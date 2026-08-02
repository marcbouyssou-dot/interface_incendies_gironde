import type {
  FullResult,
  Reporter,
  TestCase,
  TestResult,
} from '@playwright/test/reporter';

const labels = new Map<string, string>([
  ['public.spec.ts', 'Public'],
  ['coordinator.spec.ts', 'Coordinateur'],
  ['site_manager.spec.ts', 'Responsable de centre'],
  ['standard.spec.ts', 'Compte standard'],
]);

export default class SummaryReporter implements Reporter {
  private counts = new Map<string, {passed: number; total: number}>();
  private consoleErrors = 0;
  private networkErrors = 0;
  private forbiddenWrites = 0;

  onTestEnd(test: TestCase, result: TestResult): void {
    const fileName = test.location.file.split('/').at(-1) ?? '';
    const label = labels.get(fileName);
    if (label && result.status !== 'skipped') {
      const count = this.counts.get(label) ?? {passed: 0, total: 0};
      count.total += 1;
      if (result.status === 'passed') count.passed += 1;
      this.counts.set(label, count);
    }

    for (const annotation of test.annotations) {
      const value = Number(annotation.description ?? 0);
      if (annotation.type === 'consoleErrors') this.consoleErrors += value;
      if (annotation.type === 'networkErrors') this.networkErrors += value;
      if (annotation.type === 'forbiddenWrites') this.forbiddenWrites += value;
    }
  }

  onEnd(_result: FullResult): void {
    process.stdout.write('\nRésumé smoke MobSanté\n');
    for (const label of labels.values()) {
      const count = this.counts.get(label);
      process.stdout.write(
        count
          ? label === 'Public' && count.passed === count.total
            ? `${label} : OK\n`
            : `${label} : ${count.passed}/${count.total}\n`
          : `${label} : non exécuté (session absente)\n`,
      );
    }
    process.stdout.write(`Erreurs console : ${this.consoleErrors}\n`);
    process.stdout.write(`Erreurs réseau critiques : ${this.networkErrors}\n`);
    process.stdout.write(
      `Écritures interdites détectées : ${this.forbiddenWrites}\n`,
    );
  }
}
