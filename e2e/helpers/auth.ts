import type {BrowserContextOptions, Page} from '@playwright/test';
import {existsSync} from 'node:fs';
import path from 'node:path';

export type SmokeRole = 'coordinator' | 'site_manager' | 'standard';

const ENV_PREFIX: Record<SmokeRole, string> = {
  coordinator: 'MOBSANTE_E2E_COORDINATOR',
  site_manager: 'MOBSANTE_E2E_SITE_MANAGER',
  standard: 'MOBSANTE_E2E_STANDARD',
};

export type AuthMaterial =
  | {kind: 'storageState'; options: BrowserContextOptions}
  | {kind: 'credentials'; email: string; password: string};

export function resolveAuthMaterial(
  role: SmokeRole,
  options: {
    env?: NodeJS.ProcessEnv;
    authDirectory?: string;
  } = {},
): AuthMaterial {
  const env = options.env ?? process.env;
  const authDirectory = options.authDirectory ?? path.resolve('e2e/.auth');
  const statePath = path.join(authDirectory, `${role}.json`);
  if (existsSync(statePath)) {
    return {kind: 'storageState', options: {storageState: statePath}};
  }

  const prefix = ENV_PREFIX[role];
  const email = env[`${prefix}_EMAIL`];
  const password = env[`${prefix}_PASSWORD`];
  if (email && password) return {kind: 'credentials', email, password};

  throw new Error(
    `Session ${role} absente. Exécutez npm run e2e:auth ou renseignez ` +
      `${prefix}_EMAIL et ${prefix}_PASSWORD dans e2e/.env.`,
  );
}

export function authAvailability(role: SmokeRole): {
  available: boolean;
  reason: string;
} {
  try {
    resolveAuthMaterial(role);
    return {available: true, reason: ''};
  } catch (error) {
    return {available: false, reason: (error as Error).message};
  }
}

export async function loginWithCredentials(
  page: Page,
  email: string,
  password: string,
): Promise<void> {
  await page.goto('/');
  await enableFlutterSemantics(page);
  await page.getByText('Déclarer', {exact: true}).last().click();
  await page.getByRole('textbox', {name: /adresse email/i}).fill(email);
  await page.locator('input[type="password"]').fill(password);
  await page.getByRole('button', {name: 'Se connecter', exact: true}).click();
  await page.waitForTimeout(1_000);
  const invalid = page.getByText(/identifiants|mot de passe incorrect/i);
  if (await invalid.isVisible().catch(() => false)) {
    throw new Error('La connexion du profil de smoke test a échoué.');
  }
}

export async function enableFlutterSemantics(page: Page): Promise<void> {
  await page.waitForSelector('flt-glass-pane', {state: 'attached'});
  const placeholder = page.locator(
    'flt-semantics-placeholder, [aria-label="Enable accessibility"]',
  );
  if (await placeholder.count()) {
    await placeholder.first().dispatchEvent('click');
    await placeholder.first().waitFor({state: 'detached'}).catch(() => {});
  }
}
