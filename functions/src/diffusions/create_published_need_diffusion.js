import {getFirestore} from 'firebase-admin/firestore';
import {onDocumentCreated} from 'firebase-functions/v2/firestore';

import {missionCreatedEvents} from '../operational_notifications/event_factory.js';
import {
  deriveSolicitationOrganizationContext,
} from '../operational_notifications/solicitation_journal.js';
import {ensureDiffusion, readyDiffusion} from './diffusion.js';

export async function createDiffusionForPublishedNeed({
  firestore,
  mission,
  sourceEventId,
  occurredAt,
  organizationContextResolver = deriveSolicitationOrganizationContext,
}) {
  const publication = missionCreatedEvents({
    mission,
    sourceEventId,
    occurredAt,
  })[0];
  if (publication === undefined) return null;

  const context = await organizationContextResolver({
    firestore,
    missionId: publication.missionId,
    mission,
  });
  return ensureDiffusion({
    firestore,
    diffusion: readyDiffusion({
      needId: publication.missionId,
      organizationId: context.organizationId,
      mobilizationId: publication.mobilizationId,
      createdBy: publication.actorUid,
      createdAt: publication.occurredAt,
    }),
  });
}

export const createPublishedNeedDiffusion = onDocumentCreated(
  {
    region: 'europe-west1',
    retry: true,
    document: 'missions/{missionId}',
  },
  async (event) => {
    const mission = {id: event.params.missionId, ...event.data.data()};
    await createDiffusionForPublishedNeed({
      firestore: getFirestore(),
      mission,
      sourceEventId: event.id,
      occurredAt: mission.createdAt ?? event.data.createTime,
    });
  },
);
