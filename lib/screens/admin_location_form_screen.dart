import 'package:flutter/material.dart';

import '../models/admin_location.dart';
import '../models/need.dart';
import '../repositories/location_administration_repository.dart';
import '../repositories/location_administration_repository_scope.dart';
import '../widgets/common.dart';
import '../widgets/v5_form_system.dart';

abstract final class _LocationFormVisuals {
  static const background = Color(0xFFF6F7F8);
  static const surface = Colors.white;
  static const navy = Color(0xFF173052);
  static const fieldBackground = Color(0xFFF1F1EF);
  static const border = Color(0xFFE5E5E1);
  static const textMuted = Color(0xFF7C817F);
  static const orange = Color(0xFFF25C05);
  static const orangeSoft = Color(0xFFFFE8D9);
}

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
      backgroundColor: _LocationFormVisuals.background,
      appBar: AppBar(
        title: Text(_editing ? 'Modifier le lieu' : 'Créer un lieu'),
        backgroundColor: _LocationFormVisuals.background,
        foregroundColor: _LocationFormVisuals.navy,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: const TextStyle(
          color: _LocationFormVisuals.navy,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth <= 556
                ? 18.0
                : (constraints.maxWidth - 520) / 2;
            return Form(
              key: _formKey,
              child: ListView(
                key: const Key('admin-location-form-list'),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  12,
                  horizontalPadding,
                  36,
                ),
                children: [
                  _LocationFormSection(
                    icon: Icons.location_city_outlined,
                    title: 'Identité du lieu',
                    child: Column(
                      children: [
                        V5TextField(
                          key: const Key('admin-location-id-field'),
                          label: 'Identifiant stable',
                          controller: _id,
                          enabled: !_editing && !_submitting,
                          prefixIcon: const Icon(Icons.tag_rounded),
                          supportingText:
                              'Minuscules, chiffres et tirets uniquement.',
                          validator: _validateId,
                        ),
                        const SizedBox(height: AppFormLayout.fieldSpacing),
                        V5TextField(
                          key: const Key('admin-location-name-field'),
                          label: 'Nom',
                          controller: _name,
                          enabled: !_submitting,
                          prefixIcon: const Icon(Icons.business_outlined),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Saisissez le nom du lieu.'
                              : null,
                        ),
                        if (_editing) ...[
                          const SizedBox(height: 14),
                          _LocationFormStatus(active: widget.location!.active),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 13),
                  _LocationFormSection(
                    icon: Icons.map_outlined,
                    title: 'Rattachement territorial',
                    child: Column(
                      children: [
                        V5SelectField<TerritorialGroup>(
                          key: const Key('admin-location-group-field'),
                          label: 'Groupe territorial',
                          value: _group,
                          leading: const Icon(Icons.map_outlined),
                          options: [
                            for (final value in TerritorialGroup.values)
                              V5SelectOption(value: value, label: value.label),
                          ],
                          onChanged: _submitting
                              ? null
                              : (value) => setState(() => _group = value!),
                        ),
                        const SizedBox(height: AppFormLayout.fieldSpacing),
                        V5SelectField<ResponsePlaceType>(
                          key: const Key('admin-location-type-field'),
                          label: 'Type de lieu',
                          value: _type,
                          leading: const Icon(Icons.category_outlined),
                          options: [
                            for (final value in ResponsePlaceType.values)
                              V5SelectOption(value: value, label: value.label),
                          ],
                          onChanged: _submitting
                              ? null
                              : (value) => setState(() => _type = value!),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 13),
                  _LocationFormSection(
                    icon: Icons.location_on_outlined,
                    title: 'Adresse',
                    child: Column(
                      children: [
                        _field(_addressLine1, 'Adresse'),
                        _field(_addressLine2, 'Complément d’adresse'),
                        _AdaptiveFieldPair(
                          first: _field(_postalCode, 'Code postal'),
                          second: _field(_city, 'Commune'),
                        ),
                        _field(
                          _country,
                          'Pays',
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Saisissez le pays.'
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 13),
                  _LocationFormSection(
                    icon: Icons.contact_phone_outlined,
                    title: 'Contact facultatif',
                    child: Column(
                      children: [
                        _field(_contactName, 'Référent'),
                        _field(
                          _contactPhone,
                          'Téléphone',
                          keyboardType: TextInputType.phone,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 13),
                  _LocationFormSection(
                    icon: Icons.explore_outlined,
                    title: 'Coordonnées facultatives',
                    child: _AdaptiveFieldPair(
                      first: _field(
                        _latitude,
                        'Latitude',
                        keyboardType: const TextInputType.numberWithOptions(
                          signed: true,
                          decimal: true,
                        ),
                        validator: (value) =>
                            _validateCoordinate(value, min: -90, max: 90),
                      ),
                      second: _field(
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
                  ),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: Material(
        color: _LocationFormVisuals.surface,
        elevation: 6,
        shadowColor: const Color(0x24173052),
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SafeArea(
            top: false,
            minimum: AppFormLayout.actionBarPadding,
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    key: const Key('admin-location-submit'),
                    onPressed: _submitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: _LocationFormVisuals.orange,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _LocationFormVisuals.orangeSoft,
                      disabledForegroundColor: _LocationFormVisuals.orange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(_editing ? 'Enregistrer' : 'Créer le lieu'),
                  ),
                ),
              ),
            ),
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
    padding: const EdgeInsets.only(bottom: AppFormLayout.fieldSpacing),
    child: V5TextField(
      label: label,
      controller: controller,
      enabled: !_submitting,
      keyboardType: keyboardType,
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
    V5Toast.show(context, message: message, tone: V5ToastTone.danger);
  }

  static String _coordinate(double? value) => value?.toString() ?? '';
}

class _LocationFormSection extends StatelessWidget {
  const _LocationFormSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return V5Section(title: title, leading: Icon(icon), child: child);
  }
}

class _LocationFormStatus extends StatelessWidget {
  const _LocationFormStatus({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _LocationFormVisuals.fieldBackground,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _LocationFormVisuals.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            active ? 'Statut : Actif' : 'Statut : Désactivé',
            style: const TextStyle(
              color: _LocationFormVisuals.navy,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Le statut se modifie depuis la liste des lieux.',
            style: TextStyle(
              color: _LocationFormVisuals.textMuted,
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdaptiveFieldPair extends StatelessWidget {
  const _AdaptiveFieldPair({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 340) {
          return Column(children: [first, second]);
        }
        return Row(
          children: [
            Expanded(child: first),
            const SizedBox(width: 12),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}
