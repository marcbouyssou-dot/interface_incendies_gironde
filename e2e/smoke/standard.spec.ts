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
  test('utilise une session authentifiée', async ({smoke}) => {
    await openApp(smoke.page);
    const state = await smoke.page.context().storageState({indexedDB: true});
    expect(
      state.origins.some((origin) =>
        origin.indexedDB?.some(
          (database) => database.name === 'firebaseLocalStorageDb',
        ),
      ),
    ).toBe(true);
  });

  test('ne voit aucun accès Administration', async ({smoke}) => {
    await openApp(smoke.page);
    await navigate(smoke.page, 'Déclarer');
    await expect(
      smoke.page.getByText(/Coordination départementale/i),
    ).toHaveCount(0);
    await expect(
      smoke.page.getByText(/Votre accès responsable/i),
    ).toHaveCount(0);
  });

  test('ne voit aucune action responsable ou coordinateur', async ({smoke}) => {
    await openApp(smoke.page);
    await navigate(smoke.page, 'Déclarer');
    await expect(
      smoke.page.getByRole('button', {name: /créer un besoin/i}),
    ).toHaveCount(0);
    await expect(
      smoke.page.getByRole('button', {
        name: /ouvrir la gestion des responsables/i,
      }),
    ).toHaveCount(0);
  });
});
