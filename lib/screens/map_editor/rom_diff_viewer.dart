import 'package:flutter/material.dart';
import '../../core/binary/rom_diff.dart';
import '../../core/ecu/ecu_definition.dart';

/// ROM diff viewer shown before a flash is confirmed.
///
/// Displays every changed byte grouped by map name.
/// The "Approve Changes" button returns `true` to the caller,
/// enabling the flash workflow.
class RomDiffViewer extends StatefulWidget {
  final DiffResult diffResult;
  final EcuDefinition ecu;

  const RomDiffViewer({
    super.key,
    required this.diffResult,
    required this.ecu,
  });

  @override
  State<RomDiffViewer> createState() => _RomDiffViewerState();
}

class _RomDiffViewerState extends State<RomDiffViewer> {
  bool _approved = false;

  @override
  Widget build(BuildContext context) {
    final diff = widget.diffResult;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ROM Change Review'),
        backgroundColor: diff.isEmpty
            ? Colors.green
            : diff.totalChanges > 100
                ? Colors.orange.shade700
                : null,
      ),
      body: diff.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 64, color: Colors.green),
                  SizedBox(height: 16),
                  Text('No changes — ROM matches original.'),
                ],
              ),
            )
          : Column(
              children: [
                _buildSummaryBanner(diff),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      ..._buildMapDiffSections(diff),
                      if (diff.unmappedDiffs.isNotEmpty)
                        _buildUnmappedSection(diff.unmappedDiffs),
                    ],
                  ),
                ),
                _buildApproveBar(diff),
              ],
            ),
    );
  }

  Widget _buildSummaryBanner(DiffResult diff) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: diff.totalChanges > 100
          ? Colors.orange.shade100
          : Colors.blue.shade50,
      child: Row(
        children: [
          Icon(
            diff.totalChanges > 100 ? Icons.warning_amber : Icons.info_outline,
            color: diff.totalChanges > 100 ? Colors.orange : Colors.blue,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${diff.totalChanges} byte${diff.totalChanges == 1 ? "" : "s"} changed',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${diff.mapDiffs.length} map${diff.mapDiffs.length == 1 ? "" : "s"} affected'
                  '${diff.unmappedDiffs.isNotEmpty ? " · ${diff.unmappedDiffs.length} unmapped" : ""}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMapDiffSections(DiffResult diff) {
    return diff.mapDiffs.map((mapDiff) {
      // Look up the MapDescriptor to get scale and unit
      final desc = widget.ecu.mapByName(mapDiff.mapName);

      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ExpansionTile(
          initiallyExpanded: true,
          leading: const Icon(Icons.map_outlined),
          title: Text(
            mapDiff.mapName.replaceAll('_', ' ').toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            '${mapDiff.changeCount} cell${mapDiff.changeCount == 1 ? "" : "s"} changed',
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                children: mapDiff.diffs.map((d) {
                  final fromPhys = desc?.rawToPhysical(d.originalByte);
                  final toPhys = desc?.rawToPhysical(d.newByte);
                  final unit = desc?.unit ?? 'raw';

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        // Offset
                        SizedBox(
                          width: 72,
                          child: Text(
                            '0x${d.offset.toRadixString(16).padLeft(4, "0").toUpperCase()}',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        // Before
                        _ByteChip(
                          value: d.originalByte,
                          physical: fromPhys,
                          unit: unit,
                          isOriginal: true,
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.arrow_forward, size: 14),
                        ),
                        // After
                        _ByteChip(
                          value: d.newByte,
                          physical: toPhys,
                          unit: unit,
                          isOriginal: false,
                        ),
                        // Delta
                        if (fromPhys != null && toPhys != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              _formatDelta(toPhys - fromPhys, unit),
                              style: TextStyle(
                                fontSize: 11,
                                color: (toPhys - fromPhys) > 0
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildUnmappedSection(List<RomDiff> diffs) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: const Icon(Icons.help_outline, color: Colors.orange),
        title: const Text('Unmapped Changes'),
        subtitle: Text(
          '${diffs.length} byte${diffs.length == 1 ? "" : "s"} outside known maps '
          '(may include checksum)',
        ),
        children: diffs.map((d) {
          return ListTile(
            dense: true,
            title: Text(
              '0x${d.offset.toRadixString(16).padLeft(4, "0").toUpperCase()}: '
              '0x${d.originalByte.toRadixString(16).padLeft(2, "0").toUpperCase()} → '
              '0x${d.newByte.toRadixString(16).padLeft(2, "0").toUpperCase()}',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildApproveBar(DiffResult diff) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_approved)
              CheckboxListTile(
                value: false,
                onChanged: (v) {
                  if (v == true) setState(() => _approved = true);
                },
                title: const Text(
                  'I have reviewed all changes and understand the risk.',
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Go Back'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _approved
                        ? () => Navigator.pop(context, true)
                        : null,
                    icon: const Icon(Icons.flash_on),
                    label: const Text('Approve — Enable Flash'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDelta(double delta, String unit) {
    final sign = delta > 0 ? '+' : '';
    return '$sign${delta.toStringAsFixed(1)} $unit';
  }
}

class _ByteChip extends StatelessWidget {
  final int value;
  final double? physical;
  final String unit;
  final bool isOriginal;

  const _ByteChip({
    required this.value,
    this.physical,
    required this.unit,
    required this.isOriginal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isOriginal ? Colors.grey.shade200 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isOriginal ? Colors.grey.shade400 : Colors.blue.shade300,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '0x${value.toRadixString(16).padLeft(2, "0").toUpperCase()}',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
          ),
          if (physical != null)
            Text(
              '${physical!.toStringAsFixed(1)} $unit',
              style: const TextStyle(fontSize: 10, color: Colors.black54),
            ),
        ],
      ),
    );
  }
}
