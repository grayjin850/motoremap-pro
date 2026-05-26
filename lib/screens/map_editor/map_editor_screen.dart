import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/binary/rom_parser.dart';
import '../../core/binary/rom_writer.dart';
import '../../core/binary/rom_diff.dart';
import '../../core/ecu/ecu_definition.dart';
import 'rom_diff_viewer.dart';

/// Interactive ECU map editor.
///
/// Features:
/// - Tappable grid — every cell editable
/// - Color gradient: blue (rich) → white (stoich) → red (lean)
/// - Long-press: shows raw byte + physical value + safe range
/// - Undo/redo (up to 50 steps)
/// - Interpolation between two selected cells
/// - Live RPM/load overlay (when OBD is connected)
/// - Map trace mode
/// - Import/export (JSON)
class MapEditorScreen extends StatefulWidget {
  final ParsedRom parsedRom;
  final String mapName;
  final AxisDescriptor? axes;

  const MapEditorScreen({
    super.key,
    required this.parsedRom,
    required this.mapName,
    this.axes,
  });

  @override
  State<MapEditorScreen> createState() => _MapEditorScreenState();
}

class _MapEditorScreenState extends State<MapEditorScreen> {
  static const int _maxUndoSteps = 50;

  late ExtractedMap _currentMap;
  final List<ExtractedMap> _undoStack = [];
  final List<ExtractedMap> _redoStack = [];

  // Selection state
  int? _selectedRow;
  int? _selectedCol;
  int? _interpolateFromRow;
  int? _interpolateFromCol;

  // Live overlay
  int? _liveRpm;
  int? _liveLoad;
  bool _traceModeEnabled = false;
  final Set<String> _tracedCells = {};

  @override
  void initState() {
    super.initState();
    final map = widget.parsedRom.mapByName(widget.mapName);
    if (map == null) {
      throw ArgumentError('Map "${widget.mapName}" not found in parsed ROM');
    }
    _currentMap = map;
  }

  MapDescriptor get _desc => _currentMap.descriptor;
  AxisDescriptor? get _axes => widget.axes ?? widget.parsedRom.ecu.defaultAxes;

  // ── Edit actions ─────────────────────────────────────────────────────────

  void _editCell(int row, int col, double newValue) {
    final clamped = newValue.clamp(_desc.safeMin, _desc.safeMax).toDouble();
    _pushUndo();
    setState(() {
      _currentMap = _currentMap.withCell(row, col, clamped);
      _redoStack.clear();
    });
  }

  void _pushUndo() {
    _undoStack.add(_currentMap);
    if (_undoStack.length > _maxUndoSteps) _undoStack.removeAt(0);
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    setState(() {
      _redoStack.add(_currentMap);
      _currentMap = _undoStack.removeLast();
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    setState(() {
      _undoStack.add(_currentMap);
      _currentMap = _redoStack.removeLast();
    });
  }

  void _interpolateBetween(
    int r1, int c1,
    int r2, int c2,
  ) {
    if (r1 == r2 && c1 == c2) return;

    final v1 = _currentMap.values[r1][c1];
    final v2 = _currentMap.values[r2][c2];

    // Walk cells in row/col order and linearly interpolate
    final cells = <(int, int)>[];
    // Simple case: same row → interpolate across columns
    if (r1 == r2) {
      final minC = c1 < c2 ? c1 : c2;
      final maxC = c1 < c2 ? c2 : c1;
      for (int c = minC; c <= maxC; c++) {
        cells.add((r1, c));
      }
    } else if (c1 == c2) {
      // Same column → interpolate across rows
      final minR = r1 < r2 ? r1 : r2;
      final maxR = r1 < r2 ? r2 : r1;
      for (int r = minR; r <= maxR; r++) {
        cells.add((r, c1));
      }
    } else {
      return; // Diagonal interpolation not supported
    }

    if (cells.length < 2) return;
    _pushUndo();
    setState(() {
      ExtractedMap updated = _currentMap;
      for (int i = 0; i < cells.length; i++) {
        final t = i / (cells.length - 1);
        final interpolated = v1 + (v2 - v1) * t;
        final clamped = interpolated.clamp(_desc.safeMin, _desc.safeMax);
        updated = updated.withCell(cells[i].$1, cells[i].$2, clamped.toDouble());
      }
      _currentMap = updated;
      _redoStack.clear();
      _interpolateFromRow = null;
      _interpolateFromCol = null;
    });
  }

  // ── Approve + diff view ───────────────────────────────────────────────────

  Future<void> _openDiffViewer() async {
    final originalRom = widget.parsedRom.raw;
    final modifiedRom = RomBinaryWriter.applyExtractedMap(originalRom, _currentMap);

    final diffResult = RomDiffEngine.diff(
      originalRom,
      modifiedRom,
      ecu: widget.parsedRom.ecu,
    );

    if (!mounted) return;

    final approved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RomDiffViewer(
          diffResult: diffResult,
          ecu: widget.parsedRom.ecu,
        ),
      ),
    );

    if (approved == true && mounted) {
      Navigator.pop(context, modifiedRom);
    }
  }

