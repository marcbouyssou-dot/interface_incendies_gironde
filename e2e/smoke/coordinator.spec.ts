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
  await expect(page.getByText('Coordination départementale', {exact: true})).toBeVisible();
}

async function openCoordinatorLocations(page: Page) {
  await openAdministration(page);
  await page.getByText('Lieux', {exact: true}).first().click();
  await expect(page.getByText('Créer un lieu', {exact: true})).toBeVisible();
}

test.describe('Coordinateur', () => {
  test('accède à Administration', async ({smoke}) => {
    await openAdministration(smoke.page);
  });

  test('voit Créer un besoin', async ({smoke}) => {
    await openAdministration(smoke.page);
    await expect(smoke.page.getByText('Créer un besoin', {exact: true}).first()).toBeVisible();
  });

  test('voit la gestion des responsables', async ({smoke}) => {
    await openAdministration(smoke.page);
    await expect(smoke.page.getByText('Responsables', {exact: true}).first()).toBeVisible();
  });

  test('voit la gestion complète des lieux', async ({smoke}) => {
    await openAdministration(smoke.page);
    await expect(smoke.page.getByText('Lieux', {exact: true}).first()).toBeVisible();
  });

  test('voit tous les lieux de Gironde', async ({smoke}) => {
    await openAdministration(smoke.page);
    await expect(smoke.page.getByText('Tous les lieux de Gironde', {exact: true})).toBeVisible();
  });

  test('accède à Situation', async ({smoke}) => {
    await openApp(smoke.page);
    await navigate(smoke.page, 'Situation');
    await expect(smoke.page.getByText('SITUATION', {exact: true}).first()).toBeVisible();
  });

  test('ouvre Responsables et voit Invitations', async ({smoke}) => {
    await openAdministration(smoke.page);
    await smoke.page.getByText('Responsables', {exact: true}).first().click();
    await expect(smoke.page.getByText('Invitations', {exact: true})).toBeVisible();
    await smoke.page.goBack();
  });

  test('accède aux Créneaux/Missions', async ({smoke}) => {
    await openApp(smoke.page);
    await navigate(smoke.page, /Missions|Créneaux/);
    await expect(smoke.page.getByText(/professionnels à mobiliser/i).first()).toBeVisible();
  });

  test('ouvre Lieux puis une fiche lieu', async ({smoke}) => {
    await openApp(smoke.page);
    await navigate(smoke.page, 'Plus');
    await expect(smoke.page.getByText('Lieux', {exact: true}).first()).toBeVisible();
    await smoke.page.getByText('Voir le lieu', {exact: true}).first().click();
    await expect(smoke.page.getByText('Besoins en cours', {exact: true})).toBeVisible();
    await smoke.page.goBack();
  });

  test('ouvre la création d’un lieu puis revient sans enregistrer', async ({smoke}) => {
    await openCoordinatorLocations(smoke.page);
    await smoke.page.getByText('Créer un lieu', {exact: true}).click();
    await expect(smoke.page.getByText('Identifiant stable', {exact: true})).toBeVisible();
    await smoke.page.goBack();
  });

  test('ouvre la modification d’un lieu puis revient sans enregistrer', async ({smoke}) => {
    await openCoordinatorLocations(smoke.page);
    await smoke.page.getByText('Modifier', {exact: true}).first().click();
    await expect(smoke.page.getByText('Modifier le lieu', {exact: true})).toBeVisible();
    await smoke.page.goBack();
  });

  test('ouvre une modification de mission préremplie puis revient', async ({smoke}) => {
    await openApp(smoke.page);
    await navigate(smoke.page, 'Situation');
    await smoke.page.getByText('Modifier la mission', {exact: true}).first().click();
    await expect(smoke.page.getByText('Modifier la mission', {exact: true}).first()).toBeVisible();
    await expect(smoke.page.getByText('Date', {exact: true}).first()).toBeVisible();
    await expect(smoke.page.getByText(/Choisir un lieu|Lieu/i).first()).toBeVisible();
    await smoke.page.getByText('Retour', {exact: true}).click();
  });
});
