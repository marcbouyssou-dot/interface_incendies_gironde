import 'package:flutter/material.dart';

import '../config/app_identity.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_mark.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: Center(
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BrandMark(size: 92, onDarkBackground: true),
              SizedBox(height: 24),
              Text(
                AppIdentity.productName,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.6,
                ),
              ),
              SizedBox(height: 7),
              Text(
                AppIdentity.productSubtitle,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
