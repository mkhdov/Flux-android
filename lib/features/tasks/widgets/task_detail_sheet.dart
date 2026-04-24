import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/task_provider.dart';
import '../models/task_model.dart';
import '../../../core/constants/app_colors.dart';

class TaskDetailSheet extends StatefulWidget {
  final String taskId;
  const TaskDetailSheet({super.key, required this.taskId});

  @override
  State<TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends State<TaskDetailSheet> {
  bool _isEditing = false;
  bool _showDeleteConfirm = false;

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  TaskStatus _editStatus = TaskStatus.todo;
  TaskPriority _editPriority = TaskPriority.low;
  DateTime? _editDate;
  DateTime? _editDeadline;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTask());
  }

  Future<void> _loadTask() async {
    final provider = context.read<TaskProvider>();
    await provider.selectTask(widget.taskId);
    if (!mounted) return;
    _populateEditForm(provider.selectedTask);
  }

  void _populateEditForm(TaskModel? task) {
    if (task == null) return;
    _titleCtrl.text = task.title;
    _descCtrl.text = task.description ?? '';
    _editStatus = task.status;
    _editPriority = task.priority;
    _editDate = task.dateDateTime;
    _editDeadline = task.deadlineDateTime;
  }

  Future<void> _saveEdit() async {
    final provider = context.read<TaskProvider>();
    await provider.updateTask(widget.taskId, {
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'status': _editStatus.value,
      'priority': _editPriority.value,
      'date': _editDate != null ? _editDate!.toIso8601String().split('T')[0] : null,
      'deadline': _editDeadline?.toUtc().toIso8601String(),
    });
    if (!mounted) return;
    setState(() => _isEditing = false);
  }

  void _delete() {
    final provider = context.read<TaskProvider>();
    final taskId = widget.taskId;
    final taskTitle = provider.selectedTask?.title ?? 'Task';
    
    provider.deleteTask(taskId);
    Navigator.pop(context);

    // Show undo snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted "$taskTitle"'),
        backgroundColor: const Color(0xFF2A2A2C),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: AppColors.primary,
          onPressed: () => provider.undoDeleteTask(taskId),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final task = provider.selectedTask;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF2D2D2D)))),
            child: Row(children: [
              const Spacer(),
              if (task != null && !provider.isPanelLoading) ...[
                if (!_isEditing)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: AppColors.textSecondary, size: 20),
                    onPressed: () { _populateEditForm(task); setState(() => _isEditing = true); },
                  )
                else
                  TextButton(onPressed: () => setState(() => _isEditing = false), child: Text('Cancel', style: GoogleFonts.roboto(color: AppColors.textMuted))),
                IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20), onPressed: _delete),
              ],
              IconButton(icon: const Icon(Icons.close, color: AppColors.textMuted, size: 20), onPressed: () => Navigator.pop(context)),
            ]),
          ),

          // Body
          Expanded(
            child: provider.isPanelLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : task == null
                    ? Center(child: Text(provider.panelError ?? 'Not found', style: GoogleFonts.roboto(color: AppColors.error)))
                    : SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
                        child: _isEditing ? _editMode(task) : _viewMode(task, provider),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _viewMode(TaskModel task, TaskProvider provider) {
    final statusColor = <TaskStatus, Color>{
      TaskStatus.todo: AppColors.statusTodo,
      TaskStatus.inProgress: AppColors.statusInProgress,
      TaskStatus.done: AppColors.statusDone,
    }[task.status]!;

    final priorityColor = <TaskPriority, Color>{
      TaskPriority.low: AppColors.priorityLow,
      TaskPriority.medium: AppColors.priorityMedium,
      TaskPriority.high: AppColors.priorityHigh,
    }[task.priority]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Badges
        Row(children: [
          _StatusBadge(label: task.status.label, color: statusColor),
          const SizedBox(width: 8),
          _StatusBadge(label: task.priority.label, color: priorityColor),
        ]),
        const SizedBox(height: 12),

        // Title
        Text(
          task.title,
          style: GoogleFonts.roboto(
            fontSize: 22, fontWeight: FontWeight.w700,
            color: task.status == TaskStatus.done ? AppColors.textMuted : Colors.white,
            decoration: task.status == TaskStatus.done ? TextDecoration.lineThrough : null,
          ),
        ),
        const SizedBox(height: 10),

        // Description
        if (task.description != null && task.description!.isNotEmpty) ...[
          Text(task.description!, style: GoogleFonts.roboto(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
          const SizedBox(height: 12),
        ],

        // Date / Deadline
        if (task.date != null || task.deadline != null)
          Row(children: [
            if (task.date != null) _Chip(icon: Icons.calendar_today, text: _fmt(task.date!)),
            if (task.date != null && task.deadline != null) const SizedBox(width: 12),
            if (task.deadline != null) _DeadlineInfo(deadline: task.deadline!),
          ]),
        if (task.date != null || task.deadline != null) const SizedBox(height: 14),

        // Subtask progress
        if (task.subtasks.isNotEmpty) ...[
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Subtasks', style: GoogleFonts.roboto(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
            Text('${task.subtaskDone}/${task.subtasks.length}', style: GoogleFonts.roboto(fontSize: 12, color: AppColors.textMuted)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: task.subtaskProgress,
              backgroundColor: const Color(0xFF3A3A3C),
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 8),
          ...task.subtasks.map((s) => Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFF2A2A2C), borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Icon(s.isDone ? Icons.check_box : Icons.check_box_outline_blank, size: 16, color: s.isDone ? AppColors.primary : AppColors.textMuted),
              const SizedBox(width: 8),
              Expanded(child: Text(s.subtask, style: GoogleFonts.roboto(fontSize: 13, color: s.isDone ? AppColors.textMuted : AppColors.textSecondary, decoration: s.isDone ? TextDecoration.lineThrough : null))),
            ]),
          )),
          const SizedBox(height: 8),
        ],

        // Notes
        if (task.notes.isNotEmpty) ...[
          Text('Notes (${task.notes.length})', style: GoogleFonts.roboto(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
          const SizedBox(height: 8),
          ...task.notes.map((n) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF2A2A2C), borderRadius: BorderRadius.circular(10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(n.content, style: GoogleFonts.roboto(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 4),
              Text(_fmt(n.createdAt), style: GoogleFonts.roboto(color: AppColors.textMuted, fontSize: 11)),
            ]),
          )),
        ],


        const SizedBox(height: 20),
        Text('Created ${_fmt(task.createdAt)}  ·  Updated ${_fmt(task.updatedAt)}',
            style: GoogleFonts.roboto(fontSize: 11, color: AppColors.textDisabled)),
      ],
    );
  }

  Widget _editMode(TaskModel task) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Edit Task', style: GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 16),

        _label('Title *'),
        const SizedBox(height: 6),
        _textField(_titleCtrl, 'Task title'),
        const SizedBox(height: 14),

        _label('Description'),
        const SizedBox(height: 6),
        _textField(_descCtrl, 'Description', maxLines: 3),
        const SizedBox(height: 14),

        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label('Status'),
            const SizedBox(height: 6),
            _Drop(value: _editStatus.label, items: TaskStatus.values.map((s) => s.label).toList(), onChanged: (v) => setState(() => _editStatus = TaskStatus.values.firstWhere((s) => s.label == v))),
          ])),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label('Priority'),
            const SizedBox(height: 6),
            _Drop(value: _editPriority.label, items: TaskPriority.values.map((p) => p.label).toList(), onChanged: (v) => setState(() => _editPriority = TaskPriority.values.firstWhere((p) => p.label == v))),
          ])),
        ]),
        const SizedBox(height: 24),

        Row(children: [
          Expanded(child: OutlinedButton(
            onPressed: () => setState(() => _isEditing = false),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.textMuted, side: const BorderSide(color: Color(0xFF3A3A3C)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 14)),
            child: Text('Cancel', style: GoogleFonts.roboto(fontWeight: FontWeight.w600)),
          )),
          const SizedBox(width: 12),
          Expanded(child: DecoratedBox(
            decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(10)),
            child: ElevatedButton(
              onPressed: _saveEdit,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 14)),
              child: Text('Save Changes', style: GoogleFonts.roboto(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          )),
        ]),
      ],
    );
  }

  String _fmt(String s) {
    try { return DateFormat('MMM d, yyyy').format(DateTime.parse(s).toLocal()); } catch (_) { return s; }
  }

  Widget _label(String t) => Text(t, style: GoogleFonts.roboto(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary));
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

  Widget _Drop({required String value, required List<String> items, required void Function(String) onChanged}) =>
    DropdownButtonFormField<String>(
      value: value, dropdownColor: const Color(0xFF2A2A2C),
      style: GoogleFonts.roboto(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(filled: true, fillColor: const Color(0xFF2A2A2C), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), isDense: true),
      items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
      onChanged: (v) { if (v != null) onChanged(v); },
    );
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label, style: GoogleFonts.roboto(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Chip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 12, color: AppColors.textMuted),
    const SizedBox(width: 4),
    Text(text, style: GoogleFonts.roboto(fontSize: 12, color: AppColors.textMuted)),
  ]);
}

class _DeadlineInfo extends StatelessWidget {
  final String deadline;
  const _DeadlineInfo({required this.deadline});

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.tryParse(deadline)?.toLocal();
    if (dt == null) return const SizedBox.shrink();
    final diff = dt.difference(DateTime.now());
    final days = diff.inDays;
    String text; Color color;
    if (days < 0) { text = '${days.abs()}d overdue'; color = AppColors.error; }
    else if (days == 0) { text = 'Due today'; color = AppColors.warning; }
    else if (days <= 3) { text = '${days}d left'; color = AppColors.warning; }
    else { text = DateFormat('MMM d').format(dt); color = AppColors.textMuted; }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.timer_outlined, size: 12, color: color),
      const SizedBox(width: 4),
      Text(text, style: GoogleFonts.roboto(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    ]);
  }
}
