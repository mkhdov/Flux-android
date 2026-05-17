import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/calendar_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../features/auth/providers/auth_provider.dart';

class CreateEventSheet extends StatefulWidget {
  final DateTime? selectedDate;
  final String? initialTitle;
  final int? initialStartMinutes;
  final int? initialDurationMinutes;

  const CreateEventSheet({
    super.key,
    this.selectedDate,
    this.initialTitle,
    this.initialStartMinutes,
    this.initialDurationMinutes,
  });

  @override
  State<CreateEventSheet> createState() => _CreateEventSheetState();
}

class _CreateEventSheetState extends State<CreateEventSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _inviteCtrl = TextEditingController();
  final _subtaskCtrl = TextEditingController();

  DateTime? _startDate;
  TimeOfDay? _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;
  bool _allDay = false;
  String _type = 'OTHERS';
  final String _status = 'NOTSTARTED';
  String _meetingType = 'none'; // none | meet | zoom
  String _selectedColor = '#6366F1';
  final List<String> _subtasks = [];
  final List<String> _invitees = [];
  bool _isLoading = false;
  String? _error;

  bool _plannerEnabled = false;
  final Map<String, bool> _plannerDays = {
    'monday': false,
    'tuesday': false,
    'wednesday': false,
    'thursday': false,
    'friday': false,
    'saturday': false,
    'sunday': false
  };
  int _numOfWeeks = 1;

  bool _notify = false;
  String _notifType = 'EMAIL';
  int _notifMinutes = 15;

  static const _eventTypes = [
    'OTHERS',
    'MEETING',
    'WORK',
    'TASK',
    'REMINDER',
    'STUDY',
    'APPOINTMENT',
    'BIRTHDAY',
    'HOLIDAY',
    'ROUTE'
  ];
  static const _colors = [
    '#6366F1',
    '#EC4899',
    '#F59E0B',
    '#10B981',
    '#3B82F6',
    '#EF4444',
    '#8B5CF6',
    '#14B8A6'
  ];

  @override
  void initState() {
    super.initState();
    _startDate = widget.selectedDate ?? DateTime.now();
    _endDate = _startDate;
    _titleCtrl.text = widget.initialTitle ?? '';

    if (widget.initialStartMinutes != null) {
      final h = widget.initialStartMinutes! ~/ 60;
      final m = widget.initialStartMinutes! % 60;
      _startTime = TimeOfDay(hour: h, minute: m);
    } else {
      _startTime = TimeOfDay.now();
    }

    if (widget.initialDurationMinutes != null && _startTime != null) {
      final startMins = _startTime!.hour * 60 + _startTime!.minute;
      final endMins = startMins + widget.initialDurationMinutes!;
      _endTime = TimeOfDay(hour: (endMins ~/ 60) % 24, minute: endMins % 60);
    } else {
      _endTime = TimeOfDay(
          hour: (_startTime!.hour + 1) % 24, minute: _startTime!.minute);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _inviteCtrl.dispose();
    _subtaskCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial =
        isStart ? (_startDate ?? DateTime.now()) : (_endDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.dark(primary: AppColors.primary)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(picked)) _endDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = (isStart ? _startTime : _endTime) ?? TimeOfDay.now();
    final picked = await showTimePicker(
        context: context,
        initialTime: initial,
        builder: (ctx, child) => Theme(
              data: Theme.of(ctx).copyWith(
                  colorScheme:
                      const ColorScheme.dark(primary: AppColors.primary)),
              child: child!,
            ));
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  void _addSubtask() {
    if (_subtaskCtrl.text.trim().isNotEmpty) {
      setState(() {
        _subtasks.add(_subtaskCtrl.text.trim());
        _subtaskCtrl.clear();
      });
    }
  }

  void _addInvitee() {
    final email = _inviteCtrl.text.trim();
    if (email.isNotEmpty && email.contains('@')) {
      setState(() {
        _invitees.add(email);
        _inviteCtrl.clear();
      });
    }
  }

  String _buildIso(DateTime? date, TimeOfDay? time) {
    if (date == null) return '';
    final dt = time != null
        ? DateTime(date.year, date.month, date.day, time.hour, time.minute)
        : date;
    return dt.toUtc().toIso8601String();
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Event title is required.');
      return;
    }
    if (_plannerEnabled && !_plannerDays.values.any((selected) => selected)) {
      setState(() => _error = 'Select at least one repeat day.');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final provider = context.read<CalendarProvider>();
    final auth = context.read<AuthProvider>();

    final data = {
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'type': _type,
      'status': _status,
      'colorHex': _selectedColor,
      'allDay': _allDay,
      if (_startDate != null)
        'date': DateFormat('yyyy-MM-dd').format(_startDate!),
      if (_startDate != null)
        'startTime': _buildIso(_startDate, _allDay ? null : _startTime),
      if (_endDate != null)
        'endTime': _buildIso(_endDate, _allDay ? null : _endTime),
      if (_subtasks.isNotEmpty)
        'subtasks':
            _subtasks.map((s) => {'subtask': s, 'isDone': false}).toList(),
      if (_plannerEnabled)
        'planner': {
          ..._plannerDays,
          'numOfWeeks': _numOfWeeks,
        },
      if (_notify)
        'notification': {
          'enabled': true,
          'type': _notifType,
          'minutesBefore': _notifMinutes,
        },
    };

    try {
      final events = await provider.createEvent(
        data: data,
        meetingType: _meetingType,
        userId: auth.user?.id,
      );

      if (!mounted) return;

      if (events.isNotEmpty) {
        final event = events.first;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_plannerEnabled
                ? 'Recurring event created!'
                : 'Event "${event.title}" created!'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        setState(() {
          _isLoading = false;
          _error = 'Failed to create event. Please try again.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error =
              'Error: ${e.toString().contains('500') ? 'Internal Server Error' : 'Connection failed'}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: const Color(0xFF262626),
                        borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),

            // Header
            Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.add_circle_outline,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Text('New Event',
                  style: GoogleFonts.roboto(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ]),
            const SizedBox(height: 20),

            // Type selection (Horizontal list)
            _label('Event Type'),
            const SizedBox(height: 8),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _eventTypes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final type = _eventTypes[i];
                  final isActive = _type == type;
                  return GestureDetector(
                    onTap: () => setState(() => _type = type),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.primary
                            : const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: isActive
                                ? AppColors.primary
                                : const Color(0xFF262626)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        type[0] + type.substring(1).toLowerCase(),
                        style: GoogleFonts.roboto(
                            fontSize: 13,
                            fontWeight:
                                isActive ? FontWeight.w600 : FontWeight.w400,
                            color: isActive
                                ? Colors.white
                                : AppColors.textSecondary),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Title
            _label('Title *'),
            const SizedBox(height: 6),
            _textField(_titleCtrl, 'Event title'),
            const SizedBox(height: 14),

            // Description
            _label('Description'),
            const SizedBox(height: 6),
            _textField(_descCtrl, 'Optional description', maxLines: 2),
            const SizedBox(height: 14),

            // All day + dates
            Row(children: [
              Switch(
                  value: _allDay,
                  onChanged: (v) => setState(() => _allDay = v),
                  activeThumbColor: AppColors.primary),
              const SizedBox(width: 6),
              Text('All Day',
                  style: GoogleFonts.roboto(
                      color: AppColors.textSecondary, fontSize: 14)),
            ]),
            const SizedBox(height: 10),

            // Start date/time
            Row(children: [
              Expanded(
                  child: _DateTimePicker(
                label: 'Start',
                date: _startDate,
                time: !_allDay ? _startTime : null,
                showTime: !_allDay,
                onDateTap: () => _pickDate(isStart: true),
                onTimeTap: () => _pickTime(isStart: true),
              )),
              const SizedBox(width: 8),
              Expanded(
                  child: _DateTimePicker(
                label: 'End',
                date: _endDate,
                time: !_allDay ? _endTime : null,
                showTime: !_allDay,
                onDateTap: () => _pickDate(isStart: false),
                onTimeTap: () => _pickTime(isStart: false),
              )),
            ]),
            const SizedBox(height: 14),

            // Color
            _label('Color'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: _colors.map((hex) {
                final c = Color(int.parse('FF${hex.substring(1)}', radix: 16));
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = hex),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: _selectedColor == hex
                            ? Border.all(color: Colors.white, width: 2)
                            : null),
                    child: _selectedColor == hex
                        ? const Icon(Icons.check, color: Colors.white, size: 14)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Meeting type
            _label('Video Conferencing'),
            const SizedBox(height: 8),
            Row(children: [
              _MeetChip(
                  label: 'None',
                  isActive: _meetingType == 'none',
                  color: AppColors.textMuted,
                  onTap: () => setState(() => _meetingType = 'none')),
              const SizedBox(width: 8),
              _MeetChip(
                  label: 'Google Meet',
                  isActive: _meetingType == 'meet',
                  color: const Color(0xFF34A853),
                  onTap: () => setState(() => _meetingType = 'meet')),
              const SizedBox(width: 8),
              _MeetChip(
                  label: 'Zoom',
                  isActive: _meetingType == 'zoom',
                  color: const Color(0xFF2D8CFF),
                  onTap: () => setState(() => _meetingType = 'zoom')),
            ]),
            const SizedBox(height: 18),

            // Planner Mode
            Row(children: [
              _label('Repeat (Planner Mode)'),
              const Spacer(),
              Switch(
                value: _plannerEnabled,
                onChanged: (v) => setState(() => _plannerEnabled = v),
                activeThumbColor: AppColors.primary,
              ),
            ]),
            if (_plannerEnabled) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _plannerDays.keys.map((day) {
                  final isActive = _plannerDays[day]!;
                  return GestureDetector(
                    onTap: () => setState(() => _plannerDays[day] = !isActive),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.primary
                            : const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: isActive
                                ? AppColors.primary
                                : const Color(0xFF262626)),
                      ),
                      child: Text(
                        day.substring(0, 3).toUpperCase(),
                        style: GoogleFonts.roboto(
                          fontSize: 11,
                          fontWeight:
                              isActive ? FontWeight.w600 : FontWeight.w400,
                          color:
                              isActive ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Text('Repeat for',
                    style: GoogleFonts.roboto(
                        color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(width: 8),
                SizedBox(
                  width: 50,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.roboto(
                        color: AppColors.textPrimary, fontSize: 13),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        filled: true,
                        fillColor: const Color(0xFF1A1A1A),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide.none)),
                    onChanged: (v) => _numOfWeeks = int.tryParse(v) ?? 1,
                    controller:
                        TextEditingController(text: _numOfWeeks.toString()),
                  ),
                ),
                const SizedBox(width: 8),
                Text('weeks',
                    style: GoogleFonts.roboto(
                        color: AppColors.textSecondary, fontSize: 13)),
              ]),
            ],
            const SizedBox(height: 14),

            // Subtasks
            _label('Subtasks (${_subtasks.length})'),
            const SizedBox(height: 6),
            ..._subtasks.asMap().entries.map((entry) => Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    const Icon(Icons.check_box_outline_blank,
                        size: 16, color: AppColors.textMuted),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(entry.value,
                            style: GoogleFonts.roboto(
                                color: AppColors.textSecondary, fontSize: 13))),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _subtasks.removeAt(entry.key)),
                      child: const Icon(Icons.close,
                          size: 16, color: AppColors.textMuted),
                    ),
                  ]),
                )),
            Row(children: [
              Expanded(child: _textField(_subtaskCtrl, 'Add a subtask…')),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _addSubtask,
                child: Container(
                  width: 38,
                  height: 48,
                  decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(10)),
                  child:
                      const Icon(Icons.add, color: AppColors.primary, size: 20),
                ),
              ),
            ]),
            const SizedBox(height: 18),

            // Notifications
            Row(children: [
              _label('Notification'),
              const Spacer(),
              Switch(
                value: _notify,
                onChanged: (v) => setState(() => _notify = v),
                activeThumbColor: AppColors.primary,
              ),
            ]),
            if (_notify) ...[
              const SizedBox(height: 8),
              Row(children: [
                _MeetChip(
                    label: '📧 Email',
                    isActive: _notifType == 'EMAIL',
                    color: AppColors.primary,
                    onTap: () => setState(() => _notifType = 'EMAIL')),
                const SizedBox(width: 8),
                _MeetChip(
                    label: '🔔 Push',
                    isActive: _notifType == 'PUSH',
                    color: const Color(0xFF10B981),
                    onTap: () => setState(() => _notifType = 'PUSH')),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Text('Notify',
                    style: GoogleFonts.roboto(
                        color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(width: 8),
                SizedBox(
                  width: 50,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.roboto(
                        color: AppColors.textPrimary, fontSize: 13),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        filled: true,
                        fillColor: const Color(0xFF1A1A1A),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide.none)),
                    onChanged: (v) => _notifMinutes = int.tryParse(v) ?? 15,
                    controller:
                        TextEditingController(text: _notifMinutes.toString()),
                  ),
                ),
                const SizedBox(width: 8),
                Text('minutes before',
                    style: GoogleFonts.roboto(
                        color: AppColors.textSecondary, fontSize: 13)),
              ]),
            ],
            const SizedBox(height: 14),

            // Invite
            _label('Invite Members'),
            const SizedBox(height: 6),
            ..._invitees.map((email) => Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    const Icon(Icons.person,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(email,
                            style: GoogleFonts.roboto(
                                color: AppColors.textSecondary, fontSize: 13))),
                    GestureDetector(
                        onTap: () => setState(() => _invitees.remove(email)),
                        child: const Icon(Icons.close,
                            size: 14, color: AppColors.textMuted)),
                  ]),
                )),
            Row(children: [
              Expanded(
                  child: TextField(
                controller: _inviteCtrl,
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.roboto(
                    color: AppColors.textPrimary, fontSize: 14),
                onSubmitted: (_) => _addInvitee(),
                decoration: InputDecoration(
                  hintText: 'Email address',
                  hintStyle: GoogleFonts.roboto(color: AppColors.textDisabled),
                  filled: true,
                  fillColor: const Color(0xFF1A1A1A),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              )),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _addInvitee,
                child: Container(
                    width: 38,
                    height: 48,
                    decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.person_add,
                        color: AppColors.primary, size: 18)),
              ),
            ]),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style:
                      GoogleFonts.roboto(color: AppColors.error, fontSize: 13)),
            ],
            const SizedBox(height: 24),

            // Submit
            SizedBox(
              width: double.infinity,
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12)),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white)))
                      : Text('Create Event',
                          style: GoogleFonts.roboto(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: GoogleFonts.roboto(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary));

  Widget _textField(TextEditingController ctrl, String hint,
          {int maxLines = 1}) =>
      TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: GoogleFonts.roboto(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.roboto(color: AppColors.textDisabled),
          filled: true,
          fillColor: const Color(0xFF1A1A1A),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      );
}

