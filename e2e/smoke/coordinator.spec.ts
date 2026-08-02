import {expect, type Page} from '@playwright/test';
import {
  createSmokeTest,
  navigate,
  openApp,
  skipWithoutAuth,
} from '../helpers/smoke-fixture';

const test = createSmokeTest('coordinator');
skipWithoutAuth(test, 'coordinator');

async function openAdministration(page: Page) {
  await openApp(page);
  await navigate(page, 'Déclarer');
}

test.describe('Coordinateur', () => {
  test('utilise une session authentifiée', async ({smoke}) => {
    await openAdministration(smoke.page);
    await expect(
      smoke.page.getByRole('button', {name: /se déconnecter/i}),
    ).toBeVisible();
  });

  test('voit Administration', async ({smoke}) => {
    await openAdministration(smoke.page);
    await expect(
      smoke.page.getByText(/Coordination départementale/i).first(),
    ).toBeVisible();
  });

  test('accède à Déclarer', async ({smoke}) => {
    await openAdministration(smoke.page);
    await expect(
      smoke.page.getByRole('tab', {name: 'Déclarer', exact: true}),
    ).toHaveAttribute('aria-selected', 'true');
  });

  test('charge Situation sans erreur ni spinner permanent', async ({smoke}) => {
    await openApp(smoke.page);
    await navigate(smoke.page, 'Situation');
    await expect(
      smoke.page.getByText(/SITUATION/i).first(),
    ).toBeVisible();
  });
});
