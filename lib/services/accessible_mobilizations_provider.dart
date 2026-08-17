import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/mobilization.dart';
import '../models/responsible_access.dart';
import '../repositories/firestore_platform_read_repository.dart';
import '../utils/switch_latest.dart';

abstract interface class AccessibleMobilizationsProvider {
  Stream<List<Mobilization>> watchAccessibleMobilizations();
}

abstract interface class AccessibleMobilizationsDataSource {
  Stream<String?> watchCurrentUid();

  Stream<List<String>> watchAssignedMobilizationIds(String uid);

  Stream<String?> watchLegacyActiveMobilizationId(String uid);

  Stream<PlatformReadDocument?> watchMobilization(String mobilizationId);
}

class FirestoreAccessibleMobilizationsDataSource
    implements AccessibleMobilizationsDataSource {
  const FirestoreAccessibleMobilizationsDataSource({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
  }) : _auth = auth,
       _firestore = firestore;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  @override
  Stream<String?> watchCurrentUid() =>
      _auth.authStateChanges().map((user) => user?.uid);

  @override
  Stream<List<String>> watchAssignedMobilizationIds(String uid) {
    return _firestore
        .collection('mobilizationAssignments')
        .where('uid', isEqualTo: uid)
        .where('role', isEqualTo: 'coordinator')
        .where('active', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final ids = snapshot.docs
              .map((document) {
                final data = document.data();
                final mobilizationId = data['mobilizationId'];
                if (mobilizationId is! String ||
                    mobilizationId.trim().isEmpty) {
                  throw const FormatException(
                    'Affectation mobilisation invalide.',
                  );
                }
                return mobilizationId;
              })
              .toSet()
              .toList(growable: false);
          ids.sort();
          return ids;
        });
  }

  @override
  Stream<String?> watchLegacyActiveMobilizationId(String uid) {
    return switchLatest(_firestore.collection('roles').doc(uid).snapshots(), (
      snapshot,
    ) {
      final data = snapshot.data();
      if (data == null) return Stream<String?>.value(null);
      const assignmentMarker = 'hasActiveMobilizationAssignments';
      if (data.containsKey(assignmentMarker) &&
          data[assignmentMarker] != false) {
        return Stream<String?>.value(null);
      }
      try {
        final access = ResponsibleAccessParser.parse(uid: uid, data: data);
        if (!access.isCoordinator) return Stream<String?>.value(null);
      } on ResponsibleAccessFormatException {
        return Stream<String?>.value(null);
      }
      return _firestore.collection('platform').doc('config').snapshots().map((
        config,
      ) {
        final value = config.data()?['activeMobilizationId'];
        if (value == null) return null;
        if (value is! String ||
            value.trim().isEmpty ||
            value.trim() != value ||
            value.contains('/')) {
          throw const FormatException(
            'Configuration de mobilisation legacy invalide.',
          );
        }
        return value;
      });
    });
  }

  @override
  Stream<PlatformReadDocument?> watchMobilization(String mobilizationId) {
    return _firestore
        .collection('mobilizations')
        .doc(mobilizationId)
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();
          return !snapshot.exists || data == null
              ? null
              : PlatformReadDocument(id: snapshot.id, data: data);
        });
  }
}

class DefaultAccessibleMobilizationsProvider
    implements AccessibleMobilizationsProvider {
  const DefaultAccessibleMobilizationsProvider({required this.dataSource});

  final AccessibleMobilizationsDataSource dataSource;

  @override
  Stream<List<Mobilization>> watchAccessibleMobilizations() {
    return switchLatest(dataSource.watchCurrentUid(), (uid) {
      if (uid == null || uid.isEmpty) {
        return Stream<List<Mobilization>>.value(const []);
      }
      return switchLatest(dataSource.watchAssignedMobilizationIds(uid), (ids) {
        if (ids.isNotEmpty) return _watchMobilizations(ids);
        return switchLatest(
          dataSource.watchLegacyActiveMobilizationId(uid),
          (legacyId) => legacyId == null
              ? Stream<List<Mobilization>>.value(const [])
              : _watchMobilizations([legacyId]),
        );
      });
    });
  }

  Stream<List<Mobilization>> _watchMobilizations(List<String> ids) {
    if (ids.isEmpty) return Stream<List<Mobilization>>.value(const []);
    late final StreamController<List<Mobilization>> controller;
    final subscriptions = <StreamSubscription<PlatformReadDocument?>>[];
    final values = <String, Mobilization?>{};

    void emit() {
      if (values.length != ids.length || controller.isClosed) return;
      final mobilizations =
          values.values
              .whereType<Mobilization>()
              .where(
                (mobilization) =>
                    mobilization.status == MobilizationStatus.active,
              )
              .toList(growable: false)
            ..sort((left, right) => left.name.compareTo(right.name));
      controller.add(mobilizations);
    }

    controller = StreamController<List<Mobilization>>(
      onListen: () {
        for (final id in ids) {
          final subscription = dataSource.watchMobilization(id).listen((
            document,
          ) {
            values[id] = document == null ? null : _fromDocument(document);
            emit();
          }, onError: controller.addError);
          subscriptions.add(subscription);
        }
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );
    return controller.stream;
  }

  Mobilization _fromDocument(PlatformReadDocument document) {
    final data = Map<String, Object?>.of(document.data);
    for (final field in ['createdAt', 'updatedAt']) {
      data[field] = _dateTime(data[field], field);
    }
    for (final field in ['activatedAt', 'deactivatedAt', 'archivedAt']) {
      if (data[field] != null) data[field] = _dateTime(data[field], field);
    }
    final mobilization = Mobilization.fromMap(data);
    if (mobilization.id != document.id) {
      throw const FormatException('Mobilisation incohérente.');
    }
    return mobilization;
  }

  DateTime _dateTime(Object? value, String field) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    throw FormatException('Date plateforme invalide : $field.');
  }
}
