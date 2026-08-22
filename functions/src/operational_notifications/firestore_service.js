import {createHash} from 'node:crypto';
import {FieldValue, Timestamp} from 'firebase-admin/firestore';

import {
  isCriticalEvent,
  isQuietHour,
  notificationContent,
  recipientsForEvent,
} from './targeting.js';
import {
  canonicalSolicitationEntry,
  deriveSolicitationOrganizationContext,
  ensureCanonicalSolicitationEntry,
} from './solicitation_journal.js';

export async function persistCanonicalEvents({firestore, events}) {
  if (events.length === 0) return;
  await firestore.runTransaction(async (transaction) => {
    const references = events.map((event) =>
      firestore.collection('notificationEvents').doc(event.eventId));
    const existing = await Promise.all(
      references.map((reference) => transaction.get(reference)),
    );
    for (let index = 0; index < events.length; index += 1) {
      if (!existing[index].exists) {
        transaction.create(references[index], events[index]);
      }
    }
  });
}

export async function dispatchOperationalEvent({firestore, messaging, event, now = new Date()}) {
  const missionDocument = await firestore.collection('missions').doc(event.missionId).get();
  if (!missionDocument.exists) return {notifications: 0, pushes: 0};
  const mission = {id: missionDocument.id, ...missionDocument.data()};
  const [rolesSnapshot, assignmentsSnapshot, volunteersSnapshot, engagementsSnapshot, preferencesSnapshot, recentSnapshot] = await Promise.all([
    firestore.collection('roles').get(),
    firestore.collection('mobilizationAssignments')
      .where('mobilizationId', '==', event.mobilizationId)
      .where('role', '==', 'coordinator')
      .where('active', '==', true).get(),
    firestore.collection('volunteers').get(),
    firestore.collection('engagements').where('missionId', '==', event.missionId).get(),
    firestore.collection('notificationPreferences').get(),
    firestore.collection('notifications').get(),
  ]);
  const roles = rolesSnapshot.docs.map((doc) => ({uid: doc.id, ...doc.data()}));
  const assignments = assignmentsSnapshot.docs.map((doc) => ({
    id: doc.id,
    ...doc.data(),
  }));
  const volunteers = volunteersSnapshot.docs.map((doc) => ({uid: doc.id, ...doc.data()}));
  const engagements = engagementsSnapshot.docs.map((doc) => ({id: doc.id, ...doc.data()}));
  const preferences = new Map(preferencesSnapshot.docs.map((doc) => [doc.id, doc.data()]));
  const recentNotifications = new Map();
  for (const document of recentSnapshot.docs) {
    const value = document.data();
    const list = recentNotifications.get(value.recipientUid) ?? [];
    list.push({
      category: value.category,
      occurredAt: value.occurredAt?.toMillis?.() ?? 0,
    });
    recentNotifications.set(value.recipientUid, list);
  }
  const recipients = recipientsForEvent({
    event, mission, roles, assignments, volunteers, engagements, preferences,
    recentNotifications, now: now.getTime(),
  });
  if (recipients.length === 0) return {notifications: 0, pushes: 0};
  const solicitationContext = await deriveSolicitationOrganizationContext({
    firestore,
    missionId: event.missionId,
    mission,
  });
  const content = notificationContent(event);
  let pushes = 0;
  for (const recipient of recipients) {
    const notificationId = digest(`${event.eventId}:${recipient.uid}:in_app`);
    const notificationRef = firestore.collection('notifications').doc(notificationId);
    await firestore.runTransaction(async (transaction) => {
      const existing = await transaction.get(notificationRef);
      await ensureCanonicalSolicitationEntry({
        firestore,
        transaction,
        entry: canonicalSolicitationEntry({
          solicitationId: notificationId,
          recipientUid: recipient.uid,
          factType: 'created',
          ...solicitationContext,
          channel: 'in_app',
          occurredAt: event.occurredAt,
          source: 'notification_dispatch',
          sourceRecordIds: [notificationId, event.eventId],
          causeEventId: event.eventId,
          causeType: event.eventType,
          category: categoryFor(event.eventType),
          engagementId: event.payload.engagementId ?? null,
          recordedAt: FieldValue.serverTimestamp(),
        }),
      });
      if (!existing.exists) {
        transaction.create(notificationRef, {
          notificationId,
          eventId: event.eventId,
          eventType: event.eventType,
          recipientUid: recipient.uid,
          recipientRole: recipient.role,
          missionId: event.missionId,
          mobilizationId: event.mobilizationId,
          engagementId: event.payload.engagementId ?? null,
          title: content.title,
          body: content.body,
          category: categoryFor(event.eventType),
          occurredAt: event.occurredAt,
          createdAt: FieldValue.serverTimestamp(),
          readAt: null,
          version: 1,
        });
      }
    });
    const subscriptions = await firestore.collection('pushSubscriptions')
      .where('uid', '==', recipient.uid).where('active', '==', true).get();
    for (const subscription of subscriptions.docs) {
      const deferred = !isCriticalEvent(event.eventType) &&
        isQuietHour(recipient.preferences, now);
      const result = await deliverPush({
        firestore, messaging, event, content, recipientUid: recipient.uid,
        subscription: {id: subscription.id, ...subscription.data()},
        notificationId, deferred, preferences: recipient.preferences, now,
        context: solicitationContext,
      });
      if (result === 'delivered') pushes += 1;
    }
  }
  return {notifications: recipients.length, pushes};
}

