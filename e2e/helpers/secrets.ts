export function redactSecrets(
  value: string,
  secrets: Array<string | undefined>,
): string {
  return secrets.reduce(
    (redacted, secret) =>
      secret ? redacted.split(secret).join('[REDACTED]') : redacted,
    value,
  );
}
