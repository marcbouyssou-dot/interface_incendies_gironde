import {chromium} from '@playwright/test';
import dotenv from 'dotenv';
import {existsSync} from 'node:fs';
import {mkdir, readFile} from 'node:fs/promises';
import {createInterface} from 'node:readline/promises';
import {stdin as input, stdout as output} from 'node:process';
import {
  AUTH_ROLES,
  extractResponsibleUid,
  registerUniqueSession,
  validateObservedRole,
} from './helpers/session-validation.mjs';

dotenv.config({path: 'e2e/.env', quiet: true});

const baseURL =
  process.env.MOBSANTE_E2E_BASE_URL ?? 'https://mobsante.netlify.app';
const roleLabels = {
  coordinator: 'coordinateur',
  site_manager: 'responsable de centre',
  standard: 'compte standard',
};

await mkdir('e2e/.auth', {recursive: true});
const requestedRoles = process.argv.slice(2);
for (const role of requestedRoles) {
  if (!AUTH_ROLES.includes(role)) {
    throw new Error(
      `Profil inconnu : ${role}. Profils acceptés : ${AUTH_ROLES.join(', ')}.`,
    );
  }
}
const roles =
  requestedRoles.length > 0
    ? requestedRoles
    : AUTH_ROLES.filter((role) => !existsSync(authPath(role)));
if (roles.length === 0) {
  output.write(
    'Toutes les sessions existent déjà. Pour en recréer une, indiquez son ' +
      'profil après --.\n',
  );
  process.exit(0);
}

const seenSessions = new Map();
for (const role of AUTH_ROLES) {
  if (roles.includes(role) || !existsSync(authPath(role))) continue;
  const state = JSON.parse(await readFile(authPath(role), 'utf8'));
  registerUniqueSession(seenSessions, role, extractResponsibleUid(state));
}

const browser = await chromium.launch({headless: false});
const prompt = createInterface({input, output});

try {
  for (const role of roles) {
    const label = roleLabels[role];
    const context = await browser.newContext();
    const page = await context.newPage();
    await page.goto(baseURL, {waitUntil: 'domcontentloaded'});
    await page.waitForSelector('flt-glass-pane, body', {state: 'attached'});
    const placeholder = page.locator('flt-semantics-placeholder');
    if (await placeholder.count()) await placeholder.click({force: true});
    const declare = page.getByRole('tab', {name: 'Déclarer', exact: true}).last();
    if (await declare.count()) await declare.click();

    while (true) {
      output.write(
        `\nConnectez-vous manuellement avec le profil ${label}. ` +
          'Ne collez aucun secret dans ce terminal.\n',
      );
      await prompt.question(
        "Quand la connexion est terminée dans le navigateur, appuyez sur Entrée… ",
      );
      await enableFlutterSemantics(page);
      const state = await context.storageState({indexedDB: true});
      try {
        validateObservedRole(role, await observeRole(page));
        const uid = extractResponsibleUid(state);
        registerUniqueSession(seenSessions, role, uid);
        await context.storageState({path: authPath(role), indexedDB: true});
        break;
      } catch (error) {
        output.write(`${error.message}\n`);
      }
    }
    output.write(`Session locale ${label} enregistrée.\n`);
    await context.close();
  }
} finally {
  prompt.close();
  await browser.close();
}

function authPath(role) {
  return `e2e/.auth/${role}.json`;
}

async function enableFlutterSemantics(page) {
  const placeholder = page.locator(
    'flt-semantics-placeholder, [aria-label="Enable accessibility"]',
  );
  if (await placeholder.count()) {
    await placeholder.first().dispatchEvent('click');
    await placeholder.first().waitFor({state: 'detached'}).catch(() => {});
  }
}

async function observeRole(page) {
  const stableTitle = (value) => page.getByText(new RegExp(value, 'i')).first();
  return {
    coordinator: await stableTitle('Coordination départementale')
      .isVisible()
      .catch(() => false),
    siteManager: await stableTitle('Votre accès responsable')
      .isVisible()
      .catch(() => false),
    globalResponsibleManagement: await page
      .getByRole('button', {name: /ouvrir la gestion des responsables/i})
      .isVisible()
      .catch(() => false),
  };
}
