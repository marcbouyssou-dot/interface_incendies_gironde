import {expect, type Page} from '@playwright/test';
import {
  createSmokeTest,
  navigate,
  openApp,
  skipWithoutAuth,
} from '../helpers/smoke-fixture';

const test = createSmokeTest('site_manager');
skipWithoutAuth(test, 'site_manager');

async function openManagerAdministration(page: Page) {
  await openApp(page);
  await navigate(page, 'Déclarer');
}

test.describe('Responsable de centre', () => {
  test('utilise une session authentifiée', async ({smoke}) => {
    await openManagerAdministration(smoke.page);
    await expect(
      smoke.page.getByRole('button', {name: /se déconnecter/i}),
    ).toBeVisible();
    await expect(
      smoke.page.getByText(/Votre accès responsable/i).first(),
    ).toBeVisible();
  });

  test('charge Situation', async ({smoke}) => {
    await openApp(smoke.page);
    await navigate(smoke.page, 'Situation');
    await expect(
      smoke.page.getByText(/SITUATION/i).first(),
    ).toBeVisible();
  });

  test('ne voit aucune gestion globale des responsables', async ({smoke}) => {
    await openManagerAdministration(smoke.page);
    await expect(
      smoke.page.getByRole('button', {
        name: /ouvrir la gestion des responsables/i,
      }),
    ).toHaveCount(0);
  });
});
