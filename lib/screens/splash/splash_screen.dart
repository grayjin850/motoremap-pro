import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/database/db_helper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _scheduleGate();
  }

  void _scheduleGate() {
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      _showSafetyGate();
    });
  }

  void _showSafetyGate() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _SafetyGateDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: _SplashContent(),
      ),
    );
  }
}

class _SplashContent extends StatelessWidget {
  const _SplashContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.settings_input_component,
          size: 80,
          color: AppColors.primary,
        ),
        const SizedBox(height: 24),
        Text(
          AppStrings.appName,
          style: GoogleFonts.rajdhani(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          AppStrings.tagline,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _SafetyGateDialog extends StatefulWidget {
  const _SafetyGateDialog();

  @override
  State<_SafetyGateDialog> createState() => _SafetyGateDialogState();
}

class _SafetyGateDialogState extends State<_SafetyGateDialog> {
  final TextEditingController _phraseController = TextEditingController();
  bool _canProceed = false;

  @override
  void initState() {
    super.initState();
    _phraseController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final matches = _phraseController.text == AppStrings.safetyConfirmPhrase;
    if (matches != _canProceed) {
      setState(() {
        _canProceed = matches;
      });
    }
  }

  @override
  void dispose() {
    _phraseController.removeListener(_onTextChanged);
    _phraseController.dispose();
    super.dispose();
  }

  Future<void> _onConfirm() async {
    final id = 'ack_${DateTime.now().millisecondsSinceEpoch}';
    await DbHelper.insertAcknowledgment(
      id: id,
      phraseUsed: AppStrings.safetyConfirmPhrase,
      appVersion: AppStrings.appVersion,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.warning, width: 1),
      ),
      title: Text(
        '⚠️ PROPESYONAL NA GAMIT LAMANG',
        style: GoogleFonts.rajdhani(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.warning,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.safetyGateBody,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _phraseController,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.none,
              style: GoogleFonts.inter(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: AppStrings.safetyConfirmHint,
              ),
            ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: _canProceed ? _onConfirm : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _canProceed ? AppColors.primary : AppColors.cardBorder,
            foregroundColor: AppColors.textPrimary,
          ),
          child: Text(
            AppStrings.safetyProceedButton,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
