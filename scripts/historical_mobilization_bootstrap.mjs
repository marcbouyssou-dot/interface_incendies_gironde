export const platformBootstrapProjectId = 'mobilisation-sante';
export const platformBootstrapProjectEnvironmentKey =
  'PLATFORM_BOOTSTRAP_PROJECT_ID';

export const historicalTerritoryId = 'gironde';
export const historicalMobilizationId = 'incendies-gironde-2026';
export const historicalBootstrapActor = 'system:v6-bootstrap';

const specifications = [
  {
    path: `territories/${historicalTerritoryId}`,
    values: {
      id: historicalTerritoryId,
      name: 'Gironde',
      code: '33',
      active: true,
    },
    timestampFields: ['createdAt', 'updatedAt'],
  },
  {
    path: `mobilizations/${historicalMobilizationId}`,
    values: {
      id: historicalMobilizationId,
      territoryId: historicalTerritoryId,
      name: 'Incendies Gironde',
      subtitle: 'Incendies Gironde',
      contextType: 'fire',
      status: 'active',
      createdBy: historicalBootstrapActor,
      updatedBy: historicalBootstrapActor,
      activatedBy: historicalBootstrapActor,
      schemaVersion: 1,
    },
    timestampFields: ['createdAt', 'updatedAt', 'activatedAt'],
  },
  {
    path: 'platform/config',
    values: {
      activeMobilizationId: historicalMobilizationId,
      updatedBy: historicalBootstrapActor,
    },
    timestampFields: ['updatedAt'],
  },
];

export const historicalDocumentPaths = Object.freeze(
  specifications.map((specification) => specification.path),
);

export class HistoricalMobilizationConflictError extends Error {
  constructor(path, detail) {
    super(`Document incompatible: ${path} (${detail}).`);
    this.name = 'HistoricalMobilizationConflictError';
    this.path = path;
  }
}

export function resolveHistoricalBootstrapExecution({
  environment,
  arguments: commandArguments,
}) {
  const dryRun = commandArguments.includes('--dry-run');
  const apply = commandArguments.includes('--apply');
  const unknownArguments = commandArguments.filter(
    (argument) => !['--dry-run', '--apply'].includes(argument),
  );
  if (unknownArguments.length > 0 || dryRun === apply) {
    throw new Error('Utiliser exactement un mode: --dry-run ou --apply.');
  }
  const projectId = environment[platformBootstrapProjectEnvironmentKey];
  if (projectId !== platformBootstrapProjectId) {
    throw new Error(
      `Projet Firebase refusé: ${projectId || '<absent>'}. `
      + `Projet attendu: ${platformBootstrapProjectId}.`,
    );
  }
  return {mode: apply ? 'apply' : 'dry-run', projectId};
}

export function buildHistoricalMobilizationPlan({
  documents,
  isTimestamp = isFirestoreTimestamp,
}) {
  if (!(documents instanceof Map)) {
    throw new TypeError('Les documents existants doivent être fournis par chemin.');
  }

  const entries = specifications.map((specification) => {
    const existing = documents.get(specification.path) ?? null;
    if (existing === null) {
      return {path: specification.path, action: 'create'};
    }
    assertCompatibleDocument({specification, existing, isTimestamp});
    return {path: specification.path, action: 'unchanged'};
  });

  const creates = entries
    .filter((entry) => entry.action === 'create')
    .map((entry) => entry.path);
  return {
    entries,
    creates,
    summary: {
      create: creates.length,
      unchanged: entries.length - creates.length,
    },
  };
}

export function materializeHistoricalDocuments({paths, serverTimestamp}) {
  if (typeof serverTimestamp !== 'function') {
    throw new TypeError('Un timestamp serveur est requis.');
  }
  const timestamp = serverTimestamp();
  return paths.map((path) => {
    const specification = specificationFor(path);
    return {
      path,
      data: {
        ...specification.values,
        ...Object.fromEntries(
          specification.timestampFields.map((field) => [field, timestamp]),
        ),
      },
    };
  });
}

export async function runHistoricalMobilizationBootstrap({
  mode,
  readDocuments,
  createDocuments,
  serverTimestamp,
  isTimestamp = isFirestoreTimestamp,
}) {
  if (!['dry-run', 'apply'].includes(mode)) {
    throw new Error('Mode de bootstrap invalide.');
  }
  const documents = await readDocuments(historicalDocumentPaths);
  const plan = buildHistoricalMobilizationPlan({documents, isTimestamp});
  if (mode === 'dry-run' || plan.creates.length === 0) {
    return {...plan, mode, writes: 0};
  }
  if (typeof createDocuments !== 'function') {
    throw new TypeError('Le writer Admin est requis en mode apply.');
  }
  const creations = materializeHistoricalDocuments({
    paths: plan.creates,
    serverTimestamp,
  });
  await createDocuments(creations);
  return {...plan, mode, writes: creations.length};
}

function assertCompatibleDocument({specification, existing, isTimestamp}) {
  if (!isPlainObject(existing)) {
    throw new HistoricalMobilizationConflictError(
      specification.path,
      'structure invalide',
    );
  }
  const expectedKeys = [
    ...Object.keys(specification.values),
    ...specification.timestampFields,
  ].sort();
  const actualKeys = Object.keys(existing).sort();
  if (
    expectedKeys.length !== actualKeys.length
    || expectedKeys.some((key, index) => key !== actualKeys[index])
  ) {
    throw new HistoricalMobilizationConflictError(
      specification.path,
      'champs différents',
    );
  }
  for (const [field, expected] of Object.entries(specification.values)) {
    if (existing[field] !== expected) {
      throw new HistoricalMobilizationConflictError(
        specification.path,
        `valeur différente pour ${field}`,
      );
    }
  }
  for (const field of specification.timestampFields) {
    if (!isTimestamp(existing[field])) {
      throw new HistoricalMobilizationConflictError(
        specification.path,
        `timestamp invalide pour ${field}`,
      );
    }
  }
}

function specificationFor(path) {
  const specification = specifications.find((item) => item.path === path);
  if (!specification) throw new Error(`Chemin de bootstrap refusé: ${path}.`);
  return specification;
}

function isFirestoreTimestamp(value) {
  return value !== null
    && typeof value === 'object'
    && typeof value.toDate === 'function';
}

function isPlainObject(value) {
  return value !== null
    && typeof value === 'object'
    && !Array.isArray(value);
}
