import {expect} from '@playwright/test';
import {
  createSmokeTest,
  navigate,
  openApp,
  skipWithoutAuth,
} from '../helpers/smoke-fixture';

const test = createSmokeTest('standard');
skipWithoutAuth(test, 'standard');

test.describe('Compte standard', () => {
  test('accède aux Missions publiques', async ({smoke}) => {
    await openApp(smoke.page);
    await expect(smoke.page.getByText(/professionnels à mobiliser/i).first()).toBeVisible();
  });

  test('accède à Situation', async ({smoke}) => {
    await openApp(smoke.page);
    await navigate(smoke.page, 'Situation');
    await expect(smoke.page.getByText('SITUATION', {exact: true}).first()).toBeVisible();
  });

  test('n’obtient pas une Administration privilégiée', async ({smoke}) => {
    await openApp(smoke.page);
    await navigate(smoke.page, 'Déclarer');
    await expect(smoke.page.getByText('Coordination départementale', {exact: true})).toHaveCount(0);
    await expect(smoke.page.getByText('Créer un besoin', {exact: true})).toHaveCount(0);
  });

  test('ne voit pas la gestion des responsables', async ({smoke}) => {
    await openApp(smoke.page);
    await navigate(smoke.page, 'Déclarer');
    await expect(smoke.page.getByText('Responsables', {exact: true})).toHaveCount(0);
  });

  test('ne voit aucune action de modification privilégiée', async ({smoke}) => {
    await openApp(smoke.page);
    await navigate(smoke.page, 'Situation');
    await expect(smoke.page.getByText('Modifier la mission', {exact: true})).toHaveCount(0);
    await expect(smoke.page.getByText('Annuler la mission', {exact: true})).toHaveCount(0);
  });
});
