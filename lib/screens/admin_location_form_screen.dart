import 'package:flutter/material.dart';

import '../models/admin_location.dart';
import '../models/need.dart';
import '../repositories/location_administration_repository.dart';
import '../repositories/location_administration_repository_scope.dart';
import '../theme/app_theme.dart';

class AdminLocationFormScreen extends StatefulWidget {
  const AdminLocationFormScreen({super.key, this.location});

  final AdminLocation? location;

  @override
  State<AdminLocationFormScreen> createState() =>
      _AdminLocationFormScreenState();
}

class _AdminLocationFormScreenState extends State<AdminLocationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _id;
  late final TextEditingController _name;
  late final TextEditingController _addressLine1;
  late final TextEditingController _addressLine2;
  late final TextEditingController _postalCode;
  late final TextEditingController _city;
  late final TextEditingController _country;
  late final TextEditingController _contactName;
  late final TextEditingController _contactPhone;
  late final TextEditingController _latitude;
  late final TextEditingController _longitude;
  late TerritorialGroup _group;
  late ResponsePlaceType _type;
  bool _submitting = false;

  bool get _editing => widget.location != null;

  @override
  void initState() {
    super.initState();
    final location = widget.location;
    _id = TextEditingController(text: location?.id);
    _name = TextEditingController(text: location?.name);
    _addressLine1 = TextEditingController(text: location?.addressLine1);
    _addressLine2 = TextEditingController(text: location?.addressLine2);
    _postalCode = TextEditingController(text: location?.postalCode);
    _city = TextEditingController(text: location?.city);
    _country = TextEditingController(text: location?.country ?? 'France');
    _contactName = TextEditingController(text: location?.contactName);
    _contactPhone = TextEditingController(text: location?.contactPhone);
    _latitude = TextEditingController(text: _coordinate(location?.latitude));
    _longitude = TextEditingController(text: _coordinate(location?.longitude));
    _group = location?.group ?? TerritorialGroup.bordeauxMetropole;
    _type = location?.type ?? ResponsePlaceType.sdisStation;
  }

  @override
  void dispose() {
    for (final controller in [
      _id,
      _name,
      _addressLine1,
      _addressLine2,
      _postalCode,
      _city,
      _country,
      _contactName,
      _contactPhone,
      _latitude,
      _longitude,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Modifier le lieu' : 'Créer un lieu'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            key: const Key('admin-location-form-list'),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              TextFormField(
                key: const Key('admin-location-id-field'),
                controller: _id,
                enabled: !_editing && !_submitting,
                decoration: const InputDecoration(
                  labelText: 'Identifiant stable',
                  helperText: 'Minuscules, chiffres et tirets uniquement.',
                ),
                validator: _validateId,
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const Key('admin-location-name-field'),
                controller: _name,
                enabled: !_submitting,
                decoration: const InputDecoration(labelText: 'Nom'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Saisissez le nom du lieu.'
                    : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<TerritorialGroup>(
                key: const Key('admin-location-group-field'),
                initialValue: _group,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Groupe territorial',
                ),
                items: [
                  for (final value in TerritorialGroup.values)
                    DropdownMenuItem(value: value, child: Text(value.label)),
                ],
                onChanged: _submitting
                    ? null
                    : (value) => setState(() => _group = value!),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<ResponsePlaceType>(
                key: const Key('admin-location-type-field'),
                initialValue: _type,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Type de lieu'),
                items: [
                  for (final value in ResponsePlaceType.values)
                    DropdownMenuItem(value: value, child: Text(value.label)),
                ],
                onChanged: _submitting
                    ? null
                    : (value) => setState(() => _type = value!),
              ),
              const SizedBox(height: 22),
              const _SectionTitle('Adresse'),
              _field(_addressLine1, 'Adresse'),
              _field(_addressLine2, 'Complément d’adresse'),
              Row(
                children: [
                  Expanded(child: _field(_postalCode, 'Code postal')),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_city, 'Commune')),
                ],
              ),
              _field(
                _country,
                'Pays',
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Saisissez le pays.'
                    : null,
              ),
              const SizedBox(height: 18),
              const _SectionTitle('Contact facultatif'),
              _field(_contactName, 'Référent'),
              _field(
                _contactPhone,
                'Téléphone',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 18),
              const _SectionTitle('Coordonnées facultatives'),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      _latitude,
                      'Latitude',
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                        decimal: true,
                      ),
                      validator: (value) =>
                          _validateCoordinate(value, min: -90, max: 90),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(
                      _longitude,
                      'Longitude',
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                        decimal: true,
                      ),
                      validator: (value) =>
                          _validateCoordinate(value, min: -180, max: 180),
                    ),
                  ),
                ],
              ),
              if (_editing) ...[
                const SizedBox(height: 10),
                Text(
                  widget.location!.active
                      ? 'Statut : Actif'
                      : 'Statut : Désactivé',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                const Text(
                  'Le statut se modifie depuis la liste des lieux.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: FilledButton(
            key: const Key('admin-location-submit'),
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_editing ? 'Enregistrer' : 'Créer le lieu'),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      enabled: !_submitting,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label),
      validator: validator,
    ),
  );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final hasLatitude = _latitude.text.trim().isNotEmpty;
    final hasLongitude = _longitude.text.trim().isNotEmpty;
    if (hasLatitude != hasLongitude) {
      _showError('Saisissez la latitude et la longitude ensemble.');
      return;
    }
    setState(() => _submitting = true);
    final draft = AdminLocationDraft(
      id: _id.text.trim(),
      name: _name.text.trim(),
      group: _group,
      type: _type,
      addressLine1: _addressLine1.text,
      addressLine2: _addressLine2.text,
      postalCode: _postalCode.text,
      city: _city.text,
      country: _country.text.trim(),
      contactName: _contactName.text,
      contactPhone: _contactPhone.text,
      latitude: hasLatitude ? double.parse(_latitude.text.trim()) : null,
      longitude: hasLongitude ? double.parse(_longitude.text.trim()) : null,
    );
    try {
      final repository = LocationAdministrationRepositoryScope.of(context);
      if (_editing) {
        await repository.updateLocation(draft);
      } else {
        await repository.createLocation(draft);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on LocationAdministrationException catch (error) {
      if (mounted) _showError(error.message);
    } catch (_) {
      if (mounted) {
        _showError('Le lieu n’a pas pu être enregistré. Réessayez.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _validateId(String? value) {
    final id = value?.trim() ?? '';
    if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(id) ||
        id.length > 120) {
      return 'Saisissez un identifiant valide.';
    }
    return null;
  }

  String? _validateCoordinate(
    String? value, {
    required double min,
    required double max,
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final coordinate = double.tryParse(text);
    if (coordinate == null || coordinate < min || coordinate > max) {
      return 'Coordonnée invalide.';
    }
    return null;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static String _coordinate(double? value) => value?.toString() ?? '';
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      label,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
    ),
  );
}
