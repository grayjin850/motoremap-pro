import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../services/bluetooth_service.dart';

/// Compact OBD/Bluetooth connection status banner.
/// Pass [onTap] to allow tapping to open a BT scan dialog.
class OBDStatusWidget extends ConsumerWidget {
  final VoidCallback? onTap;
  final bool showLabel;

  const OBDStatusWidget({super.key, this.onTap, this.showLabel = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(bluetoothStatusProvider).valueOrNull
        ?? BluetoothConnectionStatus.disconnected;
    return _OBDStatusContent(status: status, onTap: onTap, showLabel: showLabel);
  }
}

class _OBDStatusContent extends StatelessWidget {
  final BluetoothConnectionStatus status;
  final VoidCallback? onTap;
  final bool showLabel;

  const _OBDStatusContent({
    required this.status,
    this.onTap,
    required this.showLabel,
  });

  bool get _connected => status == BluetoothConnectionStatus.connected;
  bool get _scanning => status == BluetoothConnectionStatus.scanning ||
      status == BluetoothConnectionStatus.connecting;

  Color get _color => _connected
      ? AppColors.safe
      : _scanning
          ? AppColors.warning
          : AppColors.textSecondary;

  String get _label => switch (status) {
        BluetoothConnectionStatus.connected => 'OBD: Nakakonekta',
        BluetoothConnectionStatus.connecting => 'OBD: Connecting...',
        BluetoothConnectionStatus.scanning => 'OBD: Scanning...',
        BluetoothConnectionStatus.error => 'OBD: Connection Error',
        BluetoothConnectionStatus.disconnected => 'OBD: Disconnected',
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _connected ? AppColors.safe : AppColors.cardBorder,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            _connected
                ? Icons.bluetooth_connected
                : _scanning
                    ? Icons.bluetooth_searching
                    : Icons.bluetooth_disabled,
            color: _color,
            size: 16,
          ),
          if (showLabel) ...[
            const SizedBox(width: 8),
            Text(
              _label,
              style: TextStyle(color: _color, fontSize: 12),
            ),
          ],
          if (onTap != null && !_connected) ...[
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                color: AppColors.textSecondary, size: 14),
          ],
        ]),
      ),
    );
  }
}

/// Inline status dot — just the color dot + text, no border box.
/// Use in tight spaces like AppBar or status strips.
class OBDStatusDot extends ConsumerWidget {
  const OBDStatusDot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(bluetoothStatusProvider).valueOrNull
        ?? BluetoothConnectionStatus.disconnected;
    final connected = status == BluetoothConnectionStatus.connected;
    final color = connected ? AppColors.safe : AppColors.textSecondary;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(
        connected ? 'OBD' : 'No OBD',
        style: TextStyle(color: color, fontSize: 10),
      ),
    ]);
  }
}
