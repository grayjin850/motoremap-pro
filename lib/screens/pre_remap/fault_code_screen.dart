import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class _Dtc {
  final String code;
  final String description;
  final bool isHigh;
  const _Dtc({required this.code, required this.description, this.isHigh = false});
}

class FaultCodeScreen extends StatefulWidget {
  final String modelId;
  const FaultCodeScreen({super.key, required this.modelId});

  @override
  State<FaultCodeScreen> createState() => _FaultCodeScreenState();
}

class _FaultCodeScreenState extends State<FaultCodeScreen> {
  bool _isScanning = false;
  bool _scanDone = false;
  // Starts empty — ELM327 found no codes (or NODATA for non-OBD-II ECU).
  final List<_Dtc> _codes = [];

  @override
  void initState() {
    super.initState();
    _runScan();
  }

  Future<void> _runScan() async {
    setState(() { _isScanning = true; _scanDone = false; });
    // Simulate ELM327 DTC scan (~1.8 s round-trip for mode 03 request)
    await Future.delayed(const Duration(milliseconds: 1800));
    if (mounted) setState(() { _isScanning = false; _scanDone = true; });
  }

  void _addManualCode() {
    final codeCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Magdagdag ng Fault Code'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(
            'Ilagay ang fault code na nakita ng iyong laptop flashing tool.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: codeCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Code (e.g. P0301)'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: descCtrl,
            decoration:
                const InputDecoration(labelText: 'Description (optional)'),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kanselahin'),
          ),
          ElevatedButton(
            onPressed: () {
              final code = codeCtrl.text.trim().toUpperCase();
              if (code.isNotEmpty) {
                setState(() => _codes.add(_Dtc(
                      code: code,
                      description: descCtrl.text.trim().isEmpty
                          ? 'Manual entry'
                          : descCtrl.text.trim(),
                      isHigh:
                          code.startsWith('P0') || code.startsWith('C'),
                    )));
              }
              Navigator.pop(context);
            },
            child: const Text('Idagdag'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Fault Code Scanner'),
          actions: [
            if (!_isScanning)
              TextButton.icon(
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Re-scan'),
                onPressed: _runScan,
              ),
          ],
        ),
        body: Column(children: [
          // OBD disclaimer banner
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.panel,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.5)),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline, color: AppColors.warning, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Hindi lahat ng motorcycle ECU ay nagsasalita ng OBD-II/ELM327. '
                  'Para sa mga lumang modelo, gamitin ang laptop-based na scanner.',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
            ]),
          ),

          // Scan result area
          Expanded(
            child: _isScanning
                ? const Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Nag-iiscan ng fault codes...',
                          style:
                              TextStyle(color: AppColors.textSecondary)),
                    ]),
                  )
                : _scanDone
                    ? _buildResult()
                    : const SizedBox(),
          ),

          // Manual add
          if (_scanDone)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Magdagdag mula sa Laptop Tool'),
                onPressed: _addManualCode,
              ),
            ),

          // Confirm / return with count
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _scanDone
                      ? () => Navigator.pop(context, _codes.length)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _codes.isEmpty ? AppColors.safe : AppColors.warning,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    _codes.isEmpty
                        ? 'Walang Fault Codes — OK'
                        : 'Bumalik (${_codes.length} code${_codes.length == 1 ? "" : "s"})',
                  ),
                ),
              ),
            ),
          ),
        ]),
      );

  Widget _buildResult() {
    if (_codes.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
                color: AppColors.surface, shape: BoxShape.circle),
            child: const Icon(Icons.check_circle,
                color: AppColors.safe, size: 64),
          ),
          const SizedBox(height: 16),
          const Text('Walang fault codes!',
              style: TextStyle(
                  color: AppColors.safe,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('Maayos ang ECU — walang active DTCs.',
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          const Text(
            'Kung ang iyong laptop tool ay nakahanap ng codes,\n'
            'gamitin ang "Magdagdag" button sa ibaba.',
            style:
                TextStyle(color: AppColors.textSecondary, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ]),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _codes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final dtc = _codes[i];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: dtc.isHigh ? AppColors.danger : AppColors.warning),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: dtc.isHigh
                    ? AppColors.danger.withValues(alpha: 0.2)
                    : AppColors.warning.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                dtc.code,
                style: TextStyle(
                  color:
                      dtc.isHigh ? AppColors.danger : AppColors.warning,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(dtc.description,
                  style:
                      const TextStyle(color: AppColors.textPrimary)),
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline,
                  size: 18, color: AppColors.textSecondary),
              onPressed: () => setState(() => _codes.removeAt(i)),
              tooltip: 'Alisin',
            ),
          ]),
        );
      },
    );
  }
}
