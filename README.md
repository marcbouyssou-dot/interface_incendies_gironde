# Interface Récup

PWA Flutter de coordination en temps réel des professionnels volontaires.

## Modes de données

Le mode mock est actif par défaut, notamment pour les tests :

```bash
flutter run -d chrome
```

Le mode Firestore s’active avec les paramètres du projet Firebase :

```bash
flutter run -d chrome \
  --dart-define=USE_FIREBASE=true \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_APP_ID=... \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
  --dart-define=FIREBASE_PROJECT_ID=... \
  --dart-define=FIREBASE_AUTH_DOMAIN=... \
  --dart-define=FIREBASE_STORAGE_BUCKET=...
```

L’interface dépend uniquement de `CoordinationRepository`. Les
implémentations disponibles sont :

- `FirestoreCoordinationRepository`, pour les collections Firestore ;
- `MockCoordinationRepository`, pour le développement local et les tests.

## Collections Firestore

- `locations` : `name`, `type`, `group`, `activeNeeds`, `address`
- `missions` : `place`, `group`, `date`, `time`, quotas et compteurs MK/PP,
  `equipment`, `status`
- `volunteers` : `firstName`, `lastName`, `phone`, `email` facultatif,
  `profession`, `createdAt`
- `engagements` : `missionId`, `volunteerId`, `profession`, `createdAt`

La création d’un engagement, du volontaire et la mise à jour des compteurs et
du statut de mission sont regroupées dans une transaction Firestore.

## Vérification manuelle d’une mission réelle

1. Ouvrir la PWA sur le Mac en mode Firebase.
2. Dans **Déclarer**, choisir une caserne réelle.
3. Choisir la date du lendemain.
4. Choisir un créneau `22:00 → 02:00`.
5. Régler les quotas à 2 MK et 1 PP, puis publier.
6. Attendre l’écran **Mission publiée**.
7. Ouvrir la PWA sur un iPhone sans rechargement manuel.
8. Vérifier le lieu, la date, les horaires et les quotas de la mission.
9. Vérifier le document dans Firebase Console → Firestore → `missions`.
