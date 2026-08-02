import {expect} from '@playwright/test';
import {createSmokeTest, navigate, openApp} from '../helpers/smoke-fixture';

const test = createSmokeTest();

test.describe('Public', () => {
  test('charge la PWA publiée', async ({smoke}) => {
    await openApp(smoke.page);
    await expect(smoke.page).toHaveTitle(/MobSanté/);
    await expect(smoke.page.locator('flt-glass-pane')).toBeAttached();
  });

  test('affiche la page de connexion', async ({smoke}) => {
    await openApp(smoke.page);
    await navigate(smoke.page, 'Déclarer');
    await expect(
      smoke.page.getByRole('button', {name: /se connecter/i}),
    ).toBeVisible();
    await expect(
      smoke.page.getByRole('textbox', {name: /adresse email/i}),
    ).toBeVisible();
  });

  test('ne remonte aucune erreur console ou réseau critique', async ({smoke}) => {
    await openApp(smoke.page);
    expect(smoke.telemetry.consoleErrors).toEqual([]);
    expect(smoke.telemetry.criticalResponses).toEqual([]);
  });
});
