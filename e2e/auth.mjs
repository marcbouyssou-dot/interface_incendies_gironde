import {chromium} from '@playwright/test';
import dotenv from 'dotenv';
import {mkdir} from 'node:fs/promises';
import {createInterface} from 'node:readline/promises';
import {stdin as input, stdout as output} from 'node:process';

dotenv.config({path: 'e2e/.env', quiet: true});

const baseURL =
  process.env.MOBSANTE_E2E_BASE_URL ?? 'https://mobsante.netlify.app';
const roles = [
  ['coordinateur', 'coordinator'],
  ['responsable de centre', 'site_manager'],
  ['compte standard', 'standard'],
];

await mkdir('e2e/.auth', {recursive: true});
const browser = await chromium.launch({headless: false});
const prompt = createInterface({input, output});

try {
  for (const [label, fileName] of roles) {
    const context = await browser.newContext();
    const page = await context.newPage();
    await page.goto(baseURL, {waitUntil: 'domcontentloaded'});
    await page.waitForSelector('flt-glass-pane, body', {state: 'attached'});
    const placeholder = page.locator('flt-semantics-placeholder');
    if (await placeholder.count()) await placeholder.click({force: true});
    const declare = page.getByText('Déclarer', {exact: true}).last();
    if (await declare.count()) await declare.click();

    output.write(
      `\nConnectez-vous manuellement avec le profil ${label}. ` +
        'Ne collez aucun secret dans ce terminal.\n',
    );
    await prompt.question(
      "Quand la connexion est terminée dans le navigateur, appuyez sur Entrée… ",
    );
    await context.storageState({
      path: `e2e/.auth/${fileName}.json`,
      indexedDB: true,
    });
    output.write(`Session locale ${label} enregistrée.\n`);
    await context.close();
  }
} finally {
  prompt.close();
  await browser.close();
}
