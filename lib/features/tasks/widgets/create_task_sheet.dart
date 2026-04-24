import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/task_provider.dart';
import '../models/task_model.dart';
import '../../../core/constants/app_colors.dart';

class CreateTaskSheet extends StatefulWidget {
  final String calendarId;
  const CreateTaskSheet({super.key, required this.calendarId});

  @override
  State<CreateTaskSheet> createState() => _CreateTaskSheetState();
}

class _CreateTaskSheetState extends State<CreateTaskSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _subtaskCtrl = TextEditingController();

  TaskStatus _status = TaskStatus.todo;
  TaskPriority _priority = TaskPriority.low;
  DateTime? _date;
  DateTime? _deadline;
  List<String> _subtasks = [];
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _subtaskCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isDeadline}) async {
    final initial = isDeadline ? (_deadline ?? DateTime.now()) : (_date ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.dark(primary: AppColors.primary)), child: child!),
    );
    if (picked != null) setState(() { if (isDeadline) _deadline = picked; else _date = picked; });
  }

  void _addSubtask() {
    final text = _subtaskCtrl.text.trim();
    if (text.isNotEmpty) {
      setState(() { _subtasks.add(text); _subtaskCtrl.clear(); });
    }
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Title is required.');
      return;
    }
    setState(() { _isLoading = true; _error = null; });
    final provider = context.read<TaskProvider>();
    final success = await provider.createTask({
      'calendarId': widget.calendarId,
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'status': _status.value,
      'priority': _priority.value,
      'date': _date != null ? _date!.toIso8601String().split('T')[0] : null,
      'deadline': _deadline != null ? _deadline!.toUtc().toIso8601String() : null,
      'subtasks': _subtasks.map((s) => {'subtask': s, 'isDone': false}).toList(),
    });
    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
    } else {
      setState(() { _isLoading = false; _error = 'Failed to create task.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFF3A3A3C), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.check_box_outlined, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Text('New Task', style: GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
            ]),
            const SizedBox(height: 20),

            // Title
            _Label('Title *'),
            const SizedBox(height: 6),
            _textField(_titleCtrl, 'e.g. Review pull request'),
            const SizedBox(height: 14),

            // Description
            _Label('Description'),
            const SizedBox(height: 6),
            _textField(_descCtrl, 'Optional description', maxLines: 2),
            const SizedBox(height: 14),

            // Status + Priority
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _Label('Status'),
                const SizedBox(height: 6),
                _DropField(
                  value: _status.label,
                  items: TaskStatus.values.map((s) => s.label).toList(),
                  onChanged: (v) => setState(() => _status = TaskStatus.values.firstWhere((s) => s.label == v!, orElse: () => TaskStatus.todo)),
                ),
              ])),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _Label('Priority'),
                const SizedBox(height: 6),
                _DropField(
                  value: _priority.label,
                  items: TaskPriority.values.map((p) => p.label).toList(),
                  onChanged: (v) => setState(() => _priority = TaskPriority.values.firstWhere((p) => p.label == v!, orElse: () => TaskPriority.low)),
                ),
              ])),
            ]),
            const SizedBox(height: 14),

            // Date + Deadline
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _Label('Date'),
                const SizedBox(height: 6),
                _DateBtn(date: _date, onTap: () => _pickDate(isDeadline: false), onClear: () => setState(() => _date = null)),
              ])),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _Label('Deadline'),
                const SizedBox(height: 6),
                _DateBtn(date: _deadline, onTap: () => _pickDate(isDeadline: true), onClear: () => setState(() => _deadline = null)),
              ])),
            ]),
            const SizedBox(height: 14),

            // Subtasks
            _Label('Subtasks (${_subtasks.length})'),
            const SizedBox(height: 6),
            ..._subtasks.asMap().entries.map((e) => Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFF2A2A2C), borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.check_box_outline_blank, size: 15, color: AppColors.textMuted),
                const SizedBox(width: 8),
                Expanded(child: Text(e.value, style: GoogleFonts.roboto(color: AppColors.textSecondary, fontSize: 13))),
                GestureDetector(onTap: () => setState(() => _subtasks.removeAt(e.key)), child: const Icon(Icons.close, size: 15, color: AppColors.textMuted)),
              ]),
            )),
            Row(children: [
              Expanded(child: _textField(_subtaskCtrl, 'Add subtask…')),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _addSubtask,
                child: Container(width: 38, height: 48, decoration: BoxDecoration(color: const Color(0xFF2A2A2C), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.add, color: AppColors.primary, size: 20)),
              ),
            ]),

            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: GoogleFonts.roboto(color: AppColors.error, fontSize: 13)),
            ],
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity, height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(12)),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _isLoading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                      : Text('Create Task', style: GoogleFonts.roboto(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _Label(String t) => Text(t, style: GoogleFonts.roboto(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary));
  Widget _textField(TextEditingController ctrl, String hint, {int maxLines = 1}) => TextField(
    controller: ctrl, maxLines: maxLines,
    style: GoogleFonts.roboto(color: AppColors.textPrimary, fontSize: 14),
    decoration: InputDecoration(
      hintText: hint, hintStyle: GoogleFonts.roboto(color: AppColors.textDisabled),
      filled: true, fillColor: const Color(0xFF2A2A2C),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
  );
}

class _DropField extends StatelessWidget {
  final String value;
  final List<String> items;
  final void Function(String?) onChanged;

  const _DropField({required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    value: value,
    dropdownColor: const Color(0xFF2A2A2C),
    style: GoogleFonts.roboto(color: AppColors.textPrimary, fontSize: 14),
    decoration: InputDecoration(
      filled: true, fillColor: const Color(0xFF2A2A2C),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      isDense: true,
    ),
    items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
    onChanged: onChanged,
  );
}

class _DateBtn extends StatelessWidget {
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _DateBtn({this.date, required this.onTap, required this.onClear});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFF2A2A2C), borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        const Icon(Icons.calendar_today, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Expanded(child: Text(
          date != null ? '${date!.month}/${date!.day}/${date!.year}' : 'None',
          style: GoogleFonts.roboto(fontSize: 13, color: date != null ? AppColors.textPrimary : AppColors.textDisabled),
        )),
        if (date != null) GestureDetector(onTap: onClear, child: const Icon(Icons.close, size: 14, color: AppColors.textMuted)),
      ]),
    ),
  );
}
