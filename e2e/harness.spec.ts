import {expect, test} from '@playwright/test';
import {existsSync, readFileSync} from 'node:fs';
import {resolveAuthMaterial} from './helpers/auth';
import {
  assertNoForbiddenWrite,
  assertPageHealthy,
  assertReadOnlyLabel,
  createTelemetry,
  installReadOnlyGuard,
  monitorPage,
} from './helpers/read-only-guard';
import {redactSecrets} from './helpers/secrets';
import {
  extractResponsibleUid,
  registerUniqueSession,
  validateObservedRole,
} from './helpers/session-validation.mjs';

test.describe('harnais de sécurité lecture seule', () => {
  test('une session absente produit une instruction claire', () => {
    expect(() =>
      resolveAuthMaterial('coordinator', {
        env: {},
        authDirectory: '/private/tmp/mobsante-auth-does-not-exist',
      }),
    ).toThrow(/npm run e2e:auth.*MOBSANTE_E2E_COORDINATOR_EMAIL/s);
  });

  test('un mauvais rôle est refusé avant sauvegarde', () => {
    expect(() =>
      validateObservedRole('site_manager', {
        coordinator: true,
        siteManager: false,
        globalResponsibleManagement: true,
      }),
    ).toThrow(/ne correspond pas à site_manager.*Reconnectez-vous/s);
  });

  test('deux sessions avec le même UID sont refusées sans exposer l’identifiant', () => {
    const uid = 'uid-secret-test-only';
    const sessions = new Map([['coordinator', uid]]);
    let message = '';
    try {
      registerUniqueSession(sessions, 'site_manager', uid);
    } catch (error) {
      message = (error as Error).message;
    }
    expect(message).toMatch(
      /session site_manager utilise déjà le même compte que coordinator/i,
    );
    expect(message).not.toContain(uid);
  });

  test('l’UID responsable est extrait sans journaliser les données de session', () => {
    const uid = 'uid-secret-test-only';
    const state = syntheticStorageState(uid);
    expect(extractResponsibleUid(state)).toBe(uid);
  });

  test('les rôles accessibles retrouvent les noms Flutter fusionnés', async ({
    page,
  }) => {
    await page.setContent(`
      <main>
        <div role="group" aria-label="MobSanté Encore 7 professionnels à mobiliser 0 % de couverture">Résumé</div>
        <button aria-label="Bassens Caserne SDIS Inactif Voir le lieu">Ouvrir</button>
      </main>
    `);
    await expect(
      page.getByRole('group', {
        name: /encore \d+ professionnels à mobiliser/i,
      }),
    ).toBeVisible();
    await expect(
      page.getByRole('button', {name: /voir le lieu/i}),
    ).toBeVisible();
  });

  test('une erreur console fait échouer le contrôle global', async ({browser}) => {
    const context = await browser.newContext();
    const telemetry = createTelemetry();
    await installReadOnlyGuard(context, telemetry);
    const page = await context.newPage();
    monitorPage(page, telemetry);
    await page.setContent('<main>Page synthétique</main>');
    await page.evaluate(() => console.error('synthetic-console-error'));
    await expect(assertPageHealthy(page, telemetry, 100)).rejects.toThrow(
      /Erreur console critique/,
    );
    await context.close();
  });

  test('une callable d’écriture est bloquée et signalée', async ({browser}) => {
    const context = await browser.newContext();
    const telemetry = createTelemetry();
    await installReadOnlyGuard(context, telemetry);
    const page = await context.newPage();
    await page.setContent('<main>Page synthétique</main>');
    await page.evaluate(async () => {
      await fetch(
        'https://europe-west1-mobilisation-sante.cloudfunctions.net/updateMission',
        {method: 'POST', body: '{}'},
      ).catch(() => undefined);
    });
    expect(() => assertNoForbiddenWrite(telemetry)).toThrow(
      /Écriture métier interdite/,
    );
    await context.close();
  });

  test('un POST inattendu vers une Function est bloqué', async ({browser}) => {
    const context = await browser.newContext();
    const telemetry = createTelemetry();
    await installReadOnlyGuard(context, telemetry);
    const page = await context.newPage();
    await page.setContent('<main>Page synthétique</main>');
    await page.evaluate(async () => {
      await fetch(
        'https://europe-west1-mobilisation-sante.cloudfunctions.net/unknownWriter',
        {method: 'POST', body: '{}'},
      ).catch(() => undefined);
    });
    expect(telemetry.forbiddenWrites.join('\n')).toContain('unknownWriter');
    await context.close();
  });

  test('un spinner permanent fait échouer le contrôle global', async ({page}) => {
    const telemetry = createTelemetry();
    await page.setContent(
      '<main><div role="progressbar">Chargement permanent</div></main>',
    );
    await expect(assertPageHealthy(page, telemetry, 100)).rejects.toThrow(
      /spinner reste affiché/i,
    );
  });

  test('les actions terminales sont explicitement refusées', () => {
    expect(() => assertReadOnlyLabel('Enregistrer')).toThrow(
      /Action interdite/,
    );
    expect(() => assertReadOnlyLabel('Renvoyer')).toThrow(/Action interdite/);
    expect(() => assertReadOnlyLabel('Retour')).not.toThrow();
  });

  test('une capture synthétique est créée sans exposer le champ secret', async ({
    page,
  }, testInfo) => {
    await page.setContent(
      '<main><input type="password" value="secret-test-only"><p>Échec synthétique</p></main>',
    );
    const output = testInfo.outputPath('synthetic-failure.png');
    await page.screenshot({path: output, mask: [page.locator('input')]});
    expect(existsSync(output)).toBe(true);
    expect(readFileSync(output).byteLength).toBeGreaterThan(0);
  });

  test('les secrets sont expurgés des messages', () => {
    const secret = 'test-only-password';
    const result = redactSecrets(`Erreur avec ${secret}`, [secret]);
    expect(result).toBe('Erreur avec [REDACTED]');
    expect(result).not.toContain(secret);
  });

  test('la configuration active le rapport HTML et les captures d’échec', () => {
    const config = readFileSync('playwright.config.ts', 'utf8');
    expect(config).toContain("['html'");
    const fixture = readFileSync('e2e/helpers/smoke-fixture.ts', 'utf8');
    expect(fixture).toContain('takeSanitizedFailureScreenshot');
  });
});

function syntheticStorageState(uid: string) {
  return {
    cookies: [],
    origins: [
      {
        origin: 'https://example.test',
        localStorage: [],
        indexedDB: [
          {
            name: 'firebaseLocalStorageDb',
            stores: [
              {
                records: [
                  {
                    valueEncoded: {
                      o: [
                        {
                          k: 'fbase_key',
                          v: 'firebase:authUser:test:responsible',
                        },
                        {k: 'uid', v: uid},
                      ],
                    },
                  },
                ],
              },
            ],
          },
        ],
      },
    ],
  };
}
