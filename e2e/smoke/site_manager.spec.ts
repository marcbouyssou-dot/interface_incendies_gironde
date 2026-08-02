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
  await expect(page.getByText('Votre accès responsable', {exact: true})).toBeVisible();
}

async function findLocationByEditCapability(
  page: Page,
  shouldAllowEdit: boolean,
): Promise<boolean> {
  await openApp(page);
  await navigate(page, 'Plus');
  const entries = page.getByText('Voir le lieu', {exact: true});
  const count = await entries.count();
  for (let index = 0; index < count; index += 1) {
    await entries.nth(index).click();
    const editVisible = await page
      .getByText('Modifier la mission', {exact: true})
      .first()
      .isVisible()
      .catch(() => false);
    if (editVisible === shouldAllowEdit) return true;
    await page.goBack();
  }
  return false;
}

test.describe('Responsable de centre', () => {
  test('accède à son espace responsable', async ({smoke}) => {
    await openManagerAdministration(smoke.page);
  });

  test('accède à Situation', async ({smoke}) => {
    await openApp(smoke.page);
    await navigate(smoke.page, 'Situation');
    await expect(smoke.page.getByText('SITUATION', {exact: true}).first()).toBeVisible();
  });

  test('accède à Lieux', async ({smoke}) => {
    await openApp(smoke.page);
    await navigate(smoke.page, 'Plus');
    await expect(smoke.page.getByText('Lieux', {exact: true}).first()).toBeVisible();
  });

  test('ouvre une fiche lieu', async ({smoke}) => {
    await openApp(smoke.page);
    await navigate(smoke.page, 'Plus');
    await smoke.page.getByText('Voir le lieu', {exact: true}).first().click();
    await expect(smoke.page.getByText('Besoins en cours', {exact: true})).toBeVisible();
    await smoke.page.goBack();
  });

  test('accède aux Créneaux/Missions', async ({smoke}) => {
    await openApp(smoke.page);
    await navigate(smoke.page, /Missions|Créneaux/);
    await expect(smoke.page.getByText(/professionnels à mobiliser/i).first()).toBeVisible();
  });

  test('peut ouvrir puis fermer une mission de son périmètre', async ({smoke}) => {
    expect(await findLocationByEditCapability(smoke.page, true)).toBe(true);
    await smoke.page.getByText('Modifier la mission', {exact: true}).first().click();
    await expect(smoke.page.getByText('Modifier la mission', {exact: true}).first()).toBeVisible();
    await smoke.page.getByText('Retour', {exact: true}).click();
  });

  test('ne voit ni accès global ni gestion des responsables', async ({smoke}) => {
    await openManagerAdministration(smoke.page);
    await expect(smoke.page.getByText('Tous les lieux de Gironde', {exact: true})).toHaveCount(0);
    await expect(smoke.page.getByText('Responsables', {exact: true})).toHaveCount(0);
    await expect(smoke.page.getByText('Lieux', {exact: true})).toHaveCount(0);
  });

  test('ne voit pas Modifier sur une mission hors périmètre', async ({smoke}) => {
    expect(await findLocationByEditCapability(smoke.page, false)).toBe(true);
    await expect(smoke.page.getByText('Modifier la mission', {exact: true})).toHaveCount(0);
  });
});
