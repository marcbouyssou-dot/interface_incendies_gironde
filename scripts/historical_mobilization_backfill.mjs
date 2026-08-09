export const backfillProjectId = 'mobilisation-sante';
export const historicalMobilizationId = 'incendies-gironde-2026';
export const safeBatchSize = 400;

export function resolveBackfillExecution(commandArguments) {
  let mode = 'dry-run';
  let explicitMode = null;
  let projectId = null;
  for (let index = 0; index < commandArguments.length; index++) {
    const argument = commandArguments[index];
    if (argument === '--dry-run' || argument === '--apply') {
      if (explicitMode !== null) {
        throw new Error('Utiliser --dry-run ou --apply, jamais les deux.');
      }
      explicitMode = argument;
      mode = argument === '--apply' ? 'apply' : 'dry-run';
      continue;
    }
    if (argument === '--project') {
      if (projectId !== null || index + 1 >= commandArguments.length) {
        throw new Error('Le projet Firebase doit être fourni une seule fois.');
      }
      projectId = commandArguments[++index];
      continue;
    }
    if (argument.startsWith('--project=')) {
      if (projectId !== null) {
        throw new Error('Le projet Firebase doit être fourni une seule fois.');
      }
      projectId = argument.slice('--project='.length);
      continue;
    }
    throw new Error(`Argument refusé: ${argument}.`);
  }
  if (projectId !== backfillProjectId) {
    throw new Error(
      `Projet Firebase refusé: ${projectId || '<absent>'}. `
      + `Projet attendu: ${backfillProjectId}.`,
    );
  }
  return {mode, projectId};
}

export function buildHistoricalMobilizationBackfillPlan({
  missions,
  engagements,
}) {
  const missionEntries = missions.map(classifyMission);
  const missionsById = new Map(
    missionEntries.map((entry) => [entry.id, entry]),
  );
  const engagementEntries = engagements.map((document) =>
    classifyEngagement(document, missionsById),
  );
  const summary = {
    missions: summarize(missionEntries),
    engagements: summarize(engagementEntries),
  };
  summary.global = hasBlocker(summary) ? 'NO-GO' : 'GO';
  return {
    missions: missionEntries,
    engagements: engagementEntries,
    summary,
  };
}

export function patchesForBackfillPlan(plan) {
  if (plan.summary.global !== 'GO') {
    throw new Error('Backfill refusé: le plan contient des incohérences.');
  }
  return [
    ...plan.missions
      .filter((entry) => entry.action === 'update')
      .map((entry) => ({
        kind: 'mission',
        path: `missions/${entry.id}`,
        fields: {mobilizationId: historicalMobilizationId},
      })),
    ...plan.engagements
      .filter((entry) => entry.action === 'update')
      .map((entry) => ({
        kind: 'engagement',
        path: `engagements/${entry.id}`,
        missionId: entry.missionId,
        fields: {mobilizationId: historicalMobilizationId},
      })),
  ];
}

export async function runHistoricalMobilizationBackfill({
  mode,
  readCollections,
  writePatches,
  batchSize = safeBatchSize,
}) {
  if (!['dry-run', 'apply'].includes(mode)) {
    throw new Error('Mode de backfill invalide.');
  }
  if (!Number.isInteger(batchSize) || batchSize < 1 || batchSize > 500) {
    throw new Error('Taille de batch invalide.');
  }
  const beforeDocuments = await readCollections();
  const before = buildHistoricalMobilizationBackfillPlan(beforeDocuments);
  const expectedAfter = expectedSummaryAfter(before.summary);
  if (mode === 'dry-run' || before.summary.global === 'NO-GO') {
    return {mode, before, expectedAfter, after: null, writes: 0};
  }
  if (typeof writePatches !== 'function') {
    throw new TypeError('Le writer Admin est requis en mode apply.');
  }
  const patches = patchesForBackfillPlan(before);
  let writes = 0;
  for (const kind of ['mission', 'engagement']) {
    const collectionPatches = patches.filter((patch) => patch.kind === kind);
    for (
      let offset = 0;
      offset < collectionPatches.length;
      offset += batchSize
    ) {
      const batch = collectionPatches.slice(offset, offset + batchSize);
      const written = await writePatches(batch);
      writes += Number.isInteger(written) ? written : batch.length;
    }
  }
  const afterDocuments = await readCollections();
  const after = buildHistoricalMobilizationBackfillPlan(afterDocuments);
  if (
    after.summary.global !== 'GO'
    || after.summary.missions.toModify !== 0
    || after.summary.engagements.toModify !== 0
  ) {
    throw new Error('La vérification post-backfill a échoué.');
  }
  return {mode, before, expectedAfter, after, writes};
}

