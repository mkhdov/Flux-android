import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../calendar/providers/calendar_provider.dart';
import '../../tasks/providers/task_provider.dart';
import '../../tasks/models/task_model.dart';
import '../../tasks/widgets/create_task_sheet.dart';
import '../../tasks/widgets/task_detail_sheet.dart';
import '../../../core/constants/app_colors.dart';

class TaskView extends StatelessWidget {
  final GlobalKey<ScaffoldState>? scaffoldKey;
  const TaskView({super.key, this.scaffoldKey});

  @override
  Widget build(BuildContext context) {
    final calProvider = context.watch<CalendarProvider>();
    final taskProvider = context.watch<TaskProvider>();

    Widget topBar = Container(
      height: kToolbarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        border: Border(bottom: BorderSide(color: AppColors.border(context))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.menu,
                color: AppColors.adaptiveTextSecondary(context)),
            onPressed: () => scaffoldKey?.currentState?.openDrawer(),
          ),
          Expanded(
            child: Text(
              'Tasks',
              style: GoogleFonts.roboto(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.adaptiveTextPrimary(context),
              ),
            ),
          ),
          if (calProvider.selectedCalendar != null)
            IconButton(
              icon: Icon(Icons.refresh_rounded,
                  color: AppColors.adaptiveTextSecondary(context), size: 22),
              onPressed: () => context
                  .read<TaskProvider>()
                  .fetchTasks(calProvider.selectedCalendar!.id),
            ),
        ],
      ),
    );

    if (calProvider.selectedCalendar == null) {
      return Column(
        children: [
          topBar,
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        color: AppColors.textMuted, size: 48),
                    const SizedBox(height: 16),
                    Text('No calendar selected',
                        style: GoogleFonts.roboto(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text('Select a calendar from the menu to view its tasks.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.roboto(
                            color: AppColors.textMuted, fontSize: 14)),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        topBar,
        // Toolbar
        _Toolbar(provider: taskProvider),
        // Status tabs
        _StatusTabs(provider: taskProvider),
        const Divider(height: 1, color: Color(0xFF2D2D2D)),
        // Content
        Expanded(
          child: taskProvider.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : taskProvider.error != null
                  ? _ErrorState(msg: taskProvider.error!)
                  : taskProvider.filteredTasks.isEmpty
                      ? _EmptyState(
                          calendarId: calProvider.selectedCalendar!.id)
                      : _TaskList(provider: taskProvider),
        ),
      ],
    );
  }
}

class _Toolbar extends StatelessWidget {
  final TaskProvider provider;
  const _Toolbar({required this.provider});

