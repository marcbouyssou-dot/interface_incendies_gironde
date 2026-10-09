import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/v5_secondary_navigation.dart';

/// Minimal controlled-beta invitation console. The callables enforce the
/// administrator role; the code stays in memory and is displayed only once.
class PlatformAdminProfessionalInvitationsScreen extends StatefulWidget {
  const PlatformAdminProfessionalInvitationsScreen({super.key});

  @override
  State<PlatformAdminProfessionalInvitationsScreen> createState() =>
      _PlatformAdminProfessionalInvitationsScreenState();
}

class _PlatformAdminProfessionalInvitationsScreenState
    extends State<PlatformAdminProfessionalInvitationsScreen> {
  final _email = TextEditingController();
  final _days = TextEditingController(text: '7');
  final _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
  late final Future<QuerySnapshot<Map<String, dynamic>>> _operations;
  List<Map<String, dynamic>> _invitations = const [];
  String? _operationId;
  String _profession = 'physiotherapist';
  String? _invitationId;
  String? _code;
  String? _status;
  String? _delivery;
  String? _message;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _operations = FirebaseFirestore.instance
        .collection('operations')
        .where('status', isEqualTo: 'active')
        .get();
    _loadInvitations();
  }

  Future<void> _loadInvitations() async {
    try {
      final response = await _call('listProfessionalInvitations', {});
      if (!mounted) return;
      setState(
        () => _invitations = (response['invitations'] as List)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList(),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Liste des invitations indisponible.');
      }
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _days.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, Object?> data,
  ) async {
    final response = await _functions.httpsCallable(name).call<Map>(data);
    return Map<String, dynamic>.from(response.data);
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Opération indisponible. Vérifiez les données et réessayez.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create(Map<String, dynamic> operation) async {
    final days = int.tryParse(_days.text.trim());
    if (days == null || days < 1 || days > 30) {
      setState(() => _message = 'Expiration entre 1 et 30 jours.');
      return;
    }
    await _run(() async {
      final result = await _call('createProfessionalInvitation', {
        'organizationId': operation['ownerOrganizationId'],
        'operationId': _operationId,
        'targetEmail': _email.text.trim(),
        'expectedProfession': _profession,
        'expiresAt': DateTime.now()
            .add(Duration(days: days))
            .toUtc()
            .toIso8601String(),
      });
      if (!mounted) return;
      setState(() {
        _invitationId = result['invitationId'] as String?;
        _code = result['code'] as String?;
        _status = 'valid';
        _delivery = 'pending';
        _message =
            'Invitation préparée. Le code disparaît en quittant cet écran : '
            'copiez-le ou envoyez l’e-mail maintenant. Si vous le perdez, '
            'révoquez puis créez une nouvelle invitation.';
      });
      await _loadInvitations();
    });
  }

  Future<void> _refresh() async {
    if (_invitationId == null) return;
    await _run(() async {
      final result = await _call('getProfessionalInvitationStatus', {
        'invitationId': _invitationId,
      });
      if (mounted) {
        setState(() {
          _status = result['status'] as String?;
          _delivery = result['deliveryStatus'] as String?;
        });
      }
      await _loadInvitations();
    });
  }

  Future<void> _send() async {
    if (_code == null) return;
    await _run(() async {
      await _call('sendProfessionalInvitationEmail', {'code': _code});
      if (mounted) {
        setState(() {
          _delivery = 'sent';
          _message =
              'Envoi accepté par le fournisseur. Vérifiez la réception avant la bascule.';
        });
      }
      await _loadInvitations();
    });
  }

  Future<void> _revoke() async {
    if (_invitationId == null) return;
    await _run(() async {
      await _call('revokeProfessionalInvitation', {
        'invitationId': _invitationId,
      });
      if (mounted) {
        setState(() {
          _status = 'revoked';
          _code = null;
        });
      }
      await _loadInvitations();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const V5SecondaryNavigationBar(title: 'Invitations Professionnels'),
    body: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
      future: _operations,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Actions indisponibles.'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final operations = snapshot.data!.docs
            .where(
              (doc) =>
                  doc.data()['purpose'] == null ||
                  doc.data()['purpose'] == 'operational',
            )
            .toList();
        final selected = operations
            .where((doc) => doc.id == _operationId)
            .firstOrNull;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Bêta contrôlée : une invitation personnelle par Action et profession.',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: selected?.id,
              decoration: const InputDecoration(labelText: 'Action'),
              items: operations
                  .map(
                    (doc) => DropdownMenuItem(
                      value: doc.id,
                      child: Text(
                        '${doc.data()['name'] ?? doc.id} (${doc.id})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _operationId = value),
            ),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'E-mail du destinataire',
              ),
            ),
            DropdownButtonFormField<String>(
              initialValue: _profession,
              decoration: const InputDecoration(labelText: 'Profession'),
              items: const [
                DropdownMenuItem(
                  value: 'physiotherapist',
                  child: Text('Masseur-kinésithérapeute'),
                ),
                DropdownMenuItem(
                  value: 'podiatrist',
                  child: Text('Pédicure-podologue'),
                ),
                DropdownMenuItem(value: 'physician', child: Text('Médecin')),
                DropdownMenuItem(
                  value: 'nurse',
                  child: Text('Infirmier / infirmière'),
                ),
              ],
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _profession = value!),
            ),
            TextField(
              controller: _days,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Expiration (jours, 1 à 30)',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy || selected == null
                  ? null
                  : () => _create(selected.data()),
              child: const Text('Préparer l’invitation'),
            ),
            if (_invitationId != null) ...[
              const Divider(height: 32),
              Text(
                'Statut : ${_status ?? 'inconnu'} · E-mail : ${_delivery ?? 'inconnu'}',
              ),
              Text('Identifiant : $_invitationId'),
              if (_code != null && _status == 'valid') ...[
                SelectableText('Code personnel : $_code'),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () =>
                          Clipboard.setData(ClipboardData(text: _code!)),
                      child: const Text('Copier le code'),
                    ),
                    OutlinedButton(
                      onPressed: _busy ? null : _send,
                      child: const Text('Envoyer l’e-mail'),
                    ),
                  ],
                ),
              ],
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: _busy ? null : _refresh,
                    child: const Text('Actualiser le statut'),
                  ),
                  if (_status == 'valid')
                    TextButton(
                      onPressed: _busy ? null : _revoke,
                      child: const Text('Révoquer'),
                    ),
                ],
              ),
            ],
            if (_message != null) Text(_message!),
            const Divider(height: 32),
            const Text('Invitations récentes (50 maximum)'),
            for (final invitation in _invitations)
              ListTile(
                title: Text(
                  '${invitation['targetEmailNormalized'] ?? 'Destinataire inconnu'} · '
                  '${invitation['operationId'] ?? 'Action inconnue'}',
                ),
                subtitle: Text(
                  '${invitation['expectedProfession'] ?? 'Profession inconnue'} · '
                  '${invitation['status'] ?? 'inconnu'} · '
                  'E-mail ${invitation['deliveryStatus'] ?? 'inconnu'} · '
                  'expire ${invitation['expiresAt'] ?? 'inconnu'}',
                ),
                onTap: _busy
                    ? null
                    : () => setState(() {
                        _invitationId = invitation['invitationId'] as String?;
                        _status = invitation['status'] as String?;
                        _delivery = invitation['deliveryStatus'] as String?;
                        _code = null;
                      }),
              ),
          ],
        );
      },
    ),
  );
}
