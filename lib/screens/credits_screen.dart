import 'package:flutter/material.dart';

import '../config/app_identity.dart';
import '../widgets/common.dart';
import '../widgets/v5_secondary_navigation.dart';

abstract final class _CreditsVisuals {
  static const background = Color(0xFFF6F7F8);
  static const surface = Colors.white;
  static const navy = Color(0xFF173052);
  static const fieldBackground = Color(0xFFF1F1EF);
  static const border = Color(0xFFE5E5E1);
  static const textMuted = Color(0xFF5F6865);
}

class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _CreditsVisuals.background,
      appBar: const V5SecondaryNavigationBar(title: 'Crédits'),
      body: SafeArea(
        top: false,
        child: PageContainer(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding = constraints.maxWidth <= 556
                  ? 18.0
                  : (constraints.maxWidth - 520) / 2;
              return Material(
                color: _CreditsVisuals.background,
                child: ListView(
                  key: const Key('credits-screen'),
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    12,
                    horizontalPadding,
                    36,
                  ),
                  children: const [
                    _CreditsHeader(),
                    SizedBox(height: 22),
                    _DesignerCard(),
                    SizedBox(height: 13),
                    _ThanksCard(),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CreditsHeader extends StatelessWidget {
  const _CreditsHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppIdentity.productName.toUpperCase(),
          style: const TextStyle(
            color: _CreditsVisuals.textMuted,
            fontSize: 12,
            letterSpacing: 1.25,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Crédits',
          style: TextStyle(
            color: _CreditsVisuals.navy,
            fontSize: 27,
            height: 1.12,
            letterSpacing: -0.7,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          AppIdentity.productSubtitle,
          style: TextStyle(
            color: _CreditsVisuals.textMuted,
            fontSize: 14,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _DesignerCard extends StatelessWidget {
  const _DesignerCard();

  @override
  Widget build(BuildContext context) {
    return const _CreditsCard(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            _CreditsIcon(icon: Icons.person_outline_rounded, size: 64),
            SizedBox(height: 17),
            Text(
              'Application conçue par Marc Bouyssou.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _CreditsVisuals.navy,
                fontSize: 17,
                height: 1.25,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 9),
            Text(
              'Vice-président de l’URPS '
              'Masseurs-Kinésithérapeutes Nouvelle-Aquitaine.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _CreditsVisuals.textMuted,
                fontSize: 13,
                height: 1.55,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThanksCard extends StatelessWidget {
  const _ThanksCard();

  @override
  Widget build(BuildContext context) {
    return const _CreditsCard(
      child: Padding(
        padding: EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _CreditsIcon(icon: Icons.favorite_outline_rounded, size: 40),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Remerciements',
                    style: TextStyle(
                      color: _CreditsVisuals.navy,
                      fontSize: 16,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Divider(height: 1, color: _CreditsVisuals.border),
            ),
            Text(
              'Remerciements aux professionnels de santé, '
              'coordinateurs et partenaires ayant participé aux '
              'tests terrain.',
              style: TextStyle(
                color: _CreditsVisuals.textMuted,
                fontSize: 14,
                height: 1.55,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreditsIcon extends StatelessWidget {
  const _CreditsIcon({required this.icon, required this.size});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _CreditsVisuals.fieldBackground,
        borderRadius: BorderRadius.circular(size == 40 ? 12 : 20),
      ),
      child: Icon(
        icon,
        color: _CreditsVisuals.navy,
        size: size == 40 ? 20 : 30,
      ),
    );
  }
}

class _CreditsCard extends StatelessWidget {
  const _CreditsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _CreditsVisuals.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _CreditsVisuals.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08173052),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}