export async function deliverPush({firestore, messaging, event, content, recipientUid, subscription, notificationId, deferred = false, preferences, now = new Date(), context = null}) {
  const solicitationContext = context ??
    await deriveSolicitationOrganizationContext({
      firestore,
      missionId: event.missionId,
    });
  const channel = `push:${subscription.installationId}`;
  const deliveryId = digest(`${event.eventId}:${recipientUid}:${channel}`);
  const reference = firestore.collection('notificationDeliveries').doc(deliveryId);
  const claim = await firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    const current = snapshot.data();
    const decision = deliveryClaimDecision(current, now.getTime());
    if (!decision.claim) return false;
    const attempts = decision.attempts;
    transaction.set(reference, {
      deliveryId, eventId: event.eventId, notificationId, recipientUid,
      channel, subscriptionId: subscription.id,
      status: deferred ? 'pending' : 'processing', attempts,
      availableAt: deferred ? nextQuietEnd(now, preferences) : Timestamp.fromDate(now),
      leaseExpiresAt: deferred ? null : Timestamp.fromMillis(now.getTime() + 60000),
      updatedAt: FieldValue.serverTimestamp(),
      createdAt: current?.createdAt ?? FieldValue.serverTimestamp(),
      errorCode: null,
    }, {merge: true});
    return !deferred;
  });
  if (!claim) return deferred ? 'pending' : 'skipped';
  try {
    const providerMessageId = await messaging.send({
      token: subscription.token,
      data: {
        title: content.title,
        body: content.body,
        notificationId,
        missionId: event.missionId,
        eventType: event.eventType,
        url: `/?notification=${encodeURIComponent(notificationId)}`,
      },
    });
    if (typeof providerMessageId !== 'string' || providerMessageId === '') {
      throw new Error('Le fournisseur push n’a retourné aucune preuve.');
    }
    const acceptedAt = FieldValue.serverTimestamp();
    const providerEvidenceId = `provider-${digest(providerMessageId)}`;
    await firestore.runTransaction(async (transaction) => {
      await ensureCanonicalSolicitationEntry({
        firestore,
        transaction,
        entry: canonicalSolicitationEntry({
          solicitationId: notificationId,
          recipientUid,
          factType: 'provider_accepted',
          ...solicitationContext,
          channel: 'push',
          occurredAt: acceptedAt,
          source: 'push_provider',
          sourceRecordIds: [
            deliveryId,
            notificationId,
            event.eventId,
            providerEvidenceId,
          ],
          causeEventId: event.eventId,
          causeType: event.eventType,
          category: categoryFor(event.eventType),
          engagementId: event.payload.engagementId ?? null,
          evidenceId: deliveryId,
          recordedAt: acceptedAt,
        }),
      });
      transaction.update(reference, {
        status: 'delivered', deliveredAt: acceptedAt,
        providerMessageId,
        leaseExpiresAt: null, updatedAt: acceptedAt,
      });
    });
    return 'delivered';
  } catch (error) {
    const code = normalizeMessagingError(error);
    await reference.update({
      status: 'failed', errorCode: code, leaseExpiresAt: null,
      updatedAt: FieldValue.serverTimestamp(),
    });
    if (isInvalidToken(code)) {
      await firestore.collection('pushSubscriptions').doc(subscription.id).update({
        active: false, disabledReason: code, updatedAt: FieldValue.serverTimestamp(),
      });
      return 'failed';
    }
    throw error;
  }
}

