import {defineConfig} from '@playwright/test';
import dotenv from 'dotenv';

dotenv.config({path: 'e2e/.env', quiet: true});

const baseURL =
  process.env.MOBSANTE_E2E_BASE_URL ?? 'https://mobsante.netlify.app';

export default defineConfig({
  testDir: './e2e',
  timeout: 45_000,
  expect: {timeout: 10_000},
  fullyParallel: false,
  forbidOnly: Boolean(process.env.CI),
  retries: process.env.CI ? 1 : 0,
  workers: 1,
  outputDir: 'e2e/test-results',
  reporter: [
    ['line'],
    ['./e2e/helpers/summary-reporter.ts'],
    ['html', {outputFolder: 'e2e/playwright-report', open: 'never'}],
  ],
  use: {
    baseURL,
    actionTimeout: 10_000,
    navigationTimeout: 20_000,
    trace: 'off',
    screenshot: 'off',
    video: 'off',
  },
});