class _DateTimePicker extends StatelessWidget {
  final String label;
  final DateTime? date;
  final TimeOfDay? time;
  final bool showTime;
  final VoidCallback onDateTap;
  final VoidCallback onTimeTap;

  const _DateTimePicker(
      {required this.label,
      this.date,
      this.time,
      required this.showTime,
      required this.onDateTap,
      required this.onTimeTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.roboto(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted)),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: onDateTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(Icons.calendar_today,
                  size: 13, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                  date != null
                      ? DateFormat('MMM d, yy').format(date!)
                      : 'Select',
                  style: GoogleFonts.roboto(
                      fontSize: 12,
                      color: date != null
                          ? AppColors.textPrimary
                          : AppColors.textDisabled)),
            ]),
          ),
        ),
        if (showTime) ...[
          const SizedBox(height: 4),
          GestureDetector(
            onTap: onTimeTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.access_time,
                    size: 13, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(time != null ? time!.format(context) : 'Select',
                    style: GoogleFonts.roboto(
                        fontSize: 12,
                        color: time != null
                            ? AppColors.textPrimary
                            : AppColors.textDisabled)),
              ]),
            ),
          ),
        ],
      ],
    );
  }
}

class _MeetChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color color;
  final VoidCallback onTap;

  const _MeetChip(
      {required this.label,
      required this.isActive,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? color.withValues(alpha: 0.15)
              : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(8),
          border:
              isActive ? Border.all(color: color.withValues(alpha: 0.5)) : null,
        ),
        child: Text(label,
            style: GoogleFonts.roboto(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? color : AppColors.textMuted)),
      ),
    );
  }
}
