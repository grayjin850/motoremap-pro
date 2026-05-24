import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/safety/safety_validator.dart';

/// Show a non-blocking warning dialog. Returns true when the user acknowledges.
Future<bool> showWarningDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Naintindihan, Magpatuloy',
  String cancelLabel = 'Bumalik',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(children: [
        const Icon(Icons.warning_amber, color: AppColors.warning),
        const SizedBox(width: 8),
        Expanded(child: Text(title)),
      ]),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel,
              style: const TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: AppColors.textPrimary),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Show a hard-block error dialog. No confirm action — user must resolve first.
Future<void> showHardBlockDialog(
  BuildContext context, {
  required String title,
  required String message,
  String dismissLabel = 'OK, Aayusin Ko',
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Row(children: [
        const Icon(Icons.block, color: AppColors.danger),
        const SizedBox(width: 8),
        Expanded(child: Text(title)),
      ]),
      content: Text(message,
          style: const TextStyle(color: AppColors.textSecondary)),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: AppColors.textPrimary),
          onPressed: () => Navigator.pop(ctx),
          child: Text(dismissLabel),
        ),
      ],
    ),
  );
}

/// Show safety validation warnings from [SafetyValidationResult].
/// If the result has a hard lock, shows a block dialog.
/// If it has warnings only, shows a warning dialog.
/// Returns true if the user chose to proceed (warning) or false if hard-locked.
Future<bool> showSafetyResultDialog(
  BuildContext context,
  SafetyValidationResult result,
) async {
  if (result.level == SafetyLevel.hardLock) {
    final messages = result.warnings
        .where((w) => w.isBlocking)
        .map((w) => '• ${w.message}')
        .join('\n');
    await showHardBlockDialog(
      context,
      title: 'HARD BLOCK — Hindi Makakatuloy',
      message: messages.isEmpty
          ? 'Ang safety score ay masyadong mababa. Ayusin muna ang mga isyu.'
          : messages,
    );
    return false;
  }

  if (result.level == SafetyLevel.warning) {
    final messages = result.warnings
        .map((w) => '• ${w.message}')
        .join('\n');
    return showWarningDialog(
      context,
      title: 'Safety Warning',
      message: messages.isEmpty
          ? 'May mga babala. Magpatuloy nang maingat.'
          : messages,
    );
  }

  return true;
}
