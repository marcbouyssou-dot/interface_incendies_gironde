import 'package:flutter/material.dart';

import '../config/app_identity.dart';
import '../theme/v5_foundation.dart';
import 'brand_mark.dart';
import 'native_interactions.dart';

enum MobSanteJourney { professional, responsible, coordinator, administrator }

extension MobSanteJourneyIdentity on MobSanteJourney {
  String get title => switch (this) {
    MobSanteJourney.professional => 'Professionnel de santé',
    MobSanteJourney.responsible => 'Responsable d’établissement',
    MobSanteJourney.coordinator => 'Coordinateur départemental',
    MobSanteJourney.administrator => 'Administrateur plateforme',
  };

  String get subtitle => switch (this) {
    MobSanteJourney.professional =>
      'Trouvez rapidement où vous pouvez être utile.',
    MobSanteJourney.responsible =>
      'Organisez la couverture de votre établissement.',
    MobSanteJourney.coordinator => 'Supervisez la couverture du territoire.',
    MobSanteJourney.administrator => 'Préparez et pilotez les mobilisations.',
  };
}

class MobSanteJourneyHeader extends StatelessWidget {
  const MobSanteJourneyHeader({
    super.key,
    required this.journey,
    this.pageTitle,
    this.pageTitleKey = const Key('role-page-title'),
  });

  static const slogan = 'Le bon professionnel, au bon endroit, au bon moment.';

  final MobSanteJourney journey;
  final String? pageTitle;
  final Key pageTitleKey;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final visiblePageTitle = pageTitle?.trim();
    return Semantics(
      container: true,
      child: Column(
        key: const Key('mobsante-journey-header'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            key: const Key('mobsante-product-identity'),
            label:
                '${AppIdentity.productName}. '
                '${slogan.replaceAll('\n', ' ')}',
            child: ExcludeSemantics(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BrandMark(size: 36),
                  const SizedBox(width: V5Spacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppIdentity.productName,
                          key: const Key('mobsante-product-name'),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                        ),
                        const SizedBox(height: 1),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final allowScalingToWrap =
                                MediaQuery.textScalerOf(context).scale(1) > 1;
                            final sloganText = Text(
                              slogan,
                              key: const Key('mobsante-product-slogan'),
                              maxLines: allowScalingToWrap ? null : 1,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: colors.textSecondary,
                                    fontSize: constraints.maxWidth < 320
                                        ? 10.5
                                        : 11,
                                    height: 1.22,
                                  ),
                            );
                            if (allowScalingToWrap) return sloganText;
                            return FittedBox(
                              key: const Key('mobsante-slogan-one-line'),
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: sloganText,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: V5Spacing.md),
          Semantics(
            header: true,
            child: Text(
              journey.title,
              key: Key('mobsante-journey-title-${journey.name}'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.35,
              ),
            ),
          ),
          const SizedBox(height: V5Spacing.xxs),
          Text(
            journey.subtitle,
            key: Key('mobsante-journey-subtitle-${journey.name}'),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
          if (visiblePageTitle?.isNotEmpty == true) ...[
            const SizedBox(height: V5Spacing.md),
            _AnimatedHeaderTitle(
              title: visiblePageTitle!,
              titleKey: pageTitleKey,
            ),
          ],
        ],
      ),
    );
  }
}

class MobSantePageHeader extends StatelessWidget {
  const MobSantePageHeader({
    super.key,
    required this.title,
    this.titleKey = const Key('role-page-title'),
  });

  final String title;
  final Key titleKey;

  @override
  Widget build(BuildContext context) =>
      _AnimatedHeaderTitle(title: title, titleKey: titleKey);
}

class ProfessionalPageHeader extends StatelessWidget {
  const ProfessionalPageHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => MobSantePageHeader(
    title: title,
    titleKey: const Key('professional-page-title'),
  );
}

class _AnimatedHeaderTitle extends StatelessWidget {
  const _AnimatedHeaderTitle({required this.title, required this.titleKey});

  final String title;
  final Key titleKey;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : NativeMotion.stateTransition;
    return Semantics(
      header: true,
      child: AnimatedSize(
        key: titleKey,
        duration: duration,
        curve: Curves.easeOutCubic,
        alignment: Alignment.topLeft,
        child: AnimatedSwitcher(
          duration: duration,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (currentChild, previousChildren) => Stack(
            alignment: Alignment.topLeft,
            children: [...previousChildren, ?currentChild],
          ),
          child: Text(
            title,
            key: ValueKey(title),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
      ),
    );
  }
}
