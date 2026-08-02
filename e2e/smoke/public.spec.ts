import {expect} from '@playwright/test';
import {createSmokeTest, navigate, openApp} from '../helpers/smoke-fixture';

const test = createSmokeTest();

test.describe('Public', () => {
  test('charge la PWA publiée sans écran blanc', async ({smoke}) => {
    await openApp(smoke.page);
    await expect(smoke.page).toHaveTitle(/MobSanté/);
    await expect(smoke.page.locator('flt-glass-pane')).toBeAttached();
  });

  test('affiche les missions publiques', async ({smoke}) => {
    await openApp(smoke.page);
    await expect(
      smoke.page
        .getByRole('group', {name: /Encore \d+ professionnels à mobiliser/i})
        .first(),
    ).toBeVisible();
    await smoke.page.reload({waitUntil: 'domcontentloaded'});
    await expect(smoke.page.locator('flt-glass-pane')).toBeAttached();
  });

  test('navigue vers Situation', async ({smoke}) => {
    await openApp(smoke.page);
    await navigate(smoke.page, 'Situation');
    await expect(smoke.page.getByText('SITUATION', {exact: true}).first()).toBeVisible();
  });

  test('affiche la connexion responsable sans soumission', async ({smoke}) => {
    await openApp(smoke.page);
    await navigate(smoke.page, 'Déclarer');
    await expect(smoke.page.getByText('Se connecter', {exact: true}).first()).toBeVisible();
    await expect(smoke.page.getByRole('textbox', {name: /adresse email/i})).toBeVisible();
  });
});
