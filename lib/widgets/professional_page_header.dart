import 'package:flutter/material.dart';

import '../config/app_identity.dart';
import '../theme/v5_foundation.dart';
import 'brand_mark.dart';
import 'native_interactions.dart';

enum MobSanteJourney { professional, responsible, coordinator, administrator }

extension MobSanteJourneyIdentity on MobSanteJourney {
  String get title => switch (this) {
    MobSanteJourney.professional => 'Professionnel',
    MobSanteJourney.responsible => 'Responsable de site',
    MobSanteJourney.coordinator => 'Coordinateur',
    MobSanteJourney.administrator => 'Administrateur',
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
    this.journeyTitle,
    this.journeyTitleSuffix,
    this.sloganText,
  });

  static const slogan = 'Le bon professionnel, au bon endroit, au bon moment.';
  static const professionalSlogan =
      'Le bon professionnel · au bon endroit · au bon moment';

  final MobSanteJourney journey;
  final String? pageTitle;
  final Key pageTitleKey;
  final String? journeyTitle;
  final String? journeyTitleSuffix;
  final String? sloganText;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final visiblePageTitle = pageTitle?.trim();
    final visibleJourneyTitle = journeyTitle?.trim() ?? journey.title;
    final visibleJourneyTitleSuffix = journeyTitleSuffix?.trim();
    final visibleSlogan = sloganText?.trim() ?? slogan;
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
                '${visibleSlogan.replaceAll('\n', ' ')}',
            child: ExcludeSemantics(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BrandMark(size: 48),
                  const SizedBox(width: V5Spacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppIdentity.productName,
                          key: const Key('mobsante-product-name'),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: colors.textPrimary,
                                fontSize: 26,
                                height: 1.05,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.45,
                              ),
                        ),
                        const SizedBox(height: 1),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final allowScalingToWrap =
                                MediaQuery.textScalerOf(context).scale(1) > 1;
                            final sloganText = Text(
                              visibleSlogan,
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
          const SizedBox(height: V5Spacing.sm),
          Semantics(
            key: Key('mobsante-journey-title-${journey.name}'),
            header: true,
            label: [
              visibleJourneyTitle,
              if (visibleJourneyTitleSuffix?.isNotEmpty == true)
                visibleJourneyTitleSuffix!,
            ].join(' '),
            excludeSemantics: true,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    visibleJourneyTitle,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.35,
                    ),
                  ),
                  if (visibleJourneyTitleSuffix?.isNotEmpty == true) ...[
                    const SizedBox(width: 5),
                    Text(
                      visibleJourneyTitleSuffix!,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.35,
                      ),
                    ),
                  ],
                ],
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
            const SizedBox(height: V5Spacing.sm),
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
  Widget build(BuildContext context) => MobSanteJourneyHeader(
    journey: MobSanteJourney.professional,
    journeyTitleSuffix: 'de santé',
    sloganText: MobSanteJourneyHeader.professionalSlogan,
    pageTitle: title,
    pageTitleKey: const Key('professional-page-title'),
  );
}

/// Compact product identity used on professional secondary tabs.
/// It intentionally omits the journey title and page subtitle.
class ProfessionalIdentityHeader extends StatelessWidget {
  const ProfessionalIdentityHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Semantics(
      key: const Key('mobsante-product-identity'),
      container: true,
      label:
          '${AppIdentity.productName}. '
          '${MobSanteJourneyHeader.professionalSlogan}',
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BrandMark(size: 48),
            const SizedBox(width: V5Spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppIdentity.productName,
                    key: const Key('mobsante-product-name'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: colors.textPrimary,
                      fontSize: 26,
                      height: 1.05,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.45,
                    ),
                  ),
                  const SizedBox(height: 1),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      MobSanteJourneyHeader.professionalSlogan,
                      key: const Key('mobsante-product-slogan'),
                      maxLines: 1,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                        fontSize: 11,
                        height: 1.22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfessionalProfileEditorHeader extends StatelessWidget {
  const ProfessionalProfileEditorHeader({
    super.key,
    this.title = 'Compléter mon profil',
    this.subtitle =
        'Complétez vos informations pour pouvoir vous engager sur une mission.',
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Semantics(
      container: true,
      label: 'Mon profil MobSanté. $title. $subtitle',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const BrandMark(size: 38),
                const SizedBox(width: V5Spacing.sm),
                Expanded(
                  child: Text(
                    title,
                    key: const Key('professional-profile-editor-title'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: V5Spacing.xs),
            Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
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