  @override
  Widget build(BuildContext context) {
    final calProvider = context.read<CalendarProvider>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          // Search
          Expanded(
            child: TextField(
              onChanged: provider.setSearchQuery,
              style: GoogleFonts.roboto(
                  color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search tasks…',
                hintStyle: GoogleFonts.roboto(
                    color: AppColors.textDisabled, fontSize: 14),
                prefixIcon: const Icon(Icons.search,
                    color: AppColors.textMuted, size: 18),
                filled: true,
                fillColor: const Color(0xFF2A2A2C),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Add new task
          GestureDetector(
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) =>
                  CreateTaskSheet(calendarId: calProvider.selectedCalendar!.id),
            ),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusTabs extends StatelessWidget {
  final TaskProvider provider;
  const _StatusTabs({required this.provider});

  @override
  Widget build(BuildContext context) {
    final tabs = [
      (null, 'All', provider.counts['ALL'] ?? 0),
      (TaskStatus.todo, 'To Do', provider.counts['TODO'] ?? 0),
      (
        TaskStatus.inProgress,
        'In Progress',
        provider.counts['IN_PROGRESS'] ?? 0
      ),
      (TaskStatus.done, 'Done', provider.counts['DONE'] ?? 0),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: tabs.map((tab) {
          final (status, label, count) = tab;
          final isActive = provider.statusFilter == status;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => provider.setStatusFilter(status),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.primary.withOpacity(0.15)
                      : const Color(0xFF2A2A2C),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive ? AppColors.primary : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    if (status != null) ...[
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _statusColor(status),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      label,
                      style: GoogleFonts.roboto(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isActive
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.primary.withOpacity(0.2)
                            : const Color(0xFF3A3A3C),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        count.toString(),
                        style: GoogleFonts.roboto(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isActive
                                ? AppColors.primary
                                : AppColors.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _statusColor(TaskStatus status) {
    return switch (status) {
      TaskStatus.todo => AppColors.statusTodo,
      TaskStatus.inProgress => AppColors.statusInProgress,
      TaskStatus.done => AppColors.statusDone,
    };
  }
}

class _ErrorState extends StatelessWidget {
  final String msg;
  const _ErrorState({required this.msg});

  @override
  Widget build(BuildContext context) => Center(
        child: Text(msg,
            style: GoogleFonts.roboto(color: AppColors.error, fontSize: 14)),
      );
}

class _EmptyState extends StatelessWidget {
  final String calendarId;
  const _EmptyState({required this.calendarId});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_box_outlined,
              color: AppColors.textMuted, size: 48),
          const SizedBox(height: 12),
          Text('No tasks found',
              style: GoogleFonts.roboto(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Try adjusting filters or create a new task.',
              style:
                  GoogleFonts.roboto(color: AppColors.textMuted, fontSize: 14)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => CreateTaskSheet(calendarId: calendarId),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New Task'),
          ),
        ],
      ),
    );
  }
}

class _TaskList extends StatelessWidget {
  final TaskProvider provider;
  const _TaskList({required this.provider});

  @override
  Widget build(BuildContext context) {
    final tasks = provider.filteredTasks;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
      itemCount: tasks.length,
      itemBuilder: (ctx, i) => _TaskCard(task: tasks[i], provider: provider),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final TaskModel task;
  final TaskProvider provider;

  const _TaskCard({required this.task, required this.provider});

  Color _priorityColor(TaskPriority p) => switch (p) {
        TaskPriority.high => AppColors.priorityHigh,
        TaskPriority.medium => AppColors.priorityMedium,
        TaskPriority.low => AppColors.priorityLow,
      };

  Color _statusDotColor(TaskStatus s) => switch (s) {
        TaskStatus.todo => AppColors.statusTodo,
        TaskStatus.inProgress => AppColors.statusInProgress,
        TaskStatus.done => AppColors.statusDone,
      };

  @override
  Widget build(BuildContext context) {
    final isDone = task.status == TaskStatus.done;
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => TaskDetailSheet(taskId: task.id),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isDone ? const Color(0xFF1A1A1A) : const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2D2D2D)),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _priorityColor(task.priority),
                  borderRadius:
                      const BorderRadius.horizontal(left: Radius.circular(12)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 0, 0),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: badges + quick action
                    Row(
                      children: [
                        _Pill(
                          label: task.status.label,
                          dotColor: _statusDotColor(task.status),
                          color: _statusDotColor(task.status).withOpacity(0.15),
                          textColor: _statusDotColor(task.status),
                        ),
                        const SizedBox(width: 6),
                        _Pill(
                          label: task.priority.label,
                          color:
                              _priorityColor(task.priority).withOpacity(0.15),
                          textColor: _priorityColor(task.priority),
                        ),
                        const Spacer(),
                        // Quick status button
                        _QuickStatusButton(task: task, provider: provider),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Title
                    Text(
                      task.title,
                      style: GoogleFonts.roboto(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDone
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                        decorationColor: AppColors.textMuted,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (task.description != null &&
                        task.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        task.description!,
                        style: GoogleFonts.roboto(
                            fontSize: 12, color: AppColors.textMuted),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    // Subtask progress
                    if (task.subtasks.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: task.subtaskProgress,
                                backgroundColor: const Color(0xFF3A3A3C),
                                valueColor:
                                    AlwaysStoppedAnimation(AppColors.primary),
                                minHeight: 4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${task.subtaskDone}/${task.subtasks.length}',
                            style: GoogleFonts.roboto(
                                fontSize: 11, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ],
                    // Footer chips
                    if (task.date != null ||
                        task.deadline != null ||
                        task.notes.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        children: [
                          if (task.date != null)
                            _Chip(
                                icon: Icons.calendar_today,
                                text: _fmtDate(task.date!)),
                          if (task.deadline != null)
                            _DeadlineChip(deadline: task.deadline!),
                          if (task.notes.isNotEmpty)
                            _Chip(
                                icon: Icons.notes,
                                text:
                                    '${task.notes.length} note${task.notes.length != 1 ? "s" : ""}'),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return DateFormat('MMM d, yyyy').format(dt);
    } catch (_) {
      return dateStr;
    }
  }
}

class _QuickStatusButton extends StatelessWidget {
  final TaskModel task;
  final TaskProvider provider;

  const _QuickStatusButton({required this.task, required this.provider});

  @override
  Widget build(BuildContext context) {
    if (task.status == TaskStatus.done) {
      return GestureDetector(
        onTap: () => provider.quickStatus(task.id, TaskStatus.todo),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.statusDone.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.replay_rounded,
              color: AppColors.statusDone, size: 14),
        ),
      );
    }

    return GestureDetector(
      onTap: () => provider.quickStatus(
        task.id,
        task.status == TaskStatus.todo
            ? TaskStatus.inProgress
            : TaskStatus.done,
      ),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(
          task.status == TaskStatus.todo
              ? Icons.play_arrow_rounded
              : Icons.check_rounded,
          color: AppColors.primary,
          size: 14,
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color? dotColor;
  final Color color;
  final Color textColor;

  const _Pill(
      {required this.label,
      this.dotColor,
      required this.color,
      required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotColor != null) ...[
            Container(
                width: 5,
                height: 5,
                decoration:
                    BoxDecoration(color: dotColor, shape: BoxShape.circle)),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: GoogleFonts.roboto(
                  fontSize: 11, fontWeight: FontWeight.w500, color: textColor)),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Chip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: AppColors.textMuted),
        const SizedBox(width: 3),
        Text(text,
            style:
                GoogleFonts.roboto(fontSize: 11, color: AppColors.textMuted)),
      ],
    );
  }
}

class _DeadlineChip extends StatelessWidget {
  final String deadline;
  const _DeadlineChip({required this.deadline});

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.tryParse(deadline)?.toLocal();
    if (dt == null) return const SizedBox.shrink();

    final diff = dt.difference(DateTime.now());
    final days = diff.inDays;

    String text;
    Color color;
    if (days < 0) {
      text = '${days.abs()}d overdue';
      color = AppColors.error;
    } else if (days == 0) {
      text = 'Due today';
      color = AppColors.warning;
    } else if (days <= 3) {
      text = '${days}d left';
      color = AppColors.warning;
    } else {
      text = DateFormat('MMM d').format(dt);
      color = AppColors.textMuted;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.timer_outlined, size: 11, color: color),
        const SizedBox(width: 3),
        Text(text,
            style: GoogleFonts.roboto(
                fontSize: 11, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