export async function processPendingDeliveries({firestore, messaging, now = new Date()}) {
  const snapshot = await firestore.collection('notificationDeliveries')
    .where('status', '==', 'pending')
    .limit(100).get();
  for (const delivery of snapshot.docs) {
    const value = delivery.data();
    if ((value.availableAt?.toMillis?.() ?? Number.POSITIVE_INFINITY) > now.getTime()) {
      continue;
    }
    const [eventDoc, notificationDoc, subscriptionDoc] = await Promise.all([
      firestore.collection('notificationEvents').doc(value.eventId).get(),
      firestore.collection('notifications').doc(value.notificationId).get(),
      firestore.collection('pushSubscriptions').doc(value.subscriptionId).get(),
    ]);
    if (!eventDoc.exists || !notificationDoc.exists || !subscriptionDoc.exists || subscriptionDoc.data().active !== true) continue;
    await delivery.ref.update({status: 'failed', errorCode: 'deferred-reclaimed', updatedAt: FieldValue.serverTimestamp()});
    await deliverPush({
      firestore, messaging, event: eventDoc.data(),
      content: {title: notificationDoc.data().title, body: notificationDoc.data().body},
      recipientUid: value.recipientUid,
      subscription: {id: subscriptionDoc.id, ...subscriptionDoc.data()},
      notificationId: value.notificationId, now,
    });
  }
}

function categoryFor(type) {
  if (type === 'mission.published') return 'compatible';
  if (type === 'mission.updated' || type === 'mission.cancelled') return 'engagement';
  return 'operational';
}

function digest(value) {
  return createHash('sha256').update(value).digest('hex');
}

function nextQuietEnd(now, preferences) {
  const candidate = new Date(now.getTime());
  for (let index = 0; index < 96; index += 1) {
    candidate.setMinutes(candidate.getMinutes() + 15);
    if (!isQuietHour(preferences ?? {}, candidate)) {
      return Timestamp.fromDate(candidate);
    }
  }
  return Timestamp.fromMillis(now.getTime() + 24 * 60 * 60 * 1000);
}

function normalizeMessagingError(error) {
  const code = typeof error?.code === 'string' ? error.code : 'messaging/unknown';
  return code.slice(0, 120);
}

export function isInvalidToken(code) {
  return code === 'messaging/registration-token-not-registered' ||
    code === 'messaging/invalid-registration-token';
}

export function deliveryClaimDecision(current, nowMilliseconds) {
  if (current?.status === 'delivered') return {claim: false, attempts: current.attempts ?? 0};
  const activeLease = current?.status === 'processing' &&
    (current.leaseExpiresAt?.toMillis?.() ?? 0) > nowMilliseconds;
  if (activeLease) return {claim: false, attempts: current.attempts ?? 0};
  const attempts = (current?.attempts ?? 0) + 1;
  return {claim: attempts <= 3, attempts};
}
