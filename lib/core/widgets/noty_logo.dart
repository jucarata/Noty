import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:noty/core/constants/app_assets.dart';
import 'package:noty/core/theme/app_colors.dart';

class NotyLogo extends StatelessWidget {
  const NotyLogo({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          AppAssets.notyIsotype,
          width: size,
          height: size,
        ),
        const SizedBox(height: 12),
        Text(
          'Noty',
          style: GoogleFonts.poppins(
            fontSize: 40,
            fontWeight: FontWeight.w700,
            color: AppColors.azulNoty,
          ),
        ),
      ],
    );
  }
}
