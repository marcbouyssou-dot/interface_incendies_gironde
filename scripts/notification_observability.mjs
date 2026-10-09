// Read-only operational trace. Deliberately omits UIDs, tokens, message IDs,
// notification content and other recipient details from stdout.
export function summarizeNotificationEvent({exists, notifications, deliveries}) {
  const recipients = new Set(notifications.map((item) => item.recipientUid)
    .concat(deliveries.map((item) => item.recipientUid)).filter(Boolean));
  const statuses = {};
  const failureCategories = {};
  let attempts = 0;
  for (const delivery of deliveries) {
    const status = ['pending', 'processing', 'delivered', 'failed', 'skipped']
      .includes(delivery.status) ? delivery.status : 'unknown';
    statuses[status] = (statuses[status] ?? 0) + 1;
    attempts += Number.isInteger(delivery.attempts) ? delivery.attempts : 0;
    if (status === 'failed') {
      const category = typeof delivery.errorCode === 'string'
        && /^(messaging\/[a-z-]{1,80}|[a-z-]{1,80})$/.test(delivery.errorCode)
        ? delivery.errorCode : 'unknown';
      failureCategories[category] = (failureCategories[category] ?? 0) + 1;
    }
  }
  return {eventCreated: exists, resolvedRecipients: recipients.size,
    inAppNotifications: notifications.length, pushDeliveries: deliveries.length,
    attempts, statuses, failureCategories};
}

if (process.argv[1]?.endsWith('/notification_observability.mjs')) {
  const [projectFlag, projectId, eventFlag, eventId] = process.argv.slice(2);
  if (projectFlag !== '--project' || !/^[a-z0-9-]+$/.test(projectId ?? '')
    || eventFlag !== '--event-id' || !/^[a-zA-Z0-9_-]{1,120}$/.test(eventId ?? '')) {
    throw Error('Usage: node scripts/notification_observability.mjs --project PROJECT --event-id EVENT_ID');
  }
  const {initializeApp, applicationDefault} = await import('firebase-admin/app');
  const {getFirestore} = await import('firebase-admin/firestore');
  initializeApp({projectId,
    ...(process.env.FIRESTORE_EMULATOR_HOST ? {} : {credential: applicationDefault()})});
  const db = getFirestore();
  const [event, notifications, deliveries] = await Promise.all([
    db.collection('notificationEvents').doc(eventId).get(),
    db.collection('notifications').where('eventId', '==', eventId).get(),
    db.collection('notificationDeliveries').where('eventId', '==', eventId).get(),
  ]);
  process.stdout.write(`${JSON.stringify(summarizeNotificationEvent({
    exists: event.exists,
    notifications: notifications.docs.map((doc) => doc.data()),
    deliveries: deliveries.docs.map((doc) => doc.data()),
  }), null, 2)}\n`);
}