function classifyMission(document) {
  const base = documentBase(document, 'mission');
  if (base.error) return {...base.entry, action: 'malformed'};
  const mobilization = classifyMobilizationId(document.data);
  if (mobilization === 'absent') {
    return {...base.entry, action: 'update'};
  }
  if (mobilization === 'target') {
    return {...base.entry, action: 'compliant'};
  }
  return {
    ...base.entry,
    action: mobilization === 'different' ? 'conflict' : 'malformed',
    reason: mobilization,
  };
}

function classifyEngagement(document, missionsById) {
  const base = documentBase(document, 'engagement');
  if (base.error) return {...base.entry, action: 'malformed'};
  const missionId = document.data.missionId;
  if (!isStrictText(missionId)) {
    return {...base.entry, action: 'malformed', reason: 'invalid_mission_id'};
  }
  const mission = missionsById.get(missionId);
  if (!mission) {
    return {...base.entry, action: 'orphan', reason: 'mission_missing'};
  }
  if (!['update', 'compliant'].includes(mission.action)) {
    return {
      ...base.entry,
      action: 'conflict',
      reason: 'mission_not_in_historical_mobilization',
    };
  }
  const mobilization = classifyMobilizationId(document.data);
  if (mobilization === 'absent') {
    return {...base.entry, action: 'update', missionId};
  }
  if (mobilization === 'target') {
    return {...base.entry, action: 'compliant', missionId};
  }
  return {
    ...base.entry,
    action: mobilization === 'different' ? 'conflict' : 'malformed',
    reason: mobilization,
    missionId,
  };
}

function documentBase(document, kind) {
  if (
    !document
    || !isStrictText(document.id)
    || !isPlainObject(document.data)
  ) {
    return {
      error: true,
      entry: {
        id: isStrictText(document?.id) ? document.id : `<${kind}-invalide>`,
        reason: 'document_malformed',
      },
    };
  }
  return {error: false, entry: {id: document.id}};
}

function classifyMobilizationId(data) {
  if (!Object.hasOwn(data, 'mobilizationId')) return 'absent';
  const value = data.mobilizationId;
  if (!isStrictText(value)) return 'invalid_mobilization_id';
  return value === historicalMobilizationId ? 'target' : 'different';
}

function summarize(entries) {
  return {
    total: entries.length,
    toModify: count(entries, 'update'),
    compliant: count(entries, 'compliant'),
    conflicts: count(entries, 'conflict'),
    orphans: count(entries, 'orphan'),
    malformed: count(entries, 'malformed'),
  };
}

function expectedSummaryAfter(summary) {
  return {
    missions: {
      ...summary.missions,
      compliant: summary.missions.compliant + summary.missions.toModify,
      toModify: 0,
    },
    engagements: {
      ...summary.engagements,
      compliant:
        summary.engagements.compliant + summary.engagements.toModify,
      toModify: 0,
    },
    global: summary.global,
  };
}

function hasBlocker(summary) {
  return ['conflicts', 'orphans', 'malformed'].some(
    (field) =>
      summary.missions[field] > 0 || summary.engagements[field] > 0,
  );
}

function count(entries, action) {
  return entries.filter((entry) => entry.action === action).length;
}

function isStrictText(value) {
  return typeof value === 'string'
    && value.length > 0
    && value.trim() === value;
}

function isPlainObject(value) {
  return value !== null
    && typeof value === 'object'
    && !Array.isArray(value);
}
