import {
  test as base,
  type Locator,
  type Page,
  type TestInfo,
} from '@playwright/test';
import {
  authAvailability,
  enableFlutterSemantics,
  loginWithCredentials,
  resolveAuthMaterial,
  type SmokeRole,
} from './auth';
import {
  assertPageHealthy,
  createTelemetry,
  installReadOnlyGuard,
  monitorPage,
  type SmokeTelemetry,
} from './read-only-guard';

export interface SmokePage {
  page: Page;
  telemetry: SmokeTelemetry;
}

export function createSmokeTest(role?: SmokeRole) {
  return base.extend<{smoke: SmokePage}>({
    smoke: async ({browser}, use, testInfo) => {
      const material = role ? resolveAuthMaterial(role) : undefined;
      const context = await browser.newContext(
        material?.kind === 'storageState' ? material.options : {},
      );
      const telemetry = createTelemetry();
      await installReadOnlyGuard(context, telemetry);
      const page = await context.newPage();
      monitorPage(page, telemetry);

      try {
        if (material?.kind === 'credentials') {
          await loginWithCredentials(page, material.email, material.password);
        }
        await use({page, telemetry});
        await assertPageHealthy(page, telemetry);
      } catch (error) {
        await takeSanitizedFailureScreenshot(page, testInfo).catch(() => {});
        throw error;
      } finally {
        annotateTelemetry(testInfo, telemetry);
        if (testInfo.status !== testInfo.expectedStatus) {
          await takeSanitizedFailureScreenshot(page, testInfo).catch(() => {});
        }
        await context.close();
      }
    },
  });
}

export function skipWithoutAuth(
  test: ReturnType<typeof createSmokeTest>,
  role: SmokeRole,
): void {
  const availability = authAvailability(role);
  test.skip(!availability.available, availability.reason);
}

export async function openApp(page: Page): Promise<void> {
  await page.goto('/', {waitUntil: 'domcontentloaded'});
  await enableFlutterSemantics(page);
}

export async function navigate(page: Page, label: string | RegExp): Promise<void> {
  await page
    .getByRole('tab', {name: label, exact: typeof label === 'string'})
    .last()
    .click();
  await enableFlutterSemantics(page);
}

export function visibleText(page: Page, value: string | RegExp): Locator {
  return page.getByText(value, {exact: typeof value === 'string'}).first();
}

async function takeSanitizedFailureScreenshot(
  page: Page,
  testInfo: TestInfo,
): Promise<void> {
  const masks = [
    page.locator('input'),
    page.locator('[role="textbox"]'),
    page.locator('[aria-label*="@"]'),
  ];
  await page.screenshot({
    path: testInfo.outputPath('failure.png'),
    fullPage: false,
    mask: masks,
  });
}

function annotateTelemetry(
  testInfo: TestInfo,
  telemetry: SmokeTelemetry,
): void {
  testInfo.annotations.push(
    {type: 'consoleErrors', description: String(telemetry.consoleErrors.length)},
    {type: 'networkErrors', description: String(telemetry.criticalResponses.length)},
    {type: 'forbiddenWrites', description: String(telemetry.forbiddenWrites.length)},
  );
}