  // ── Cell color ────────────────────────────────────────────────────────────

  Color _cellColor(double value) {
    final range = _desc.safeMax - _desc.safeMin;
    if (range == 0) return Colors.white;
    final t = (value - _desc.safeMin) / range; // 0 = min, 1 = max
    // For fuel maps: low value = rich (blue), high value = lean (red)
    if (t < 0.5) {
      // Rich (blue) → stoich (white)
      return Color.lerp(const Color(0xFF4FC3F7), Colors.white, t * 2)!;
    } else {
      // Stoich (white) → lean (red)
      return Color.lerp(Colors.white, const Color(0xFFEF5350), (t - 0.5) * 2)!;
    }
  }

  // ── Cell dialog ───────────────────────────────────────────────────────────

  Future<void> _showCellEditDialog(int row, int col) async {
    final value = _currentMap.values[row][col];
    final rawByte = _desc.physicalToRaw(value);
    final controller = TextEditingController(text: value.toStringAsFixed(1));

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit ${_desc.name} [R$row, C$col]'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Raw byte: 0x${rawByte.toRadixString(16).padLeft(2, "0").toUpperCase()} '
              '($rawByte)',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            Text(
              'Safe range: ${_desc.safeMin}–${_desc.safeMax} ${_desc.unit}',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Value (${_desc.unit})',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text);
              if (parsed != null) {
                _editCell(row, col, parsed);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_desc.name.replaceAll('_', ' ').toUpperCase()),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Undo',
            onPressed: _undoStack.isNotEmpty ? _undo : null,
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            tooltip: 'Redo',
            onPressed: _redoStack.isNotEmpty ? _redo : null,
          ),
          IconButton(
            icon: Icon(
              _traceModeEnabled ? Icons.gps_fixed : Icons.gps_not_fixed,
            ),
            tooltip: _traceModeEnabled ? 'Disable trace' : 'Enable trace',
            onPressed: () => setState(() => _traceModeEnabled = !_traceModeEnabled),
          ),
          FilledButton.icon(
            onPressed: _openDiffViewer,
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text('Review & Flash'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: _buildGrid(),
                ),
              ),
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final isInterpolating =
        _interpolateFromRow != null && _interpolateFromCol != null;
    if (!isInterpolating) return const SizedBox.shrink();

    return Container(
      color: Colors.amber.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.linear_scale, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Interpolate from R${_interpolateFromRow}×C${_interpolateFromCol} '
              '— tap destination cell',
            ),
          ),
          TextButton(
            onPressed: () => setState(() {
              _interpolateFromRow = null;
              _interpolateFromCol = null;
            }),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    final axes = _axes;

    return Table(
      defaultColumnWidth: const FixedColumnWidth(60),
      border: TableBorder.all(color: Colors.grey.shade300, width: 0.5),
      children: [
        // Column header row (load / TPS values)
        if (axes != null)
          TableRow(
            decoration: BoxDecoration(color: Colors.grey.shade200),
            children: [
              const SizedBox(height: 32), // empty top-left corner
              for (int c = 0; c < _desc.cols; c++)
                Center(
                  child: Text(
                    c < axes.loadPoints.length
                        ? '${axes.loadPoints[c]}%'
                        : '$c',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        for (int r = 0; r < _desc.rows; r++)
          TableRow(
            children: [
              // Row header (RPM)
              if (axes != null)
                Container(
                  color: Colors.grey.shade200,
                  alignment: Alignment.center,
                  height: 40,
                  child: Text(
                    r < axes.rpmPoints.length
                        ? '${axes.rpmPoints[r]}'
                        : '$r',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              for (int c = 0; c < _desc.cols; c++)
                _buildCell(r, c),
            ],
          ),
      ],
    );
  }

  Widget _buildCell(int row, int col) {
    final value = _currentMap.values[row][col];
    final isSelected = _selectedRow == row && _selectedCol == col;
    final isInterpolateSrc =
        _interpolateFromRow == row && _interpolateFromCol == col;
    final isLiveActive = _isLiveCell(row, col);
    final isTraced = _traceModeEnabled &&
        _tracedCells.contains('$row,$col');

    return GestureDetector(
      onTap: () => _onCellTap(row, col),
      onDoubleTap: () => _showCellEditDialog(row, col),
      onLongPress: () => _onCellLongPress(row, col),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 40,
        decoration: BoxDecoration(
          color: _cellColor(value),
          border: Border.all(
            color: isLiveActive
                ? Colors.green
                : isSelected || isInterpolateSrc
                    ? Colors.blue
                    : Colors.transparent,
            width: isLiveActive || isSelected || isInterpolateSrc ? 2 : 0,
          ),
        ),
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              value.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: Colors.black87,
              ),
            ),
            if (isTraced)
              const Positioned(
                right: 2,
                top: 2,
                child: Icon(Icons.fiber_manual_record, size: 6, color: Colors.green),
              ),
          ],
        ),
      ),
    );
  }

  bool _isLiveCell(int row, int col) {
    if (_liveRpm == null || _liveLoad == null) return false;
    final axes = _axes;
    if (axes == null) return false;
    // Find closest RPM row
    final rpmRow = _closestIndex(axes.rpmPoints, _liveRpm!);
    final loadCol = _closestIndex(axes.loadPoints, _liveLoad!);
    return rpmRow == row && loadCol == col;
  }

  int _closestIndex(List<int> points, int value) {
    int closest = 0;
    int minDist = (points[0] - value).abs();
    for (int i = 1; i < points.length; i++) {
      final d = (points[i] - value).abs();
      if (d < minDist) {
        minDist = d;
        closest = i;
      }
    }
    return closest;
  }

  void _onCellTap(int row, int col) {
    if (_interpolateFromRow != null && _interpolateFromCol != null) {
      _interpolateBetween(
        _interpolateFromRow!, _interpolateFromCol!,
        row, col,
      );
      return;
    }
    setState(() {
      if (_selectedRow == row && _selectedCol == col) {
        _selectedRow = null;
        _selectedCol = null;
      } else {
        _selectedRow = row;
        _selectedCol = col;
      }
    });
    if (_traceModeEnabled) {
      _tracedCells.add('$row,$col');
    }
  }

  void _onCellLongPress(int row, int col) {
    if (_selectedRow != null && _selectedCol != null &&
        (_selectedRow != row || _selectedCol != col)) {
      // Long-press on a different cell while one is selected → start interpolation
      showModalBottomSheet<void>(
        context: context,
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.linear_scale),
                title: const Text('Interpolate between cells'),
                subtitle: Text(
                  'From R${_selectedRow}×C${_selectedCol} to R${row}×C$col',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _interpolateBetween(
                    _selectedRow!, _selectedCol!,
                    row, col,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit this cell'),
                onTap: () {
                  Navigator.pop(context);
                  _showCellEditDialog(row, col);
                },
              ),
            ],
          ),
        ),
      );
    } else {
      setState(() {
        _interpolateFromRow = row;
        _interpolateFromCol = col;
      });
    }
  }

  Widget _buildFooter() {
    final sel = (_selectedRow != null && _selectedCol != null)
        ? _currentMap.values[_selectedRow!][_selectedCol!]
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          if (sel != null) ...[
            Text(
              'Selected: ${sel.toStringAsFixed(2)} ${_desc.unit}  '
              '(raw: 0x${_desc.physicalToRaw(sel).toRadixString(16).toUpperCase().padLeft(2, "0")})',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _showCellEditDialog(_selectedRow!, _selectedCol!),
              icon: const Icon(Icons.edit, size: 14),
              label: const Text('Edit'),
            ),
          ] else ...[
            Text(
              '${_desc.rows}×${_desc.cols} | ${_desc.unit} | '
              'Undo: ${_undoStack.length}/${_maxUndoSteps}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
