import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/protocols/kwp_protocol_logger.dart';

/// Protocol log viewer screen.
///
/// Displays every KWP2000 frame logged in the current session with
/// colour-coded TX/RX rows and inline NRC descriptions.
/// Includes export-to-clipboard and full-text-share actions.
class ProtocolLogScreen extends StatefulWidget {
  final int sessionId;

  const ProtocolLogScreen({super.key, required this.sessionId});

  @override
  State<ProtocolLogScreen> createState() => _ProtocolLogScreenState();
}

class _ProtocolLogScreenState extends State<ProtocolLogScreen> {
  List<KwpFrameEntry> _frames = [];
  bool _loading = true;
  bool _autoScroll = true;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadFrames();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFrames() async {
    final frames =
        await KwpProtocolLogger.instance.framesForSession(widget.sessionId);
    if (mounted) {
      setState(() {
        _frames = frames;
        _loading = false;
      });
      if (_autoScroll && _scrollController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        });
      }
    }
  }

  Future<void> _exportText() async {
    final text = await KwpProtocolLogger.instance
        .exportSessionText(widget.sessionId);
    if (!mounted) return;
    await Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Protocol log copied to clipboard')),
    );
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await _loadFrames();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('KWP Log — Session ${widget.sessionId}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy full log',
            onPressed: _exportText,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
          _AutoScrollToggle(
            value: _autoScroll,
            onChanged: (v) => setState(() => _autoScroll = v),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _frames.isEmpty
              ? Center(
                  child: Text(
                    'No frames logged in session ${widget.sessionId}.',
                    style: theme.textTheme.bodyMedium,
                  ),
                )
              : _buildLog(theme),
    );
  }

  Widget _buildLog(ThemeData theme) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemCount: _frames.length,
      itemBuilder: (context, i) => _buildRow(_frames[i], theme),
    );
  }

  Widget _buildRow(KwpFrameEntry entry, ThemeData theme) {
    final isTx = entry.direction == FrameDirection.tx;
    final isNrc = entry.nrcCode != null;

    final rowColor = isNrc
        ? Colors.red.withValues(alpha: 0.08)
        : isTx
            ? Colors.blue.withValues(alpha: 0.05)
            : Colors.green.withValues(alpha: 0.05);

    final labelColor = isNrc
        ? Colors.red
        : isTx
            ? Colors.blue
            : Colors.green;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 1),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: rowColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time
          SizedBox(
            width: 72,
            child: Text(
              entry.formattedTime,
              style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          // Direction badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: labelColor.withValues(alpha: 0.15),
              border: Border.all(color: labelColor),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              entry.directionLabel,
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: labelColor),
            ),
          ),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isNrc ? Colors.red : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.dataHex,
                  style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AutoScrollToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _AutoScrollToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.vertical_align_bottom, size: 16),
          const SizedBox(width: 2),
          Switch(
            value: value,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}
