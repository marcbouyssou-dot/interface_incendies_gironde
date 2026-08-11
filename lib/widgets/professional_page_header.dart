import 'package:flutter/material.dart';

import 'native_interactions.dart';

class MobSantePageHeader extends StatelessWidget {
  const MobSantePageHeader({
    super.key,
    required this.title,
    this.titleKey = const Key('role-page-title'),
  });

  final String title;
  final Key titleKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSize(
          key: titleKey,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : NativeMotion.stateTransition,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topLeft,
          child: AnimatedSwitcher(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : NativeMotion.stateTransition,
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
      ],
    );
  }
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
