import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/safety/safety_validator.dart';

/// Circular safety score ring with level label and optional subtitle.
/// Used on PreRemapScreen, PostRemapScreen, and TuneProfilesScreen.
class SafetyScoreWidget extends StatelessWidget {
  final int score;
  final SafetyLevel level;
  final String? overrideLabel;
  final String? subtitle;
  final double ringSize;
  final double strokeWidth;

  const SafetyScoreWidget({
    super.key,
    required this.score,
    required this.level,
    this.overrideLabel,
    this.subtitle,
    this.ringSize = 64,
    this.strokeWidth = 6,
  });

  Color get _levelColor => switch (level) {
        SafetyLevel.approved => AppColors.safe,
        SafetyLevel.warning => AppColors.warning,
        SafetyLevel.hardLock => AppColors.danger,
      };

  String get _levelLabel => overrideLabel ?? switch (level) {
        SafetyLevel.approved => 'LIGTAS',
        SafetyLevel.warning => 'BABALA',
        SafetyLevel.hardLock => 'BLOCKED',
      };

  @override
  Widget build(BuildContext context) {
    final color = _levelColor;
    return Row(children: [
      SizedBox(
        width: ringSize,
        height: ringSize,
        child: Stack(alignment: Alignment.center, children: [
          CircularProgressIndicator(
            value: score / 100,
            backgroundColor: AppColors.cardBorder,
            color: color,
            strokeWidth: strokeWidth,
          ),
          Text(
            '$score',
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: ringSize * 0.25),
          ),
        ]),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            _levelLabel,
            style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w700),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                subtitle!,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12),
              ),
            ),
        ]),
      ),
    ]);
  }
}

/// Compact score ring used in grid/card contexts (no label row).
class SafetyScoreRing extends StatelessWidget {
  final int score;
  final SafetyLevel level;
  final double size;
  final double strokeWidth;

  const SafetyScoreRing({
    super.key,
    required this.score,
    required this.level,
    this.size = 56,
    this.strokeWidth = 5,
  });

  Color get _color => switch (level) {
        SafetyLevel.approved => AppColors.safe,
        SafetyLevel.warning => AppColors.warning,
        SafetyLevel.hardLock => AppColors.danger,
      };

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        CircularProgressIndicator(
          value: score / 100,
          backgroundColor: AppColors.cardBorder,
          color: color,
          strokeWidth: strokeWidth,
        ),
        Text(
          '$score',
          style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: size * 0.24),
        ),
      ]),
    );
  }
}
