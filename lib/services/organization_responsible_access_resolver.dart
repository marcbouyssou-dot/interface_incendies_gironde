import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/organization_context.dart';
import '../models/organization_role.dart';
import '../models/responsible_access.dart';
import '../utils/value_listenable_stream.dart';

/// Projette les rôles organisationnels RC4 vers le contrat historique utilisé
/// par les parcours Coordinateur et Responsable.
///
/// La projection n'ajoute aucun droit : une membership active et cohérente est
/// obligatoire hors du périmètre legacy. Dans `legacy-gironde`, le document
/// `roles/{uid}` reste accepté uniquement quand aucune membership RC4 n'existe.
class OrganizationResponsibleAccessResolver {
  const OrganizationResponsibleAccessResolver();

  Stream<ResponsibleAccess?> watch({
    required Stream<ResponsibleAccess?> legacyAccess,
    required ValueListenable<OrganizationContext?> context,
    bool closeWhenLegacyAccessCloses = true,
  }) => Stream<ResponsibleAccess?>.multi((controller) {
    var currentContext = context.value;
    ResponsibleAccess? currentLegacyAccess;
    var hasLegacyValue = false;
    var closed = false;
    StreamSubscription<OrganizationContext?>? contextSubscription;

    void emit() {
      if (!hasLegacyValue) return;
      controller.add(
        resolve(context: currentContext, legacyAccess: currentLegacyAccess),
      );
    }

    Future<void> close() async {
      if (closed) return;
      closed = true;
      await contextSubscription?.cancel();
      controller.close();
    }

    final legacySubscription = legacyAccess.listen(
      (access) {
        currentLegacyAccess = access;
        hasLegacyValue = true;
        emit();
      },
      onError: controller.addError,
      onDone: closeWhenLegacyAccessCloses ? () => unawaited(close()) : null,
    );
    contextSubscription = watchValueListenable(context).listen((
      organizationContext,
    ) {
      currentContext = organizationContext;
      emit();
    }, onError: controller.addError);
    controller.onCancel = () async {
      closed = true;
      await legacySubscription.cancel();
      await contextSubscription?.cancel();
    };
  });

  @visibleForTesting
  ResponsibleAccess? resolve({
    required OrganizationContext? context,
    required ResponsibleAccess? legacyAccess,
  }) {
    if (context == null || !context.hasSelectedOrganization) {
      return legacyAccess;
    }
    final membership = context.membership;
    if (membership != null) {
      if (!membership.active) return null;
      final roles = <String>[
        if (membership.roles.contains(OrganizationRole.coordinator))
          ResponsibleRole.coordinator,
        if (membership.roles.contains(OrganizationRole.siteManager))
          ResponsibleRole.siteManager,
      ];
      if (roles.isEmpty) return null;
      try {
        return ResponsibleAccess.v2(
          uid: context.uid,
          roles: roles,
          locationIds: membership.locationIds,
          active: true,
        );
      } on FormatException {
        return null;
      }
    }
    if (!context.isLegacy ||
        legacyAccess?.active != true ||
        legacyAccess?.uid != context.uid) {
      return null;
    }
    final expectedRoles = <String>{
      if (context.hasRole(OrganizationRole.coordinator))
        ResponsibleRole.coordinator,
      if (context.hasRole(OrganizationRole.siteManager))
        ResponsibleRole.siteManager,
    };
    return legacyAccess!.roles.length == expectedRoles.length &&
            legacyAccess.roles.containsAll(expectedRoles)
        ? legacyAccess
        : null;
  }
}
