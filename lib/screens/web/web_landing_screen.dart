import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import 'web_open_url.dart';

class WebLandingScreen extends StatelessWidget {
  const WebLandingScreen({super.key});

  static const _repoUrl = 'https://github.com/grayjin850/motoremap-pro';

  void _openRepo() => openUrl(_repoUrl);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.settings_input_component,
                  size: 72,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'MotoRemap Pro',
                  style: GoogleFonts.rajdhani(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Professional ECU Remapping Platform',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                _PlatformBadge(),
                const SizedBox(height: 32),
                const _FeatureRow(
                  icon: Icons.usb,
                  label: 'USB K-Line / KWP2000',
                  detail: 'Direct ECU read + flash via OpenPort 2.0',
                ),
                const SizedBox(height: 12),
                const _FeatureRow(
                  icon: Icons.bluetooth,
                  label: 'Bluetooth OBD Diagnostics',
                  detail: 'Live AFR, RPM, knock, fuel trims',
                ),
                const SizedBox(height: 12),
                const _FeatureRow(
                  icon: Icons.electric_moped,
                  label: 'Honda Click 125i · Yamaha Aerox 155',
                  detail: 'Keihin PGM-FI + Shindengen RH850 support',
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _openRepo,
                    icon: const Icon(Icons.android, size: 20),
                    label: Text(
                      'Get the Android APK',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _openRepo,
                  child: Text(
                    'View on GitHub →',
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'This app uses USB serial and Bluetooth Classic APIs\nthat are only available on Android.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary.withValues(alpha: 0.6),
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlatformBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.android, size: 18, color: AppColors.warning),
          const SizedBox(width: 8),
          Text(
            'Android Required',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.label,
    required this.detail,
  });

  final IconData icon;
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                detail,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
