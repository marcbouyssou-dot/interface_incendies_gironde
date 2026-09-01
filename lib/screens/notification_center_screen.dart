import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../models/need.dart';
import '../repositories/coordination_repository.dart';
import '../repositories/live_data_scope.dart';
import '../repositories/repository_scope.dart';
import '../services/push_notification_gateway.dart';
import '../services/platform_administration_service.dart';
import '../theme/v5_foundation.dart';
import '../utils/app_page_route.dart';
import '../widgets/common.dart';
import '../widgets/v5_controls.dart';
import '../widgets/v5_form_system.dart';

abstract final class AdminNotificationHydrationTraceState {
  static const identityReady = 'ADMIN_IDENTITY_READY';
  static const firestoreSubscriptionReadStarted =
      'FIRESTORE_SUBSCRIPTION_READ_STARTED';
  static const firestoreSubscriptionReadOk = 'FIRESTORE_SUBSCRIPTION_READ_OK';
  static const firestoreSubscriptionReadFailed =
      'FIRESTORE_SUBSCRIPTION_READ_FAILED';
  static const firestoreSubscriptionReadTimeout =
      'FIRESTORE_SUBSCRIPTION_READ_TIMEOUT';
  static const preflightStarted = 'ADMIN_PREFLIGHT_STARTED';
  static const preflightOk = 'ADMIN_PREFLIGHT_OK';
  static const preflightFailed = 'ADMIN_PREFLIGHT_FAILED';
}

void emitAdminNotificationHydrationTrace(
  void Function(String state) trace,
  String state,
) {
  try {
    trace(state);
  } catch (_) {
    // Diagnostic output must never affect notification hydration.
  }
}

Future<T> runTracedAdminSubscriptionRead<T>({
  required Future<T> Function() read,
  required void Function(String state) trace,
  Duration observationDelay = const Duration(seconds: 15),
}) async {
  emitAdminNotificationHydrationTrace(
    trace,
    AdminNotificationHydrationTraceState.firestoreSubscriptionReadStarted,
  );
  var completed = false;
  final observer = Timer(observationDelay, () {
    if (!completed) {
      emitAdminNotificationHydrationTrace(
        trace,
        AdminNotificationHydrationTraceState.firestoreSubscriptionReadTimeout,
      );
    }
  });
  try {
    final result = await read();
    completed = true;
    emitAdminNotificationHydrationTrace(
      trace,
      AdminNotificationHydrationTraceState.firestoreSubscriptionReadOk,
    );
    return result;
  } catch (_) {
    completed = true;
    emitAdminNotificationHydrationTrace(
      trace,
      AdminNotificationHydrationTraceState.firestoreSubscriptionReadFailed,
    );
    rethrow;
  } finally {
    observer.cancel();
  }
}

