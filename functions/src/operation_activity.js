// Legacy mobilizations have no Operation. Once an Operation is attached,
// its lifecycle is authoritative for new operational mutations.
export function operationAllowsOperationalMutation(mobilization, operation) {
  if (mobilization === null || typeof mobilization !== 'object') return false;
  if (!Object.hasOwn(mobilization, 'operationId')) return true;
  return typeof mobilization.operationId === 'string'
    && mobilization.operationId.length > 0
    && operation !== null
    && typeof operation === 'object'
    && operation.id === mobilization.operationId
    && operation.status === 'active';
}
