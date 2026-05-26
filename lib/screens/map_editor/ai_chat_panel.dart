import 'package:flutter/material.dart';
import '../../ai/tuning_ai.dart';
import '../../core/binary/rom_parser.dart';
import '../../core/ecu/ecu_definition.dart';

// ── Message model ─────────────────────────────────────────────────────────────

enum _Sender { user, ai, system }

class _ChatMessage {
  final _Sender sender;
  final String text;
  final TuningSuggestion? suggestion;
  final DateTime timestamp;

  _ChatMessage({
    required this.sender,
    required this.text,
    this.suggestion,
  }) : timestamp = DateTime.now();
}

// ── AI Chat Panel ─────────────────────────────────────────────────────────────

/// Slide-up panel embedded in the map editor.
/// Returns a list of [CellChange] via [onApply] when the tuner accepts
/// suggestions. All cell changes have already been filtered by SafetyValidator.
class AiChatPanel extends StatefulWidget {
  final EcuDefinition ecu;
  final ParsedRom rom;
  final String apiKey;
  final void Function(List<CellChange> changes) onApply;
  final VoidCallback onDismiss;

  const AiChatPanel({
    super.key,
    required this.ecu,
    required this.rom,
    required this.apiKey,
    required this.onApply,
    required this.onDismiss,
  });

  @override
  State<AiChatPanel> createState() => _AiChatPanelState();
}

class _AiChatPanelState extends State<AiChatPanel> {
  late final TuningAI _ai;
  final List<_ChatMessage> _messages = [];
  final List<Map<String, String>> _history = [];
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _isThinking = false;

  static const _quickPrompts = [
    'What areas of the map look unsafe?',
    'I fitted a free-flow exhaust — what should I change?',
    'Lean at 3000 RPM partial throttle — how to fix?',
    'How much timing can I safely add for premium fuel?',
  ];

  @override
  void initState() {
    super.initState();
    _ai = TuningAI(apiKey: widget.apiKey);
    _messages.add(_ChatMessage(
      sender: _Sender.system,
      text: 'AI Tuning Assistant ready.\n'
          'ECU: ${widget.ecu.displayName}\n'
          'Maps loaded: ${widget.rom.maps.length}\n'
          'All suggestions are filtered by SafetyValidator before display.',
    ));
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Message handling ───────────────────────────────────────────────────────

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isThinking) return;

    _inputCtrl.clear();
    setState(() {
      _messages.add(_ChatMessage(sender: _Sender.user, text: trimmed));
      _isThinking = true;
    });
    _scrollToBottom();

    try {
      final suggestion = await _ai.ask(
        userMessage: trimmed,
        ecu: widget.ecu,
        rom: widget.rom,
        conversationHistory: List.from(_history),
      );

      _history.add({'role': 'user', 'content': trimmed});
      _history.add({'role': 'assistant', 'content': suggestion.rawAiResponse});

      setState(() {
        _isThinking = false;
        _messages.add(_ChatMessage(
          sender: _Sender.ai,
          text: _buildDisplayText(suggestion),
          suggestion: suggestion,
        ));
      });
    } catch (e) {
      setState(() {
        _isThinking = false;
        _messages.add(_ChatMessage(
          sender: _Sender.system,
          text: 'Error: $e',
        ));
      });
    }
    _scrollToBottom();
  }

  String _buildDisplayText(TuningSuggestion s) {
    final buf = StringBuffer(s.summary);
    if (s.cellChanges.isNotEmpty) {
      buf.write('\n\n${s.cellChanges.length} cell change(s) suggested.');
    }
    if (s.safetyWarning != null) {
      buf.write('\n\n⚠ ${s.safetyWarning}');
    }
    if (s.cellChanges.isEmpty && s.safetyWarning == null) {
      buf.write('\n\n(No actionable cell changes parsed — see full response below.)');
    }
    return buf.toString();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _applyChanges(TuningSuggestion suggestion) {
    if (suggestion.cellChanges.isEmpty) return;
    widget.onApply(suggestion.cellChanges);
    setState(() {
      _messages.add(_ChatMessage(
        sender: _Sender.system,
        text: '✅ ${suggestion.cellChanges.length} change(s) applied to map. '
            'Undo available in map editor.',
      ));
    });
    _scrollToBottom();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHandle(theme),
          _buildHeader(theme),
          _buildQuickPrompts(theme),
          const Divider(height: 1),
          Expanded(child: _buildMessageList(theme)),
          if (_isThinking) _buildThinkingIndicator(theme),
          const Divider(height: 1),
          _buildInputBar(theme),
        ],
      ),
    );
  }

  Widget _buildHandle(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: theme.colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: 8),
          Text(
            'AI Tuning Assistant',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: widget.onDismiss,
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPrompts(ThemeData theme) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: _quickPrompts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) => ActionChip(
          label: Text(
            _quickPrompts[i],
            style: theme.textTheme.bodySmall,
          ),
          onPressed: _isThinking ? null : () => _send(_quickPrompts[i]),
        ),
      ),
    );
  }

  Widget _buildMessageList(ThemeData theme) {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, i) => _buildMessageBubble(_messages[i], theme),
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg, ThemeData theme) {
    final isUser = msg.sender == _Sender.user;
    final isSystem = msg.sender == _Sender.system;

    if (isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            msg.text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: isUser
                    ? theme.colorScheme.primary
                    : theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: Text(
                msg.text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isUser
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            if (!isUser && msg.suggestion != null)
              _buildSuggestionActions(msg.suggestion!, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionActions(TuningSuggestion suggestion, ThemeData theme) {
    if (suggestion.cellChanges.isEmpty) return const SizedBox.shrink();

    final riskColor = switch (suggestion.riskLevel) {
      RiskLevel.low => Colors.green,
      RiskLevel.medium => Colors.orange,
      RiskLevel.high => Colors.red,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: riskColor.withOpacity(0.15),
              border: Border.all(color: riskColor),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              suggestion.riskLevel.name.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: riskColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.edit, size: 14),
            label: Text('Apply ${suggestion.cellChanges.length} change(s)'),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () => _applyChanges(suggestion),
          ),
          const SizedBox(width: 6),
          _FullResponseButton(rawResponse: suggestion.rawAiResponse),
        ],
      ),
    );
  }

  Widget _buildThinkingIndicator(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Analyzing map...',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(ThemeData theme) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputCtrl,
                enabled: !_isThinking,
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: _send,
                decoration: InputDecoration(
                  hintText: 'Ask about your tune…',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: theme.colorScheme.outline),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _isThinking ? null : () => _send(_inputCtrl.text),
              style: FilledButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: EdgeInsets.zero,
                shape: const CircleBorder(),
              ),
              child: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Full response dialog button ───────────────────────────────────────────────

class _FullResponseButton extends StatelessWidget {
  final String rawResponse;
  const _FullResponseButton({required this.rawResponse});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
      onPressed: () => showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Full AI Response'),
          content: SingleChildScrollView(
            child: SelectableText(
              rawResponse,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
      child: const Text('Full response'),
    );
  }
}