Future<bool> runTracedAdminPreflight({
  required Future<bool> Function() preflight,
  required void Function(String state) trace,
}) async {
  emitAdminNotificationHydrationTrace(
    trace,
    AdminNotificationHydrationTraceState.preflightStarted,
  );
  try {
    final result = await preflight();
    emitAdminNotificationHydrationTrace(
      trace,
      result
          ? AdminNotificationHydrationTraceState.preflightOk
          : AdminNotificationHydrationTraceState.preflightFailed,
    );
    return result;
  } catch (_) {
    emitAdminNotificationHydrationTrace(
      trace,
      AdminNotificationHydrationTraceState.preflightFailed,
    );
    rethrow;
  }
}

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({
    super.key,
    this.pushGateway,
    this.targetedPushTestService,
    this.initialNotificationId,
  });

  final PushNotificationGateway? pushGateway;
  final TargetedPushTestService? targetedPushTestService;
  final String? initialNotificationId;

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  late final PushNotificationGateway _pushGateway;
  CoordinationRepository? _repository;
  Stream<List<AppNotification>>? _notifications;
  Stream<NotificationPreferences>? _preferences;
  PushPermissionState? _permission;
  bool _activating = false;
  bool _hydratingPush = true;
  PushSubscriptionState _subscriptionState = PushSubscriptionState.absent;
  bool _subscriptionPersisted = false;
  bool _localInstallationReady = false;
  bool _adminTargetResolvable = false;
  String? _adminInstallationId;
  bool _activationFailed = false;
  bool _consentDeferred = false;
  bool _sendingPushTest = false;
  bool _initialNotificationHandled = false;
  StreamSubscription<PushSubscriptionRegistration>? _registrationSubscription;

  @override
  void initState() {
    super.initState();
    _pushGateway = widget.pushGateway ?? createPushNotificationGateway();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repository = RepositoryScope.of(context);
    if (identical(repository, _repository)) return;
    _repository = repository;
    _hydratingPush = true;
    _localInstallationReady = false;
    _adminTargetResolvable = false;
    _adminInstallationId = null;
    _notifications = repository.watchNotifications();
    _preferences = repository.watchNotificationPreferences();
    unawaited(_hydratePushSubscription(repository));
    unawaited(_registrationSubscription?.cancel());
    if (widget.targetedPushTestService == null) {
      _registrationSubscription = _pushGateway.registrationUpdates.listen(
        (registration) =>
            unawaited(_persistRefreshedRegistration(registration)),
        onError: (Object _, StackTrace _) {
          if (mounted) {
            setState(() {
              _subscriptionPersisted = false;
              _activationFailed = true;
            });
          }
        },
      );
    }
  }

  Future<void> _hydratePushSubscription(
    CoordinationRepository repository,
  ) async {
    PushPermissionState? permission;
    var subscriptionState = PushSubscriptionState.absent;
    try {
      permission = await _pushGateway.permissionState();
      var persisted = false;
      final pushRepository = repository is PushSubscriptionReadRepository
          ? repository as PushSubscriptionReadRepository
          : null;
      if (widget.targetedPushTestService case final adminService?) {
        final identityRepository =
            repository is AdministrativeIdentityReadRepository
            ? repository as AdministrativeIdentityReadRepository
            : null;
        final ownerIdentity = identityRepository == null
            ? null
            : await identityRepository.watchAdministrativeUid().first;
        _traceAdminHydration(
          AdminNotificationHydrationTraceState.identityReady,
        );
        final adminInstallationId = _pushGateway.existingInstallationId;
        if (permission == PushPermissionState.granted &&
            pushRepository != null &&
            adminInstallationId != null) {
          subscriptionState = await runTracedAdminSubscriptionRead(
            read: () =>
                pushRepository.readPushSubscriptionState(adminInstallationId),
            trace: _traceAdminHydration,
          );
        }
        if (!await _isCurrentPushHydration(
          repository,
          identityRepository,
          ownerIdentity,
        )) {
          _finishCancelledPushHydration(repository, permission);
          return;
        }
        final localReady =
            adminInstallationId != null &&
            permission == PushPermissionState.granted &&
            await _pushGateway.hasUsableLocalSubscription();
        final targetResolvable = localReady
            ? await runTracedAdminPreflight(
                preflight: () => adminService.canSendTargetedPushTest(
                  installationId: adminInstallationId,
                ),
                trace: _traceAdminHydration,
              )
            : false;
        if (!await _isCurrentPushHydration(
          repository,
          identityRepository,
          ownerIdentity,
        )) {
          _finishCancelledPushHydration(repository, permission);
          return;
        }
        setState(() {
          _permission = permission;
          _subscriptionState = subscriptionState;
          _subscriptionPersisted =
              subscriptionState == PushSubscriptionState.active;
          _localInstallationReady = localReady;
          _adminTargetResolvable = targetResolvable;
          _adminInstallationId = adminInstallationId;
          _activationFailed = false;
          _hydratingPush = false;
        });
        return;
      }
      if (permission == PushPermissionState.granted && pushRepository != null) {
        final identityRepository =
            repository is AdministrativeIdentityReadRepository
            ? repository as AdministrativeIdentityReadRepository
            : null;
        final ownerIdentity = identityRepository == null
            ? null
            : await identityRepository.watchAdministrativeUid().first;
        subscriptionState = await pushRepository.readPushSubscriptionState(
          _pushGateway.installationId,
        );
        if (!await _isCurrentPushHydration(
          repository,
          identityRepository,
          ownerIdentity,
        )) {
          _finishCancelledPushHydration(repository, permission);
          return;
        }
        if (subscriptionState == PushSubscriptionState.active) {
          final registration = await _pushGateway.reconcileRegistration();
          final current = await _isCurrentPushHydration(
            repository,
            identityRepository,
            ownerIdentity,
          );
          if (!current) {
            _finishCancelledPushHydration(repository, permission);
            return;
          }
          if (registration != null &&
              registration.installationId == _pushGateway.installationId) {
            persisted = await _persist(registration, repository: repository);
          }
        } else if (subscriptionState == PushSubscriptionState.stale) {
          _tracePushRecovery(PushRecoveryTraceState.recoveryStarted);
          try {
            final recoveryGateway = _pushGateway is PushStaleRecoveryGateway
                ? _pushGateway as PushStaleRecoveryGateway
                : null;
            final registration = await recoveryGateway
                ?.recoverStaleRegistration();
            final current = await _isCurrentPushHydration(
              repository,
              identityRepository,
              ownerIdentity,
            );
            if (!current) {
              _tracePushRecovery(PushRecoveryTraceState.recoveryFailed);
              _finishCancelledPushHydration(repository, permission);
              return;
            }
            if (registration != null &&
                registration.installationId == _pushGateway.installationId) {
              _tracePushRecovery(PushRecoveryTraceState.persistStarted);
              persisted = await _persist(registration, repository: repository);
              _tracePushRecovery(
                persisted
                    ? PushRecoveryTraceState.persistOk
                    : PushRecoveryTraceState.persistFailed,
              );
              if (persisted) subscriptionState = PushSubscriptionState.active;
            }
            _tracePushRecovery(
              persisted
                  ? PushRecoveryTraceState.recoveryReady
                  : PushRecoveryTraceState.recoveryFailed,
            );
          } catch (_) {
            _tracePushRecovery(PushRecoveryTraceState.recoveryFailed);
            rethrow;
          }
        }
      }
      if (!mounted || !identical(repository, _repository)) return;
      setState(() {
        _permission = permission;
        _subscriptionState = subscriptionState;
        _subscriptionPersisted = persisted;
        _activationFailed = false;
        _hydratingPush = false;
      });
    } catch (_) {
      if (!mounted || !identical(repository, _repository)) return;
      setState(() {
        _permission = permission;
        _subscriptionState = subscriptionState;
        _subscriptionPersisted = false;
        _localInstallationReady = false;
        _adminTargetResolvable = false;
        _adminInstallationId = null;
        _activationFailed = permission == PushPermissionState.granted;
        _hydratingPush = false;
      });
    }
  }

  void _finishCancelledPushHydration(
    CoordinationRepository repository,
    PushPermissionState? permission,
  ) {
    if (!mounted || !identical(repository, _repository)) return;
    setState(() {
      _permission = permission;
      _subscriptionState = PushSubscriptionState.absent;
      _subscriptionPersisted = false;
      _localInstallationReady = false;
      _adminTargetResolvable = false;
      _adminInstallationId = null;
      _activationFailed = permission == PushPermissionState.granted;
      _hydratingPush = false;
    });
  }

  void _tracePushRecovery(String state) {
    try {
      debugPrint(state);
    } catch (_) {
      // Diagnostic output must never affect notification activation.
    }
  }

  void _traceAdminHydration(String state) {
    emitAdminNotificationHydrationTrace(debugPrint, state);
  }

  Future<bool> _isCurrentPushHydration(
    CoordinationRepository repository,
    AdministrativeIdentityReadRepository? identityRepository,
    String? ownerIdentity,
  ) async {
    if (!mounted || !identical(repository, _repository)) return false;
    if (identityRepository == null) return true;
    try {
      final currentIdentity = await identityRepository
          .watchAdministrativeUid()
          .first;
      return mounted &&
          identical(repository, _repository) &&
          currentIdentity == ownerIdentity;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    unawaited(_registrationSubscription?.cancel());
    super.dispose();
  }

  Future<void> _activate() async {
    if (_activating) return;
    final staleRecovery =
        _permission == PushPermissionState.granted &&
        _subscriptionState == PushSubscriptionState.stale;
    if (staleRecovery) {
      _tracePushRecovery(PushRecoveryTraceState.recoveryStarted);
    } else {
      _tracePushActivation(PushActivationTraceState.activationStarted);
    }
    setState(() {
      _activating = true;
      _activationFailed = false;
    });
    try {
      final recoveryGateway = _pushGateway is PushStaleRecoveryGateway
          ? _pushGateway as PushStaleRecoveryGateway
          : null;
      final result = staleRecovery
          ? PushActivationResult(
              PushPermissionState.granted,
              registration: await recoveryGateway?.recoverStaleRegistration(),
            )
          : await _pushGateway.activate();
      var persisted = false;
      if (result.registration case final registration?) {
        if (staleRecovery) {
          _tracePushRecovery(PushRecoveryTraceState.persistStarted);
        } else {
          _tracePushActivation(PushActivationTraceState.persistStarted);
        }
        persisted = staleRecovery
            ? await _persist(registration)
            : await _persistActivation(registration);
        if (staleRecovery) {
          _tracePushRecovery(
            persisted
                ? PushRecoveryTraceState.persistOk
                : PushRecoveryTraceState.persistFailed,
          );
        } else {
          _tracePushActivation(
            persisted
                ? PushActivationTraceState.persistOk
                : PushActivationTraceState.persistFailed,
          );
        }
      }
      if (staleRecovery) {
        _tracePushRecovery(
          persisted
              ? PushRecoveryTraceState.recoveryReady
              : PushRecoveryTraceState.recoveryFailed,
        );
      } else {
        _tracePushActivation(
          persisted
              ? PushActivationTraceState.activationReady
              : PushActivationTraceState.activationFailed,
        );
      }
      if (mounted) {
        setState(() {
          _permission = result.state;
          if (persisted) _subscriptionState = PushSubscriptionState.active;
          _subscriptionPersisted =
              result.state == PushPermissionState.granted && persisted;
          _activationFailed =
              result.state == PushPermissionState.granted && !persisted;
        });
      }
    } catch (_) {
      if (staleRecovery) {
        _tracePushRecovery(PushRecoveryTraceState.recoveryFailed);
      } else {
        _tracePushActivation(PushActivationTraceState.activationFailed);
      }
      if (mounted) {
        setState(() {
          _subscriptionPersisted = false;
          _activationFailed = true;
        });
      }
    } finally {
      if (mounted) setState(() => _activating = false);
    }
  }

  Future<bool> _persist(
    PushSubscriptionRegistration registration, {
    CoordinationRepository? repository,
  }) async {
    try {
      await (repository ?? _repository!).registerPushSubscription(registration);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _persistActivation(
    PushSubscriptionRegistration registration,
  ) async {
    try {
      final repository = _repository!;
      final activationRepository =
          repository is PushActivationPersistenceRepository
          ? repository as PushActivationPersistenceRepository
          : null;
      if (activationRepository != null) {
        await activationRepository.registerPushSubscriptionForActivation(
          registration,
          onTokenCompared: (tokenChanged) => _tracePushActivation(
            tokenChanged
                ? PushActivationTraceState.tokenChanged
                : PushActivationTraceState.tokenUnchanged,
          ),
        );
      } else {
        await repository.registerPushSubscription(registration);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  void _tracePushActivation(String state) {
    emitPushActivationTrace(debugPrint, state);
  }

  Future<void> _persistRefreshedRegistration(
    PushSubscriptionRegistration registration,
  ) async {
    final persisted = await _persist(registration);
    if (!mounted) return;
    setState(() {
      _permission = PushPermissionState.granted;
      if (persisted) _subscriptionState = PushSubscriptionState.active;
      _subscriptionPersisted = persisted;
      _activationFailed = !persisted;
    });
  }

  Future<void> _sendPushTest() async {
    final service = widget.targetedPushTestService;
    final adminInstallationId = _adminInstallationId;
    if (service == null ||
        adminInstallationId == null ||
        !_localInstallationReady ||
        !_adminTargetResolvable ||
        _hydratingPush ||
        _sendingPushTest) {
      return;
    }
    setState(() => _sendingPushTest = true);
    try {
      final confirmed = await showV5Confirmation(
        context: context,
        title: 'Envoyer une notification test ?',
        message:
            'Une seule notification neutre sera envoyée à cette installation. '
            'Un test réussi ne pourra pas être répété.',
        cancelLabel: 'Annuler',
        confirmLabel: 'Envoyer le test',
        barrierDismissible: false,
        icon: Icons.notification_add_outlined,
        cancelKey: const Key('cancel-targeted-push-test'),
        confirmKey: const Key('confirm-targeted-push-test'),
      );
      if (confirmed != true || !mounted) return;
      await service.sendTargetedPushTest(installationId: adminInstallationId);
      if (!mounted) return;
      V5Toast.show(
        context,
        message: 'Notification test envoyée à cette installation.',
        tone: V5ToastTone.success,
      );
    } on PlatformAdministrationException catch (error) {
      if (!mounted) return;
      V5Toast.show(context, message: error.message, tone: V5ToastTone.danger);
    } catch (_) {
      if (!mounted) return;
      V5Toast.show(
        context,
        message: 'La notification test n’a pas pu être envoyée.',
        tone: V5ToastTone.danger,
      );
    } finally {
      if (mounted) setState(() => _sendingPushTest = false);
    }
  }

  Future<void> _open(AppNotification notification) async {
    if (!notification.isRead) {
      await _repository!.setNotificationRead(notification.id, read: true);
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => RepositoryScope(
          repository: _repository!,
          child: _NotificationMissionDestination(notification: notification),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.v5Colors.canvas,
    body: SafeArea(
      child: StreamBuilder<List<AppNotification>>(
        stream: _notifications,
        builder: (context, snapshot) {
          final notifications = snapshot.data ?? const <AppNotification>[];
          _scheduleInitialNotification(notifications);
          final unreadNotifications = notifications
              .where((item) => !item.isRead)
              .toList(growable: false);
          final recentNotifications = notifications
              .where((item) => item.isRead)
              .toList(growable: false);
          final unread = unreadNotifications.length;
          unawaited(_pushGateway.updateBadge(unread));
          return ListView(
            key: const Key('notification-center'),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 36),
            children: [
              Row(
                children: [
                  IconButton(
                    key: const Key('notification-center-close'),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Fermer',
                    icon: const Icon(Icons.close_rounded),
                  ),
                  const SizedBox(width: V5Spacing.xs),
                  Expanded(
                    child: Text(
                      'Notifications',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  if (unread > 0)
                    Semantics(
                      label: '$unread notifications non lues',
                      child: Badge(label: Text('$unread')),
                    ),
                ],
              ),
              const SizedBox(height: V5Spacing.lg),
              if (widget.targetedPushTestService == null &&
                  !_consentDeferred) ...[
                _ConsentCard(
                  permission: _permission,
                  activating: _activating || _hydratingPush,
                  subscriptionPersisted: _subscriptionPersisted,
                  activationFailed: _activationFailed,
                  onActivate: _activate,
                  onLater: () => setState(() => _consentDeferred = true),
                ),
                const SizedBox(height: V5Spacing.lg),
              ],
              StreamBuilder<NotificationPreferences>(
                stream: _preferences,
                builder: (context, preferenceSnapshot) => _PreferencesCard(
                  preferences:
                      preferenceSnapshot.data ??
                      const NotificationPreferences(),
                  onChanged: _repository!.saveNotificationPreferences,
                ),
              ),
              if (widget.targetedPushTestService != null) ...[
                const SizedBox(height: V5Spacing.lg),
                _AdminPushTestCard(
                  localInstallationReady: _localInstallationReady,
                  currentIdentityActive: _subscriptionPersisted,
                  targetResolvable: _adminTargetResolvable,
                  checking: _hydratingPush,
                  sending: _sendingPushTest,
                  onSend: _sendPushTest,
                ),
              ],
              const SizedBox(height: V5Spacing.xl),
              if (snapshot.connectionState == ConnectionState.waiting)
                const V5LoadingState(label: 'Chargement des notifications…')
              else if (snapshot.hasError)
                const V5EmptyState(
                  title: 'Notifications indisponibles',
                  message: 'Réessayez dans quelques instants.',
                )
              else if (notifications.isEmpty)
                const V5EmptyState(
                  title: 'Aucune notification',
                  message: 'Les informations utiles apparaîtront ici.',
                )
              else ...[
                if (unreadNotifications.isNotEmpty) ...[
                  Text(
                    'Non lues',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: V5Spacing.sm),
                ],
                for (final notification in unreadNotifications)
                  _NotificationTile(
                    notification: notification,
                    onTap: () => _open(notification),
                    onToggleRead: () => _repository!.setNotificationRead(
                      notification.id,
                      read: !notification.isRead,
                    ),
                  ),
                if (recentNotifications.isNotEmpty) ...[
                  const SizedBox(height: V5Spacing.lg),
                  Text(
                    'Récentes',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: V5Spacing.sm),
                ],
                for (final notification in recentNotifications)
                  _NotificationTile(
                    notification: notification,
                    onTap: () => _open(notification),
                    onToggleRead: () => _repository!.setNotificationRead(
                      notification.id,
                      read: !notification.isRead,
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    ),
  );

  void _scheduleInitialNotification(List<AppNotification> notifications) {
    final initialId = widget.initialNotificationId;
    if (_initialNotificationHandled || initialId == null) return;
    final notification = notifications
        .where((item) => item.id == initialId)
        .firstOrNull;
    if (notification == null) return;
    _initialNotificationHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_open(notification));
    });
  }
}

class _AdminPushTestCard extends StatelessWidget {
  const _AdminPushTestCard({
    required this.localInstallationReady,
    required this.currentIdentityActive,
    required this.targetResolvable,
    required this.checking,
    required this.sending,
    required this.onSend,
  });

  final bool localInstallationReady;
  final bool currentIdentityActive;
  final bool targetResolvable;
  final bool checking;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => V5Section(
    title: 'Diagnostic administrateur',
    leading: const Icon(Icons.admin_panel_settings_outlined),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localInstallationReady
              ? 'Abonnement local valide sur cette installation.'
              : 'Aucun abonnement local valide sur cette installation.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: V5Spacing.xs),
        Text(
          currentIdentityActive
              ? 'Identité courante associée à cet abonnement.'
              : 'Identité courante distincte de l’abonnement de l’installation.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: V5Spacing.xs),
        Text(
          checking
              ? 'Vérification de la cible administrateur…'
              : targetResolvable
              ? 'Une cible administrateur ACTIVE a été résolue.'
              : 'Aucune cible administrateur unique et ACTIVE n’est disponible.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: V5Spacing.sm),
        V5Button(
          key: const Key('send-targeted-push-test'),
          label: sending ? 'Envoi en cours…' : 'Envoyer une notification test',
          icon: Icons.notification_add_outlined,
          tone: V5ButtonTone.secondary,
          onPressed:
              localInstallationReady &&
                  targetResolvable &&
                  !checking &&
                  !sending
              ? onSend
              : null,
        ),
      ],
    ),
  );
}

class _ConsentCard extends StatelessWidget {
  const _ConsentCard({
    required this.permission,
    required this.activating,
    required this.subscriptionPersisted,
    required this.activationFailed,
    required this.onActivate,
    required this.onLater,
  });

  final PushPermissionState? permission;
  final bool activating;
  final bool subscriptionPersisted;
  final bool activationFailed;
  final VoidCallback onActivate;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final unsupported = permission == PushPermissionState.unsupported;
    final misconfigured = permission == PushPermissionState.misconfigured;
    final unavailable = unsupported || misconfigured;
    final activated =
        permission == PushPermissionState.granted && subscriptionPersisted;
    final incomplete =
        activationFailed ||
        (permission == PushPermissionState.granted && !subscriptionPersisted);
    return Container(
      key: const Key('notification-consent-card'),
      padding: const EdgeInsets.all(V5Spacing.md),
      decoration: BoxDecoration(
        color: activated
            ? colors.successContainer
            : incomplete
            ? colors.warningContainer
            : colors.infoContainer,
        borderRadius: BorderRadius.circular(V5Radius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            activated
                ? 'Notifications activées'
                : incomplete
                ? 'Activation incomplète'
                : 'Être alerté lorsqu’une mission vous concerne',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (!activated) ...[
            const SizedBox(height: V5Spacing.xs),
            Text(
              incomplete
                  ? 'L’abonnement n’a pas pu être enregistré. Réessayez.'
                  : unsupported
                  ? 'Ce navigateur ne prend pas en charge les notifications. '
                        'Sur iPhone, installez MobSanté sur l’écran d’accueil.'
                  : misconfigured
                  ? 'Les notifications sont temporairement indisponibles : '
                        'la configuration Push est incomplète.'
                  : permission == PushPermissionState.denied
                  ? 'La permission est refusée. MobSanté reste utilisable.'
                  : 'Vous gardez le contrôle et pourrez les désactiver.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: V5Spacing.sm),
            Wrap(
              spacing: V5Spacing.sm,
              children: [
                V5Button(
                  key: const Key('activate-notifications'),
                  label: incomplete ? 'Réessayer' : 'Activer les notifications',
                  icon: Icons.notifications_active_outlined,
                  onPressed: unavailable || activating ? null : onActivate,
                ),
                TextButton(
                  key: const Key('notifications-later'),
                  onPressed: onLater,
                  child: const Text('Plus tard'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PreferencesCard extends StatelessWidget {
  const _PreferencesCard({required this.preferences, required this.onChanged});
  final NotificationPreferences preferences;
  final ValueChanged<NotificationPreferences> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Préférences', style: Theme.of(context).textTheme.titleLarge),
      V5SwitchTile(
        title: 'Missions compatibles',
        value: preferences.compatibleMissions,
        onChanged: (value) =>
            onChanged(preferences.copyWith(compatibleMissions: value)),
      ),
      V5SwitchTile(
        title: 'Modifications de mes engagements',
        value: preferences.engagementUpdates,
        onChanged: (value) =>
            onChanged(preferences.copyWith(engagementUpdates: value)),
      ),
      V5SwitchTile(
        title: 'Alertes opérationnelles',
        value: preferences.operationalAlerts,
        onChanged: (value) =>
            onChanged(preferences.copyWith(operationalAlerts: value)),
      ),
    ],
  );
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onToggleRead,
  });
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onToggleRead;

  @override
  Widget build(BuildContext context) => ListTile(
    key: Key('notification-${notification.id}'),
    minVerticalPadding: 10,
    contentPadding: EdgeInsets.zero,
    leading: Icon(
      notification.isRead
          ? Icons.notifications_none_rounded
          : Icons.notifications_active_rounded,
      color: notification.isRead
          ? context.v5Colors.textSecondary
          : context.v5Colors.info,
    ),
    title: Text(notification.title),
    subtitle: Text(
      '${notification.body}\n${_relative(notification.occurredAt)}',
    ),
    isThreeLine: true,
    trailing: IconButton(
      key: Key('notification-read-${notification.id}'),
      tooltip: notification.isRead
          ? 'Marquer comme non lue'
          : 'Marquer comme lue',
      onPressed: onToggleRead,
      icon: Icon(
        notification.isRead
            ? Icons.mark_email_unread_outlined
            : Icons.mark_email_read_outlined,
      ),
    ),
    onTap: onTap,
  );
}

class _NotificationMissionDestination extends StatefulWidget {
  const _NotificationMissionDestination({required this.notification});
  final AppNotification notification;

  @override
  State<_NotificationMissionDestination> createState() =>
      _NotificationMissionDestinationState();
}

class _NotificationMissionDestinationState
    extends State<_NotificationMissionDestination> {
  CoordinationRepository? _repository;
  LiveCoordinationData? _liveData;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repository = RepositoryScope.of(context);
    if (identical(repository, _repository)) return;
    unawaited(_liveData?.dispose());
    _repository = repository;
    _liveData = LiveCoordinationData(repository);
  }

  @override
  void dispose() {
    unawaited(_liveData?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.v5Colors.canvas,
    appBar: AppBar(title: const Text('Mission')),
    body: SafeArea(
      child: FutureBuilder<CoordinationNeed?>(
        future: _repository!.getMission(widget.notification.missionId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const V5LoadingState(label: 'Ouverture de la mission…');
          }
          if (snapshot.hasError || snapshot.data == null) {
            return const V5EmptyState(
              title: 'Mission inaccessible',
              message:
                  'Elle n’existe plus ou vos droits ne permettent plus de '
                  'la consulter.',
            );
          }
          return LiveCoordinationDataScope(
            data: _liveData!,
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                NeedCard(need: snapshot.data!, professionalJourney: true),
              ],
            ),
          );
        },
      ),
    ),
  );
}

String _relative(DateTime date) {
  final elapsed = DateTime.now().difference(date);
  if (elapsed.inMinutes < 1) return 'À l’instant';
  if (elapsed.inMinutes < 60) return 'Il y a ${elapsed.inMinutes} min';
  if (elapsed.inHours < 24) return 'Il y a ${elapsed.inHours} h';
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}';
}
