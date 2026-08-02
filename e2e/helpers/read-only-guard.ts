import {expect, type BrowserContext, type Page} from '@playwright/test';

export const WRITE_CALLABLES = [
  'updateMission',
  'manageLocation',
  'updateResponsibleAccess',
  'manageAdminInvitation',
  'provisionAdminInvitation',
] as const;

export const READ_CALLABLES = [
  'listResponsibleAccess',
  'listAdminLocations',
] as const;

export const FORBIDDEN_ACTION_LABELS = [
  /^Enregistrer$/i,
  /^Supprimer/i,
  /^Confirmer$/i,
  /^Envoyer$/i,
  /^Renvoyer/i,
  /^Désactiver/i,
  /^Réactiver/i,
  /^Créer$/i,
  /^Publier$/i,
  /^Annuler la mission$/i,
] as const;

export interface SmokeTelemetry {
  consoleErrors: string[];
  pageErrors: string[];
  criticalResponses: string[];
  forbiddenWrites: string[];
}

export function createTelemetry(): SmokeTelemetry {
  return {
    consoleErrors: [],
    pageErrors: [],
    criticalResponses: [],
    forbiddenWrites: [],
  };
}

export async function installReadOnlyGuard(
  context: BrowserContext,
  telemetry: SmokeTelemetry,
): Promise<void> {
  await context.route('**/*', async (route) => {
    const request = route.request();
    if (request.method() !== 'POST') return route.continue();

    const functionName = callableName(request.url());
    if (functionName === null) return route.continue();
    if (READ_CALLABLES.includes(functionName as (typeof READ_CALLABLES)[number])) {
      return route.continue();
    }

    telemetry.forbiddenWrites.push(`${functionName}: ${request.url()}`);
    await route.abort('blockedbyclient');
  });
}

export function monitorPage(page: Page, telemetry: SmokeTelemetry): void {
  page.on('console', (message) => {
    if (message.type() === 'error') telemetry.consoleErrors.push(message.text());
  });
  page.on('pageerror', (error) => telemetry.pageErrors.push(error.message));
  page.on('response', (response) => {
    if (response.status() >= 500) {
      telemetry.criticalResponses.push(
        `${response.status()} ${response.request().method()} ${response.url()}`,
      );
    }
  });
}

export async function assertPageHealthy(
  page: Page,
  telemetry: SmokeTelemetry,
  spinnerTimeout = 8_000,
): Promise<void> {
  await expect
    .poll(
      async () =>
        page
          .locator(
            '[role="progressbar"]:not([aria-valuenow]):not([aria-valuetext]), ' +
              'flt-semantics[aria-label*="chargement" i]',
          )
          .count(),
      {timeout: spinnerTimeout, message: 'Un spinner reste affiché trop longtemps.'},
    )
    .toBe(0);

  const surfaceCount = await page
    .locator('flt-glass-pane, canvas, flt-scene-host, [role="main"], main')
    .count();
  expect(surfaceCount, 'Écran blanc détecté.').toBeGreaterThan(0);

  const bodyText = await page.locator('body').innerText().catch(() => '');
  expect(bodyText).not.toMatch(
    /une erreur inattendue|application error|something went wrong|écran indisponible/i,
  );
  expect(telemetry.consoleErrors, 'Erreur console critique détectée.').toEqual([]);
  expect(telemetry.pageErrors, 'Erreur JavaScript non gérée détectée.').toEqual([]);
  expect(telemetry.criticalResponses, 'Réponse réseau 500 détectée.').toEqual([]);
  expect(telemetry.forbiddenWrites, 'Écriture métier interdite détectée.').toEqual([]);
}

export function assertNoForbiddenWrite(telemetry: SmokeTelemetry): void {
  expect(telemetry.forbiddenWrites, 'Écriture métier interdite détectée.').toEqual([]);
}

export function assertReadOnlyLabel(label: string): void {
  if (FORBIDDEN_ACTION_LABELS.some((pattern) => pattern.test(label.trim()))) {
    throw new Error(`Action interdite en smoke lecture seule : ${label}`);
  }
}

function callableName(rawUrl: string): string | null {
  const url = new URL(rawUrl);
  const isCloudFunction =
    url.hostname.endsWith('cloudfunctions.net') ||
    url.hostname.endsWith('.a.run.app');
  if (!isCloudFunction) return null;

  const pathName = url.pathname.split('/').filter(Boolean).at(-1) ?? '';
  for (const name of [...WRITE_CALLABLES, ...READ_CALLABLES]) {
    if (
      pathName.toLowerCase() === name.toLowerCase() ||
      url.hostname.replaceAll('-', '').includes(name.toLowerCase())
    ) {
      return name;
    }
  }
  return pathName || url.hostname;
}
