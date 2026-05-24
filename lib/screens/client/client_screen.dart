import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_colors.dart';
import '../../core/database/db_helper.dart';
import '../../models/client_model.dart';

class ClientScreen extends StatefulWidget {
  const ClientScreen({super.key});

  @override
  State<ClientScreen> createState() => _ClientScreenState();
}

class _ClientScreenState extends State<ClientScreen> {
  List<ClientModel> _clients = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    setState(() => _isLoading = true);
    final clients = await DbHelper.getAllClients();
    if (mounted) setState(() { _clients = clients; _isLoading = false; });
  }

  void _openForm({ClientModel? existing}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: AppColors.cardBorder),
      ),
      builder: (_) => _ClientForm(existing: existing),
    );
    if (result == true) _loadClients();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mga Kliyente'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _loadClients,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Bagong Kliyente'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textPrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _clients.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.people_outline,
                        size: 56, color: AppColors.textSecondary),
                    const SizedBox(height: 12),
                    const Text('Walang kliyente pa.',
                        style: TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.person_add_outlined),
                      label: const Text('Magdagdag ng Kliyente'),
                      onPressed: () => _openForm(),
                    ),
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: _loadClients,
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _clients.length,
                    itemBuilder: (_, i) => _ClientCard(
                      client: _clients[i],
                      onTap: () => _openForm(existing: _clients[i]),
                    ),
                  ),
                ),
    );
  }
}

// ---------------------------------------------------------------------------
// Client card
// ---------------------------------------------------------------------------

class _ClientCard extends StatelessWidget {
  final ClientModel client;
  final VoidCallback onTap;
  const _ClientCard({required this.client, required this.onTap});

  static final _fmt = DateFormat('MMM d, yyyy');

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_outline,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(client.name,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
              const SizedBox(height: 2),
              Row(children: [
                if (client.plateNumber != null) ...[
                  const Icon(Icons.credit_card_outlined,
                      size: 12, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(client.plateNumber!,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(width: 8),
                ],
                if (client.motorcycleBrand != null)
                  Text(
                    '${client.motorcycleBrand} ${client.motorcycleModel ?? ""}',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
              ]),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (client.lastServiceAt != null)
              Text(
                _fmt.format(client.lastServiceAt!),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            if (client.currentOdometer != null) ...[
              const SizedBox(height: 2),
              Text(
                '${client.currentOdometer!.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} km',
                style: const TextStyle(
                    color: AppColors.primary, fontSize: 11),
              ),
            ],
          ]),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add / Edit form (bottom sheet)
// ---------------------------------------------------------------------------

class _ClientForm extends StatefulWidget {
  final ClientModel? existing;
  const _ClientForm({this.existing});

  @override
  State<_ClientForm> createState() => _ClientFormState();
}

class _ClientFormState extends State<_ClientForm> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _plateCtrl;
  late final TextEditingController _brandCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _colorCtrl;
  late final TextEditingController _yearCtrl;
  late final TextEditingController _odomCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _phoneCtrl = TextEditingController(text: e?.phone ?? '');
    _plateCtrl = TextEditingController(text: e?.plateNumber ?? '');
    _brandCtrl = TextEditingController(text: e?.motorcycleBrand ?? '');
    _modelCtrl = TextEditingController(text: e?.motorcycleModel ?? '');
    _colorCtrl = TextEditingController(text: e?.motorcycleColor ?? '');
    _yearCtrl = TextEditingController(
        text: e?.motorcycleYear?.toString() ?? '');
    _odomCtrl = TextEditingController(
        text: e?.currentOdometer?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _plateCtrl.dispose();
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _colorCtrl.dispose();
    _yearCtrl.dispose();
    _odomCtrl.dispose();
    super.dispose();
  }

  bool get _isEdit => widget.existing != null;

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pangalan ay kinakailangan.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final now = DateTime.now();
      if (_isEdit) {
        final updated = widget.existing!.copyWith(
          name: name,
          phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          plateNumber: _plateCtrl.text.trim().isEmpty ? null : _plateCtrl.text.trim(),
          motorcycleBrand: _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
          motorcycleModel: _modelCtrl.text.trim().isEmpty ? null : _modelCtrl.text.trim(),
          motorcycleColor: _colorCtrl.text.trim().isEmpty ? null : _colorCtrl.text.trim(),
          motorcycleYear: _yearCtrl.text.isEmpty ? null : int.tryParse(_yearCtrl.text),
          currentOdometer: _odomCtrl.text.isEmpty ? null : int.tryParse(_odomCtrl.text),
          lastServiceAt: now,
        );
        await DbHelper.updateClient(updated);
      } else {
        final client = ClientModel(
          id: const Uuid().v4(),
          name: name,
          phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          plateNumber: _plateCtrl.text.trim().isEmpty ? null : _plateCtrl.text.trim(),
          motorcycleBrand: _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
          motorcycleModel: _modelCtrl.text.trim().isEmpty ? null : _modelCtrl.text.trim(),
          motorcycleColor: _colorCtrl.text.trim().isEmpty ? null : _colorCtrl.text.trim(),
          motorcycleYear: _yearCtrl.text.isEmpty ? null : int.tryParse(_yearCtrl.text),
          currentOdometer: _odomCtrl.text.isEmpty ? null : int.tryParse(_odomCtrl.text),
          createdAt: now,
          lastServiceAt: now,
        );
        await DbHelper.insertClient(client);
      }
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + inset),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Text(
            _isEdit ? 'I-edit ang Kliyente' : 'Bagong Kliyente',
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.textSecondary),
            onPressed: () => Navigator.pop(context, false),
          ),
        ]),
        const SizedBox(height: 12),
        Flexible(
          child: SingleChildScrollView(
            child: Column(children: [
              _Field(controller: _nameCtrl, label: 'Pangalan *', hint: 'Juan dela Cruz'),
              const SizedBox(height: 8),
              _Field(controller: _phoneCtrl, label: 'Telepono', hint: '09xx xxx xxxx',
                  keyboardType: TextInputType.phone),
              const SizedBox(height: 8),
              _Field(controller: _plateCtrl, label: 'Plate Number', hint: 'ABC 1234',
                  caps: TextCapitalization.characters),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Motorsiklo',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: _Field(controller: _brandCtrl, label: 'Brand', hint: 'Yamaha')),
                const SizedBox(width: 8),
                Expanded(child: _Field(controller: _modelCtrl, label: 'Model', hint: 'Mio Aerox')),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _Field(controller: _colorCtrl, label: 'Kulay', hint: 'Puti')),
                const SizedBox(width: 8),
                Expanded(
                  child: _Field(
                    controller: _yearCtrl,
                    label: 'Taon',
                    hint: '2023',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              _Field(
                controller: _odomCtrl,
                label: 'Kasalukuyang Odometer (km)',
                hint: '12500',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isEdit ? 'I-update' : 'I-save'),
                  onPressed: _isSaving ? null : _save,
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType keyboardType;
  final TextCapitalization caps;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType = TextInputType.text,
    this.caps = TextCapitalization.words,
  });

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: caps,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          isDense: true,
        ),
      );
}
