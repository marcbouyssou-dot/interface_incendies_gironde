import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/operation.dart';
import '../models/organization.dart';
import '../models/organization_context.dart';
import '../models/organization_membership.dart';
import '../repositories/organization_read_repository.dart';
import 'legacy_organization_resolver.dart';

/// Résout et publie le contexte Organisation consommé par les politiques RC4.
///
/// Les memberships actives sont la source des rôles organisationnels. Le
/// fallback RC3 reste centralisé dans le resolver et limité au périmètre
/// `legacy-gironde`.
class OrganizationContextController
    extends ValueNotifier<OrganizationContext?> {
  OrganizationContextController({
    required OrganizationReadRepository repository,
    LegacyOrganizationResolver resolver = const LegacyOrganizationResolver(),
  }) : _repository = repository,
       _resolver = resolver,
       super(null);

  final OrganizationReadRepository _repository;
  final LegacyOrganizationResolver _resolver;

  StreamSubscription<OrganizationMembership?>? _membershipSubscription;
  StreamSubscription<Organization?>? _organizationSubscription;
  int _resolutionGeneration = 0;
  ({String uid, Set<String> roles, bool platformAdministrator})? _identity;

  /// Résout la session privilégiée RC3 dans l'organisation legacy canonique.
  ///
  /// La valeur legacy est publiée immédiatement pendant la lecture RC4. Une
  /// membership explicite, y compris inactive, devient ensuite prioritaire.
  void resolveLegacyIdentity({
    required String uid,
    Iterable<String> legacyRoleValues = const [],
    bool isPlatformAdministrator = false,
  }) {
    final roles = Set<String>.unmodifiable(legacyRoleValues);
    final identity = (
      uid: uid,
      roles: roles,
      platformAdministrator: isPlatformAdministrator,
    );
    if (_sameIdentity(_identity, identity)) return;
    _identity = identity;
    final generation = ++_resolutionGeneration;
    unawaited(_membershipSubscription?.cancel());
    unawaited(_organizationSubscription?.cancel());
    _organizationSubscription = null;

    _publishLegacyFallback(identity);
    _membershipSubscription = _repository
        .watchMembership(
          organizationId: LegacyOrganizationResolver.legacyOrganizationId,
          uid: uid,
        )
        .listen(
          (membership) => _handleMembership(
            identity: identity,
            membership: membership,
            generation: generation,
          ),
          onError: (Object error, StackTrace stackTrace) {
            if (generation != _resolutionGeneration) return;
            debugPrint('Lecture membership Organisation indisponible : $error');
            _publishLegacyFallback(identity);
          },
        );
  }

  /// Retire le contexte privilégié, notamment pour le parcours Professionnel.
  void clear() {
    if (_identity == null && value == null) return;
    _identity = null;
    _resolutionGeneration++;
    unawaited(_membershipSubscription?.cancel());
    unawaited(_organizationSubscription?.cancel());
    _membershipSubscription = null;
    _organizationSubscription = null;
    value = null;
  }

  /// Instrumentation centrale de la propriété d'une opération.
  String resolveOperationOrganizationId(Operation operation) =>
      _resolver.resolveOperationOrganizationId(operation);

  void _handleMembership({
    required ({String uid, Set<String> roles, bool platformAdministrator})
    identity,
    required OrganizationMembership? membership,
    required int generation,
  }) {
    if (generation != _resolutionGeneration) return;
    unawaited(_organizationSubscription?.cancel());
    _organizationSubscription = null;

    if (membership?.active != true && !identity.platformAdministrator) {
      _publish(
        identity: identity,
        organization: LegacyOrganizationResolver.legacyOrganization,
        membership: membership,
      );
      return;
    }

    _organizationSubscription = _repository
        .watchOrganization(LegacyOrganizationResolver.legacyOrganizationId)
        .listen(
          (organization) {
            if (generation != _resolutionGeneration) return;
            _publish(
              identity: identity,
              organization:
                  organization ?? LegacyOrganizationResolver.legacyOrganization,
              membership: membership,
            );
          },
          onError: (Object error, StackTrace stackTrace) {
            if (generation != _resolutionGeneration) return;
            debugPrint('Lecture organisation legacy indisponible : $error');
            _publish(
              identity: identity,
              organization: LegacyOrganizationResolver.legacyOrganization,
              membership: membership,
            );
          },
        );
  }

  void _publishLegacyFallback(
    ({String uid, Set<String> roles, bool platformAdministrator}) identity,
  ) {
    _publish(
      identity: identity,
      organization: LegacyOrganizationResolver.legacyOrganization,
    );
  }

  void _publish({
    required ({String uid, Set<String> roles, bool platformAdministrator})
    identity,
    required Organization organization,
    OrganizationMembership? membership,
  }) {
    value = _resolver.resolveContext(
      uid: identity.uid,
      selectedOrganization: organization,
      membership: membership,
      legacyRoleValues: identity.roles,
      isPlatformAdministrator: identity.platformAdministrator,
    );
  }

  @override
  void dispose() {
    _resolutionGeneration++;
    unawaited(_membershipSubscription?.cancel());
    unawaited(_organizationSubscription?.cancel());
    super.dispose();
  }
}

/// Accès central au contexte courant pour les futurs repositories contextualisés.
class OrganizationContextScope
    extends InheritedNotifier<OrganizationContextController> {
  const OrganizationContextScope({
    super.key,
    required OrganizationContextController controller,
    required super.child,
  }) : super(notifier: controller);

  static OrganizationContext? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<OrganizationContextScope>()
      ?.notifier
      ?.value;

  /// Accès non réactif utilisé par la couche de routage pour alimenter le scope.
  static OrganizationContextController controllerOf(BuildContext context) {
    final scope = context
        .getInheritedWidgetOfExactType<OrganizationContextScope>();
    assert(scope != null, 'OrganizationContextScope absent de l’arbre');
    return scope!.notifier!;
  }

  /// Compatibilité des harnais RC3 qui instancient encore AppShell isolément.
  static OrganizationContextController? maybeControllerOf(
    BuildContext context,
  ) => context
      .getInheritedWidgetOfExactType<OrganizationContextScope>()
      ?.notifier;
}

/// Gère le cycle de vie du contrôleur au niveau de l'infrastructure applicative.
class OrganizationContextBootstrap extends StatefulWidget {
  const OrganizationContextBootstrap({
    super.key,
    required this.repository,
    required this.child,
    this.controller,
  });

  final OrganizationReadRepository repository;
  final OrganizationContextController? controller;
  final Widget child;

  @override
  State<OrganizationContextBootstrap> createState() =>
      _OrganizationContextBootstrapState();
}

class _OrganizationContextBootstrapState
    extends State<OrganizationContextBootstrap> {
  late OrganizationContextController _controller;
  late bool _ownsController;

  @override
  void initState() {
    super.initState();
    _installController();
  }

  @override
  void didUpdateWidget(covariant OrganizationContextBootstrap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository) ||
        !identical(oldWidget.controller, widget.controller)) {
      if (_ownsController) _controller.dispose();
      _installController();
    }
  }

  void _installController() {
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ??
        OrganizationContextController(repository: widget.repository);
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      OrganizationContextScope(controller: _controller, child: widget.child);
}

bool _sameIdentity(
  ({String uid, Set<String> roles, bool platformAdministrator})? left,
  ({String uid, Set<String> roles, bool platformAdministrator}) right,
) =>
    left != null &&
    left.uid == right.uid &&
    left.platformAdministrator == right.platformAdministrator &&
    left.roles.length == right.roles.length &&
    left.roles.containsAll(right.roles);
