import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_filex/open_filex.dart';
import '../providers/calendar_provider.dart';
import '../models/event_model.dart';
import '../repositories/event_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import 'event_ui_helpers.dart';

// ─────────────────────────────────────────────
//  Design tokens
// ─────────────────────────────────────────────
class _DS {
  // Backgrounds
  static const bg1 = Color(0xFF121212);   // sheet background (matches daily timeline)
  static const bg2 = Color(0xFF181818);   // card background (neutral gray)

  // Aurora palette
  static const cyan   = Color(0xFF00E5FF);
  static const teal   = Color(0xFF00C9A7);
  static const indigo = Color(0xFF7B8CFF);
  static const rose   = Color(0xFFFF4F7B);
  static const amber  = Color(0xFFFFB84D);

  // Text
  static const t1 = Color(0xFFF0F4FF);
  static const t2 = Color(0xFFADB8D0);
  static const t3 = Color(0xFF5A6680);
  static const tDisabled = Color(0xFF2E3A50);

  // Borders
  static const border  = Color(0xFF262626);
  static const borderHi = Color(0xFF333333);

  // Semantic
  static const error = Color(0xFFFF4F7B);

  // Gradients
  static const auroraA = LinearGradient(
    colors: [Color(0xFF00E5FF), Color(0xFF7B8CFF), Color(0xFFFF4F7B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ─────────────────────────────────────────────
//  Main widget
// ─────────────────────────────────────────────
class EventDetailSheet extends StatefulWidget {
  final String eventId;
  const EventDetailSheet({super.key, required this.eventId});

  @override
  State<EventDetailSheet> createState() => _EventDetailSheetState();
}

class _EventDetailSheetState extends State<EventDetailSheet>
    with TickerProviderStateMixin {
  final _repo = EventRepository();
  EventModel? _event;
  bool _isLoading = true;
  String? _error;

  final _titleCtrl = TextEditingController();
  final _descCtrl  = TextEditingController();

  Map<String, dynamic>? _mapLinks;
  bool _mapLoading = false;

  late final AnimationController _shimmerCtrl;

  List<dynamic> _reminders = [];
  bool _remindersLoading = false;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    _loadEvent();
    _fetchReminders();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // ── data methods (unchanged logic) ─────────
  Future<void> _loadEvent() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final calProvider = context.read<CalendarProvider>();
      final existing = calProvider.events.firstWhere(
        (e) => e.id == widget.eventId,
        orElse: () => const EventModel(id: '', calendarId: '', title: '', allDay: false,
            subtasks: [], notes: [], members: [], attachments: [],
            createdAt: '', updatedAt: ''),
      );
      if (existing.id.isNotEmpty) {
        _event = existing;
        _titleCtrl.text = existing.title;
        _descCtrl.text  = existing.description ?? '';
        setState(() => _isLoading = false);
        _refreshMapLinks();
      }
      final refreshed = await calProvider.refreshEvent(widget.eventId);
      if (!mounted) return;
      if (refreshed != null) {
        _event = refreshed;
        _titleCtrl.text = refreshed.title;
        _descCtrl.text  = refreshed.description ?? '';
        _refreshMapLinks();
      }
    } catch (e) {
      _error = 'Failed to load event.';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _updateEvent(Map<String, dynamic> patch) async {
    final event = _event;
    final scope = event?.isRecurring == true
        ? await _promptRecurringScope('Apply changes to')
        : null;
    if (event?.isRecurring == true && scope == null) return false;
    if (!mounted) return false;

    final provider = context.read<CalendarProvider>();
    final success  = await provider.updateEvent(widget.eventId, patch, scope: scope);
    if (success) {
      if (scope != null && scope != 'THIS_EVENT' && event != null) {
        await provider.loadEvents(event.calendarId);
      }
      await _loadEvent();
    }
    return success;
  }

  void _deleteEvent() async {
    final event = _event;
    if (event == null) return;

    final provider   = context.read<CalendarProvider>();
    final eventTitle = event.title;

    final scope = event.isRecurring
        ? await _promptRecurringScope('Delete')
        : null;
    if (event.isRecurring && scope == null) return;
    if (!mounted) return;

    if (scope != null && scope != 'THIS_EVENT') {
      try {
        await _repo.deleteRecurringEvent(widget.eventId, scope);
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Deleted "$eventTitle"', style: GoogleFonts.spaceGrotesk(color: _DS.t1)),
          backgroundColor: _DS.bg2,
          duration: const Duration(seconds: 3),
        ));
        // Reload calendar
        provider.loadEvents(event.calendarId);
      } catch (e) {
        if (mounted) _showError('Failed to delete event(s)');
      }
      return;
    }

    provider.deleteEvent(widget.eventId);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Deleted "$eventTitle"', style: GoogleFonts.spaceGrotesk(color: _DS.t1)),
      backgroundColor: _DS.bg2,
      duration: const Duration(seconds: 5),
      action: SnackBarAction(
        label: 'UNDO',
        textColor: _DS.cyan,
        onPressed: () {
          provider.undoDeleteEvent(widget.eventId);
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        },
      ),
    ));
  }


  Future<void> _addGoogleMeet() async {
    setState(() => _isLoading = true);
    try {
      final updated = await _repo.addGoogleMeet(widget.eventId);
      if (!mounted) return;
      context.read<CalendarProvider>().upsertLocalEvent(updated);
      setState(() => _event = updated);
      _refreshMapLinks();
    } catch (e) {
      if (mounted) _showError('Failed to add Google Meet');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addZoom() async {
    setState(() => _isLoading = true);
    try {
      final updated = await _repo.addZoom(widget.eventId);
      if (!mounted) return;
      context.read<CalendarProvider>().upsertLocalEvent(updated);
      setState(() => _event = updated);
      _refreshMapLinks();
    } catch (e) {
      if (mounted) _showError('Failed to add Zoom');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeConference() async {
    final conf = _event?.conference;
    if (conf == null) return;
    final type = conf.isZoom ? 'zoom' : 'meet';
    setState(() => _isLoading = true);
    try {
      final updated = await _repo.removeConference(widget.eventId, type);
      if (!mounted) return;
      context.read<CalendarProvider>().upsertLocalEvent(updated);
      setState(() => _event = updated);
      _refreshMapLinks();
    } catch (e) {
      if (mounted) _showError('Failed to remove conference');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _inviteMember() async {
    final email = await _promptText('Invite Member', '');
    if (email == null || email.trim().isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await _repo.inviteMember(widget.eventId, email.trim());
      await _loadEvent();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invited $email')));
      }
    } catch (e) {
      if (mounted) _showError('Failed to invite member');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeMember(MemberModel member) async {
    final confirmed = await _confirmDialog('Remove member?', 'Remove "${member.email}"?');
    if (confirmed != true) return;
    setState(() => _isLoading = true);
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    try {
      await _repo.deleteMember(memberId: member.id, userId: auth.user?.id ?? '');
      if (!mounted) return;
      await _loadEvent();
    } catch (e) {
      if (mounted) _showError('Failed to remove member');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshMapLinks() async {
    final locId = _event?.location?.id;
    if (locId == null || locId.isEmpty) {
      if (mounted) setState(() { _mapLinks = null; _mapLoading = false; });
      return;
    }
    setState(() => _mapLoading = true);
    try {
      final m = await _repo.getMapLinks(locId);
      if (!mounted) return;
      setState(() { _mapLinks = m; _mapLoading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _mapLinks = null; _mapLoading = false; });
    }
  }

  Future<void> _editTitle() async {
    final next = await _promptText('Edit title', _event?.title ?? '');
    if (next == null || next.trim().isEmpty || next.trim() == _event?.title) return;
    await _updateEvent({'title': next.trim()});
  }

  Future<void> _editDescription() async {
    final next = await _promptText('Edit description', _event?.description ?? '', multiline: true);
    if (next == null || next == _event?.description) return;
    await _updateEvent({'description': next.trim()});
  }

  Future<void> _editType() async {
    final next = await _promptChoice('Select type', EventUi.eventTypeValues, _event?.type ?? 'OTHERS');
    if (next == null || next == _event?.type) return;
    await _updateEvent({'type': next});
  }

  Future<void> _editStatus() async {
    final next = await _promptChoice('Select status', EventUi.statusValues, _event?.status ?? 'NOTSTARTED');
    if (next == null || next == _event?.status) return;
    await _updateEvent({'status': next});
  }

  Future<void> _editTime() async {
    final e = _event;
    if (e == null || e.startDateTime == null) return;
    final startDate = await showDatePicker(
      context: context,
      initialDate: e.startDateTime!,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (ctx, child) => _themedPicker(ctx, child),
    );
    if (!mounted) return;
    if (startDate == null) return;
    final startTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(e.startDateTime!),
      builder: (ctx, child) => _themedPicker(ctx, child),
    );
    if (!mounted) return;
    if (startTime == null) return;
    final endBase = e.endDateTime ?? e.startDateTime!.add(const Duration(hours: 1));
    final endTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(endBase),
      builder: (ctx, child) => _themedPicker(ctx, child),
    );
    if (!mounted) return;
    if (endTime == null) return;
    final start = DateTime(startDate.year, startDate.month, startDate.day, startTime.hour, startTime.minute);
    final end   = DateTime(startDate.year, startDate.month, startDate.day, endTime.hour, endTime.minute);
    if (!end.isAfter(start)) return;
    await _updateEvent({
      'startTime': start.toUtc().toIso8601String(),
      'endTime':   end.toUtc().toIso8601String(),
      'allDay': false,
    });
  }

  Future<void> _editLocation() async {
    final loc  = _event?.location;
    final current = loc?.placeName ?? loc?.displayText ?? '';
    final next = await _promptText('Edit location', current);
    if (next == null || next.trim().isEmpty || next.trim() == current.trim()) return;
    await _updateEvent({'location': {'placeName': next.trim()}});
  }

  Future<void> _openMapsFallback() async {
    final loc = _event?.location;
    if (loc == null) return;
    final q = Uri.encodeComponent(loc.displayText.isNotEmpty ? loc.displayText : (loc.placeName ?? ''));
    if (q.isEmpty) return;
    await _openAnyUrl('https://www.google.com/maps/search/?api=1&query=$q');
  }

  Future<void> _uploadAttachment() async {
    final picked = await FilePicker.platform.pickFiles(withData: false);
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    if (file.path == null) return;
    setState(() => _isLoading = true);
    try {
      await _repo.uploadAttachment(eventId: widget.eventId, filePath: file.path!, fileName: file.name);
      await _loadEvent();
    } catch (e) {
      if (mounted) _showError('Failed to upload: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openAttachment(AttachmentModel a) async {
    try {
      final path   = await _repo.downloadAttachmentToTemp(attachmentId: a.id, fileName: a.title ?? 'attachment.bin');
      final result = await OpenFilex.open(path);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not open file. Saved to: $path',
              style: GoogleFonts.spaceGrotesk(color: _DS.t1)),
          backgroundColor: _DS.bg2,
        ));
      }
    } catch (e) {
      if (mounted) _showError('Failed to download: ${e.toString()}');
    }
  }

  Future<void> _removeAttachment(AttachmentModel a) async {
    final confirmed = await _confirmDialog('Remove attachment?',
        'Remove "${a.title ?? 'this attachment'}"?');
    if (confirmed != true) return;
    try {
      await _repo.deleteAttachment(a.id);
      await _loadEvent();
    } catch (_) {
      if (mounted) _showError('Failed to remove attachment');
    }
  }

  Future<void> _addSubtask() async {
    final text = await _promptText('New subtask', '');
    if (text == null || text.trim().isEmpty) return;
    try {
      await _repo.addSubtask(eventId: widget.eventId, subtaskText: text.trim());
      await _loadEvent();
    } catch (_) {
      if (mounted) _showError('Failed to add subtask');
    }
  }

  Future<void> _removeSubtask(SubtaskModel sub) async {
    if (sub.id == null || sub.id!.isEmpty) return;
    try {
      await _repo.deleteSubtask(widget.eventId, sub.id!);
      await _loadEvent();
    } catch (_) {
      if (mounted) _showError('Failed to remove subtask');
    }
  }

  Future<void> _toggleSubtask(SubtaskModel sub) async {
    if (sub.id == null || sub.id!.isEmpty) return;
    setState(() {
      if (_event != null) {
        final idx = _event!.subtasks.indexWhere((s) => s.id == sub.id);
        if (idx != -1) {
          final updated = List<SubtaskModel>.from(_event!.subtasks);
          updated[idx] = sub.copyWith(isDone: !sub.isDone);
          _event = _event!.copyWithSubtasks(updated);
        }
      }
    });
    try {
      await _repo.updateSubtask(eventId: widget.eventId, subtaskId: sub.id!, isDone: !sub.isDone);
      await _loadEvent();
    } catch (_) {
      await _loadEvent();
    }
  }

  Future<void> _openMeetingLink(String url) async => _openAnyUrl(url);

  Future<void> _openAnyUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    String normalized = url.trim();
    final raw = Uri.tryParse(normalized);
    if (raw != null && raw.scheme.isEmpty && !normalized.contains('://')) {
      normalized = 'https://$normalized';
    } else if (raw != null && raw.scheme.isNotEmpty && raw.scheme != 'http' && raw.scheme != 'https' && raw.scheme != 'zoomus') {
      if (!normalized.contains('://')) {
        normalized = 'https://$normalized';
      }
    }
    
    final uri = Uri.tryParse(normalized);
    if (uri != null) {
      try {
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!launched && uri.scheme == 'zoomus') {
          final confno = uri.queryParameters['confno'];
          final pwd = uri.queryParameters['pwd'];
          if (confno != null) {
            String webUrl = 'https://zoom.us/j/$confno';
            if (pwd != null && pwd.isNotEmpty) webUrl += '?pwd=$pwd';
            await launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
          } else {
            await launchUrl(Uri.parse('https://zoom.us/join'), mode: LaunchMode.externalApplication);
          }
        }
      } catch (e) {
        if (uri.scheme == 'zoomus') {
          final confno = uri.queryParameters['confno'];
          final pwd = uri.queryParameters['pwd'];
          if (confno != null) {
            String webUrl = 'https://zoom.us/j/$confno';
            if (pwd != null && pwd.isNotEmpty) webUrl += '?pwd=$pwd';
            await launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
          } else {
            await launchUrl(Uri.parse('https://zoom.us/join'), mode: LaunchMode.externalApplication);
          }
        }
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.spaceGrotesk(color: _DS.t1)),
      backgroundColor: _DS.error.withValues(alpha: 0.85),
    ));
  }

  // ── reminders ───────────────────────────────
  bool _remindersError = false;

  Future<void> _fetchReminders() async {
    if (!mounted) return;
    setState(() {
      _remindersLoading = true;
      _remindersError = false;
    });
    try {
      final cp = context.read<CalendarProvider>();
      final list = await cp.getRemindersForEvent(widget.eventId);
      if (mounted) setState(() => _reminders = list);
    } catch (_) {
      if (mounted) setState(() => _remindersError = true);
    } finally {
      if (mounted) setState(() => _remindersLoading = false);
    }
  }

  Future<void> _addReminder() async {
    final values = [5, 10, 15, 30, 60, 120, 1440];
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChoiceSheet(
        title: 'Minutes before',
        values: values.map((v) => v.toString()).toList(),
        current: '15',
      ),
    );
    if (!mounted) return;
    if (choice == null) return;
    final mins = int.tryParse(choice) ?? 15;

    final type = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ChoiceSheet(
        title: 'Type',
        values: ['EMAIL', 'PUSH'],
        current: 'EMAIL',
      ),
    );
    if (!mounted) return;
    if (type == null) return;

    setState(() => _isLoading = true);
    try {
      final auth = context.read<AuthProvider>();
      final cp   = context.read<CalendarProvider>();
      final start = _event?.startDateTime;
      if (start == null) return;

      final trigger = start.subtract(Duration(minutes: mins));
      await cp.createReminder({
        'eventId': widget.eventId,
        'userId': auth.user?.id,
        'triggerTime': trigger.toUtc().toIso8601String(),
        'type': type,
      });
      if (!mounted) return;
      await _fetchReminders();
    } catch (e) {
      if (mounted) _showError('Failed to add reminder');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteReminder(String id) async {
    setState(() => _isLoading = true);
    try {
      final cp = context.read<CalendarProvider>();
      await cp.deleteReminder(id);
      await _fetchReminders();
    } catch (_) {
      if (mounted) _showError('Failed to delete reminder');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── dialogs ─────────────────────────────────
  Widget _themedPicker(BuildContext ctx, Widget? child) {
    return Theme(
      data: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(primary: _DS.cyan, surface: _DS.bg2, onSurface: _DS.t1),
      ),
      child: child!,
    );
  }

  Future<String?> _promptText(String title, String initial, {bool multiline = false}) async {
    final ctrl = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _AuroraDialog(
        title: title,
        content: TextField(
          controller: ctrl,
          maxLines: multiline ? 5 : 1,
          autofocus: true,
          style: GoogleFonts.spaceGrotesk(color: _DS.t1, fontSize: 14),
          cursorColor: _DS.cyan,
          decoration: InputDecoration(
            hintText: 'Enter value…',
            hintStyle: GoogleFonts.spaceGrotesk(color: _DS.t3, fontSize: 13),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: _DS.border)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: _DS.cyan, width: 1.5)),
          ),
        ),
        actions: [
          _DialogBtn('Cancel', _DS.t3, () => Navigator.pop(context)),
          _DialogBtn('Save', _DS.cyan, () => Navigator.pop(context, ctrl.text)),
        ],
      ),
    );
    Future.delayed(const Duration(seconds: 1), ctrl.dispose);
    return result;
  }

  Future<String?> _promptChoice(String title, List<String> values, String current) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChoiceSheet(title: title, values: values, current: current),
    );
  }

  Future<String?> _promptRecurringScope(String title) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChoiceSheet(
        title: title,
        values: ['THIS_EVENT', 'ALL_EVENTS'],
        current: 'THIS_EVENT',
      ),
    );
  }

  Future<bool?> _confirmDialog(String title, String body) {
    return showDialog<bool>(
      context: context,
      builder: (_) => _AuroraDialog(
        title: title,
        content: Text(body, style: GoogleFonts.spaceGrotesk(color: _DS.t2, fontSize: 13)),
        actions: [
          _DialogBtn('Cancel', _DS.t3, () => Navigator.pop(context, false)),
          _DialogBtn('Remove', _DS.error, () => Navigator.pop(context, true)),
        ],
      ),
    );
  }

  // ── build ────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _DS.bg1,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: _DS.border, width: 0.5),
      ),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      child: Column(
        children: [
          _buildHandle(),
          Expanded(
            child: _isLoading
                ? _buildLoading()
                : _error != null
                    ? _buildError()
                    : _event == null
                        ? const SizedBox.shrink()
                        : SingleChildScrollView(
                            padding: EdgeInsets.fromLTRB(
                                20, 0, 20, 24 + MediaQuery.of(context).viewInsets.bottom),
                            child: _buildBody(),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    final event = _event;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
      child: Row(
        children: [
          Center(
            child: Container(
              width: 36, height: 3,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_DS.cyan, _DS.indigo]),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Spacer(),
          if (event != null && !_isLoading)
            _GlowIconBtn(
              icon: Icons.delete_outline_rounded,
              color: _DS.rose,
              onTap: _deleteEvent,
            ),
          const SizedBox(width: 4),
          _GlowIconBtn(
            icon: Icons.close_rounded,
            color: _DS.t3,
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() => const Center(
    child: SizedBox(
      width: 32, height: 32,
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation(_DS.cyan),
        strokeWidth: 2,
      ),
    ),
  );

  Widget _buildError() => Center(
    child: Text(_error!, style: GoogleFonts.spaceGrotesk(color: _DS.error, fontSize: 14)),
  );

  Widget _buildBody() {
    final event = _event!;

    // Resolve accent color
    final hex = event.effectiveColor.replaceFirst('#', '');
    Color accent;
    try { accent = Color(int.parse('FF$hex', radix: 16)); }
    catch (_) { accent = _DS.cyan; }

    final loc = event.location;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Glowing color bar ──
        _AuroraBar(color: accent),
        const SizedBox(height: 18),

        // ── Meta row + sync badge ──
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: EventUi.metaRow(event, showStatus: false)),
            if (event.syncStatus != null && event.syncStatus!.isNotEmpty)
              _SyncBadge(label: event.syncStatus!),
          ],
        ),
        const SizedBox(height: 14),

        // ── Title ──
        _EditableTitle(
          text: event.displayTitle,
          onTap: _editTitle,
          accent: accent,
        ),
        const SizedBox(height: 16),

        // ── Time ──
        if (event.startDateTime != null)
          _AuroraInfoChip(
            icon: Icons.schedule_rounded,
            text: event.allDay
                ? 'All day · ${DateFormat('EEE, MMM d').format(event.startDateTime!)}'
                : '${DateFormat('EEE, MMM d · h:mm a').format(event.startDateTime!)}'
                  '${event.endDateTime != null ? '  →  ${DateFormat('h:mm a').format(event.endDateTime!)}' : ''}',
            accent: accent,
            onTap: _editTime,
          ),
        const SizedBox(height: 8),

        // ── Type & Status row ──
        Row(
          children: [
            Expanded(
              child: _AuroraInfoChip(
                icon: Icons.category_outlined,
                text: EventUi.typeLabel(event.type),
                accent: _DS.indigo,
                onTap: _editType,
                label: 'TYPE',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _AuroraInfoChip(
                icon: Icons.flag_rounded,
                text: EventUi.statusLabel(event.status),
                accent: _DS.teal,
                onTap: _editStatus,
                label: 'STATUS',
              ),
            ),
          ],
        ),

        // ── Location ──
        if (loc != null &&
            (loc.displayText.isNotEmpty ||
             (loc.placeName?.isNotEmpty ?? false) ||
             (loc.streetAddress?.isNotEmpty ?? false))) ...[
          const SizedBox(height: 24),
          _SectionLabel('Location', icon: Icons.location_on_outlined, color: _DS.amber),
          const SizedBox(height: 10),
          _LocationCard(
            loc: loc,
            mapLinks: _mapLinks,
            mapLoading: _mapLoading,
            accent: accent,
            onEdit: _editLocation,
            onOpenUrl: _openAnyUrl,
            onFallback: _openMapsFallback,
          ),
        ],

        // ── Description ──
        if (event.description != null && event.description!.isNotEmpty) ...[
          const SizedBox(height: 24),
          const _SectionLabel('Description', icon: Icons.notes_rounded, color: _DS.indigo),
          const SizedBox(height: 10),
          _GlassCard(
            onTap: _editDescription,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(event.description!,
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 13.5, color: _DS.t2, height: 1.65,
                          letterSpacing: 0.1)),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.edit_outlined, size: 13, color: _DS.t3),
              ],
            ),
          ),
        ],

        // ── Conference ──
        const SizedBox(height: 24),
        _SectionRow(
          label: 'Video Conference',
          icon: Icons.video_call_rounded,
          color: _DS.teal,
          action: event.conference == null ? Row(
            children: [
              _AuroraTextBtn(label: '+ Meet', color: const Color(0xFF34A853), onTap: _addGoogleMeet),
              const SizedBox(width: 8),
              _AuroraTextBtn(label: '+ Zoom', color: const Color(0xFF2D8CFF), onTap: _addZoom),
            ]
          ) : const SizedBox.shrink(),
        ),
        const SizedBox(height: 10),
        if (event.conference != null)
          _ConferenceCard(conference: event.conference!, onJoin: _openMeetingLink, onRemove: _removeConference)
        else
          _EmptyHint('No video conference added'),

        // ── Attachments ──
        const SizedBox(height: 24),
        _SectionRow(
          label: 'Attachments',
          icon: Icons.attach_file_rounded,
          color: _DS.indigo,
          count: event.attachments.isNotEmpty ? event.attachments.length : null,
          action: _AuroraTextBtn(label: '+ Add', color: _DS.cyan, onTap: _uploadAttachment),
        ),
        const SizedBox(height: 8),
        if (event.attachments.isEmpty)
          _EmptyHint('No attachments yet')
        else
          ...event.attachments.map((a) => _AttachmentTile(
                attachment: a,
                onOpen: () => _openAttachment(a),
                onDelete: () => _removeAttachment(a),
              )),

        // ── Subtasks ──
        const SizedBox(height: 24),
        _SectionRow(
          label: 'Subtasks',
          icon: Icons.checklist_rounded,
          color: _DS.teal,
          count: event.subtasks.isNotEmpty ? event.subtasks.length : null,
          trailing: event.subtasks.isNotEmpty
              ? Text('${event.subtaskDone}/${event.subtasks.length}',
                    style: GoogleFonts.spaceMono(fontSize: 11, color: _DS.teal,
                        fontWeight: FontWeight.w700))
              : null,
          action: _AuroraTextBtn(label: '+ Add', color: _DS.teal, onTap: _addSubtask),
        ),
        const SizedBox(height: 8),
        if (event.subtasks.isNotEmpty) ...[
          _AuroraProgressBar(value: event.subtaskProgress, color: accent),
          const SizedBox(height: 10),
          ...event.subtasks.map((sub) => _SubtaskItem(
                subtask: sub,
                accent: accent,
                onToggle: () => _toggleSubtask(sub),
                onDelete: () => _removeSubtask(sub),
              )),
        ] else
          _EmptyHint('No subtasks yet'),

        // ── Notes ──
        if (event.notes.isNotEmpty) ...[
          const SizedBox(height: 24),
          const _SectionLabel('Notes', icon: Icons.sticky_note_2_outlined, color: _DS.amber),
          const SizedBox(height: 8),
          ...event.notes.map((note) => _NoteCard(note: note)),
        ],

        // ── Members ──
        const SizedBox(height: 24),
        _SectionRow(
          label: 'Members',
          icon: Icons.group_outlined,
          color: _DS.indigo,
          count: event.members.isNotEmpty ? event.members.length : null,
          action: _AuroraTextBtn(label: '+ Invite', color: _DS.cyan, onTap: _inviteMember),
        ),
        const SizedBox(height: 8),
        if (event.members.isEmpty)
          _EmptyHint('No members yet')
        else
          ...event.members.map((m) => _MemberTile(member: m, onDelete: () => _removeMember(m))),

        // ── Reminders ──
        const SizedBox(height: 24),
        _SectionRow(
          label: 'Reminders',
          icon: Icons.notifications_active_outlined,
          color: _DS.amber,
          count: _reminders.isNotEmpty ? _reminders.length : null,
          action: _AuroraTextBtn(label: '+ Add', color: _DS.amber, onTap: _addReminder),
        ),
        const SizedBox(height: 8),
        if (_remindersLoading)
          _buildLoading()
        else if (_remindersError)
          _EmptyHint('Failed to load. [RETRY]', 
            onTap: _fetchReminders, 
            color: _DS.error.withValues(alpha: 0.7))
        else if (_reminders.isEmpty)
          const _EmptyHint('No reminders set')
        else
          ..._reminders.map((rem) => _ReminderTile(
            reminder: rem,
            onDelete: () => _deleteReminder(rem['id'].toString()),
          )),

        // ── Timestamp ──
        const SizedBox(height: 28),
        Center(
          child: Text(
            'Created ${DateFormat('MMM d, yyyy').format(DateTime.parse(event.createdAt).toLocal())}',
            style: GoogleFonts.spaceMono(fontSize: 10, color: _DS.t3, letterSpacing: 0.8),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Reusable design components
// ─────────────────────────────────────────────

/// Glowing horizontal rule that pulses the event's accent color
class _AuroraBar extends StatelessWidget {
  final Color color;
  const _AuroraBar({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 3,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0), color, color.withOpacity(0.4), color.withOpacity(0)],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ),
        borderRadius: BorderRadius.circular(2),
        boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8, offset: const Offset(0, 2))],
      ),
    );
  }
}

/// Bold display title
class _EditableTitle extends StatelessWidget {
  final String text;
  final Color  accent;
  final VoidCallback onTap;
  const _EditableTitle({required this.text, required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(text,
              style: GoogleFonts.playfairDisplay(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: _DS.t1,
                height: 1.2,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Icon(Icons.edit_outlined, size: 14, color: accent.withOpacity(0.5)),
          ),
        ],
      ),
    );
  }
}

/// Aurora-styled info chip / tappable row
class _AuroraInfoChip extends StatelessWidget {
  final IconData icon;
  final String   text;
  final Color    accent;
  final String?  label;
  final VoidCallback onTap;

  const _AuroraInfoChip({
    required this.icon,
    required this.text,
    required this.accent,
    required this.onTap,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: _DS.bg2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withOpacity(0.18), width: 0.8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (label != null)
                    Text(label!, style: GoogleFonts.spaceMono(
                        fontSize: 8, color: accent.withOpacity(0.6),
                        fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                  Text(text, style: GoogleFonts.spaceGrotesk(
                      fontSize: 13, color: _DS.t1, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 14, color: _DS.t3),
          ],
        ),
      ),
    );
  }
}

/// Glass card with optional tap
class _GlassCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _GlassCard({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: _DS.cyan.withOpacity(0.07),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _DS.bg2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _DS.borderHi, width: 0.6),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Section header with colored dot + label
class _SectionLabel extends StatelessWidget {
  final String  title;
  final IconData icon;
  final Color   color;
  const _SectionLabel(this.title, {required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3, height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 6)],
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 6),
        Text(title, style: GoogleFonts.spaceMono(
            fontSize: 10, fontWeight: FontWeight.w700,
            color: color, letterSpacing: 1.4)),
      ],
    );
  }
}

/// Section row with count badge + action button
class _SectionRow extends StatelessWidget {
  final String    label;
  final IconData  icon;
  final Color     color;
  final int?      count;
  final Widget?   trailing;
  final Widget    action;
  const _SectionRow({
    required this.label, required this.icon, required this.color,
    this.count, this.trailing, required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 16,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2),
              boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 6)])),
        const SizedBox(width: 10),
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.spaceMono(
            fontSize: 10, fontWeight: FontWeight.w700, color: color, letterSpacing: 1.4)),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.25)),
            ),
            child: Text('$count', style: GoogleFonts.spaceMono(
                fontSize: 9, fontWeight: FontWeight.w800, color: color)),
          ),
        ],
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        const Spacer(),
        action,
      ],
    );
  }
}

/// Thin aurora progress bar
class _AuroraProgressBar extends StatelessWidget {
  final double value;
  final Color  color;
  const _AuroraProgressBar({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: 4,
          decoration: BoxDecoration(
            color: _DS.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        FractionallySizedBox(
          widthFactor: value.clamp(0.0, 1.0),
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, _DS.cyan]),
              borderRadius: BorderRadius.circular(2),
              boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 6)],
            ),
          ),
        ),
      ],
    );
  }
}

/// Text action button
class _AuroraTextBtn extends StatelessWidget {
  final String label;
  final Color  color;
  final VoidCallback onTap;
  const _AuroraTextBtn({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Text(label, style: GoogleFonts.spaceMono(
            fontSize: 11, color: color, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

/// Glow icon button for header
class _GlowIconBtn extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final VoidCallback onTap;
  const _GlowIconBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.15)),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

class _SyncBadge extends StatelessWidget {
  final String label;
  const _SyncBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _DS.teal.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _DS.teal.withOpacity(0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.sync_rounded, size: 10, color: _DS.teal),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.spaceMono(
            fontSize: 9, color: _DS.teal, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
      ]),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final Color? color;
  const _EmptyHint(this.text, {this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Text(text,
            style: GoogleFonts.spaceGrotesk(
                fontSize: 13, 
                color: color ?? _DS.tDisabled,
                fontStyle: FontStyle.italic)),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Location card
// ─────────────────────────────────────────────
class _LocationCard extends StatelessWidget {
  final dynamic      loc;
  final Map<String, dynamic>? mapLinks;
  final bool         mapLoading;
  final Color        accent;
  final VoidCallback onEdit;
  final VoidCallback onFallback;
  final Function(String?) onOpenUrl;

  const _LocationCard({
    required this.loc, required this.mapLinks, required this.mapLoading,
    required this.accent, required this.onEdit, required this.onFallback,
    required this.onOpenUrl,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onEdit,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _DS.bg2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _DS.amber.withOpacity(0.18), width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.location_on_rounded, size: 15, color: _DS.amber),
              const SizedBox(width: 8),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (loc.placeName != null && (loc.placeName as String).isNotEmpty)
                    Text(loc.placeName as String,
                        style: GoogleFonts.playfairDisplay(
                            fontSize: 15, fontWeight: FontWeight.w600, color: _DS.t1)),
                  if ((loc.displayText as String).isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(loc.displayText as String,
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 12, color: _DS.t2, height: 1.4)),
                  ],
                ],
              )),
              Icon(Icons.edit_outlined, size: 13, color: _DS.t3),
            ]),
            if (loc.buildingName != null || loc.floor != null || loc.room != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  [
                    if (loc.buildingName != null && (loc.buildingName as String).isNotEmpty) loc.buildingName,
                    if (loc.floor != null && (loc.floor as String).isNotEmpty) 'Floor ${loc.floor}',
                    if (loc.room != null && (loc.room as String).isNotEmpty) 'Room ${loc.room}',
                  ].whereType<String>().join(' · '),
                  style: GoogleFonts.spaceMono(fontSize: 10, color: _DS.t3),
                ),
              ),
            const SizedBox(height: 14),
            if (mapLoading)
              Row(children: [
                const SizedBox(width: 12, height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: _DS.amber)),
                const SizedBox(width: 8),
                Text('Loading maps…', style: GoogleFonts.spaceMono(fontSize: 11, color: _DS.t3)),
              ])
            else
              Builder(builder: (ctx) {
                final links  = mapLinks;
                final hasLinks = links != null &&
                    ['googleMaps', 'yandexMaps', 'app'].any(
                        (k) => links[k] != null && links[k].toString().isNotEmpty);
                return Wrap(spacing: 8, runSpacing: 8, children: [
                  if (hasLinks) ...[
                    if (links['googleMaps']?.toString().isNotEmpty ?? false)
                      _MapChip('Google Maps', Icons.map_rounded, const Color(0xFF4285F4),
                          () => onOpenUrl(links['googleMaps']?.toString())),
                    if (links['yandexMaps']?.toString().isNotEmpty ?? false)
                      _MapChip('Yandex', Icons.map_outlined, const Color(0xFFFF3333),
                          () => onOpenUrl(links['yandexMaps']?.toString())),
                    if (links['app']?.toString().isNotEmpty ?? false)
                      _MapChip('Open in App', Icons.navigation_rounded, _DS.teal,
                          () => onOpenUrl(links['app']?.toString())),
                  ] else
                    _MapChip('Open in Maps', Icons.map_rounded, accent, onFallback),
                ]);
              }),
          ],
        ),
      ),
    );
  }
}

class _MapChip extends StatelessWidget {
  final String    label;
  final IconData  icon;
  final Color     color;
  final VoidCallback onTap;
  const _MapChip(this.label, this.icon, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3), width: 0.8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.spaceGrotesk(
              fontSize: 12, fontWeight: FontWeight.w600, color: _DS.t1)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Conference card
// ─────────────────────────────────────────────
class _ConferenceCard extends StatelessWidget {
  final ConferenceModel     conference;
  final Function(String)    onJoin;
  final VoidCallback        onRemove;
  const _ConferenceCard({required this.conference, required this.onJoin, required this.onRemove});

  String _joinUrl() {
    final isMeet = conference.isGoogleMeet;
    final raw = conference.meetingLink?.trim() ?? '';
    final code = conference.meetingCode?.trim() ?? '';
    final pwd = conference.conferencePassword?.trim() ?? '';

    if (!isMeet) {
      String? confno;
      String? pass = pwd.isNotEmpty ? pwd : null;

      if (code.isNotEmpty) {
        confno = code.replaceAll(RegExp(r'[^0-9]'), '');
      }

      if (confno == null || confno.isEmpty) {
        if (raw.isNotEmpty) {
          final uri = Uri.tryParse(raw.startsWith('http') ? raw : 'https://$raw');
          if (uri != null) {
            if (uri.pathSegments.contains('j')) {
              final idx = uri.pathSegments.indexOf('j');
              if (idx + 1 < uri.pathSegments.length) {
                confno = uri.pathSegments[idx + 1];
              }
            } else if (uri.pathSegments.isNotEmpty && RegExp(r'^\d+$').hasMatch(uri.pathSegments.last)) {
              confno = uri.pathSegments.last;
            }
            pass ??= uri.queryParameters['pwd'];
          }
        }
      }

      if (confno != null && confno.isNotEmpty) {
        String zoomUri = 'zoomus://zoom.us/join?action=join&confno=$confno';
        if (pass != null && pass.isNotEmpty) {
          zoomUri += '&pwd=$pass';
        }
        return zoomUri;
      }
      return 'zoomus://zoom.us/join';
    }

    if (raw.isNotEmpty) {
      final lower = raw.toLowerCase();
      if (lower.startsWith('http://') || lower.startsWith('https://')) {
        return raw;
      }
      if (lower.contains('meet.google.com')) {
        return 'https://$raw';
      }
    }

    if (code.isNotEmpty) {
      final meetCode = code.replaceAll(' ', '');
      return 'https://meet.google.com/$meetCode';
    }

    return 'https://meet.google.com';
  }

  @override
  Widget build(BuildContext context) {
    final isMeet  = conference.isGoogleMeet;
    final color   = isMeet ? const Color(0xFF34A853) : const Color(0xFF2D8CFF);
    final joinUrl = _joinUrl();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onJoin(joinUrl),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.12), color.withOpacity(0.03)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(isMeet ? Icons.videocam_rounded : Icons.video_call_rounded,
                  color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isMeet ? 'Google Meet' : 'Zoom',
                  style: GoogleFonts.playfairDisplay(
                      color: color, fontWeight: FontWeight.w700, fontSize: 15)),
              if (conference.meetingCode != null)
                Text('Code: ${conference.meetingCode}',
                    style: GoogleFonts.spaceMono(color: _DS.t2, fontSize: 11)),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Tap card to open meeting',
                  style: GoogleFonts.spaceMono(color: _DS.t3, fontSize: 10),
                ),
              ),
            ])),
            GestureDetector(
              onTap: () => onJoin(joinUrl),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Text('Join', style: GoogleFonts.spaceGrotesk(
                    color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ),
            const SizedBox(width: 8),
            _GlowIconBtn(icon: Icons.delete_outline_rounded, color: _DS.rose, onTap: onRemove),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Attachment tile
// ─────────────────────────────────────────────
class _AttachmentTile extends StatelessWidget {
  final AttachmentModel attachment;
  final VoidCallback    onOpen;
  final VoidCallback    onDelete;
  const _AttachmentTile({required this.attachment, required this.onOpen, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final name = attachment.title ?? 'Attachment';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _DS.bg2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _DS.borderHi, width: 0.6),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: _DS.indigo.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _DS.indigo.withOpacity(0.25)),
                ),
                alignment: Alignment.center,
                child: Text(attachment.ext,
                    style: GoogleFonts.spaceMono(
                        fontSize: 9, fontWeight: FontWeight.w800, color: _DS.indigo)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 13, color: _DS.t1, fontWeight: FontWeight.w600)),
                if (attachment.fileSize != null)
                  Text(_fmt(attachment.fileSize!),
                      style: GoogleFonts.spaceMono(fontSize: 10, color: _DS.t3)),
              ])),
              _GlowIconBtn(icon: Icons.download_rounded, color: _DS.cyan, onTap: onOpen),
              const SizedBox(width: 2),
              _GlowIconBtn(icon: Icons.delete_outline_rounded, color: _DS.rose, onTap: onDelete),
            ]),
          ),
        ),
      ),
    );
  }

  String _fmt(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ─────────────────────────────────────────────
//  Subtask item
// ─────────────────────────────────────────────
class _SubtaskItem extends StatelessWidget {
  final SubtaskModel subtask;
  final Color        accent;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  const _SubtaskItem({required this.subtask, required this.accent,
      required this.onToggle, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final done = subtask.isDone;
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      decoration: BoxDecoration(
        color: done ? accent.withOpacity(0.06) : _DS.bg2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: done ? accent.withOpacity(0.25) : _DS.border,
          width: 0.8,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 20, height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? accent : Colors.transparent,
                  border: Border.all(
                      color: done ? accent : _DS.t3, width: 1.5),
                  boxShadow: done
                      ? [BoxShadow(color: accent.withOpacity(0.35), blurRadius: 8)]
                      : null,
                ),
                child: done
                    ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(
                subtask.subtask,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  color: done ? _DS.t3 : _DS.t1,
                  decoration: done ? TextDecoration.lineThrough : null,
                  decorationColor: _DS.t3,
                ),
              )),
              GestureDetector(
                onTap: onDelete,
                child: const Icon(Icons.close_rounded, size: 15, color: _DS.t3),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Note card
// ─────────────────────────────────────────────
class _NoteCard extends StatelessWidget {
  final dynamic note;
  const _NoteCard({required this.note});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _DS.bg2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _DS.borderHi, width: 0.6),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Container(width: 3, color: _DS.amber),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(note.content,
                      style: GoogleFonts.spaceGrotesk(color: _DS.t2, fontSize: 13, height: 1.55)),
                  const SizedBox(height: 6),
                  Text(DateFormat('MMM d, yyyy').format(DateTime.parse(note.createdAt).toLocal()),
                      style: GoogleFonts.spaceMono(color: _DS.t3, fontSize: 10)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Member tile
// ─────────────────────────────────────────────
class _MemberTile extends StatelessWidget {
  final dynamic member;
  final VoidCallback onDelete;
  const _MemberTile({required this.member, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _DS.bg2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _DS.border, width: 0.6),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [_DS.indigo, _DS.cyan], begin: Alignment.topLeft, end: Alignment.bottomRight),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: _DS.indigo.withOpacity(0.3), blurRadius: 8)],
          ),
          alignment: Alignment.center,
          child: Text(member.initial as String,
              style: GoogleFonts.playfairDisplay(
                  color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(member.displayName as String,
              style: GoogleFonts.spaceGrotesk(
                  color: _DS.t1, fontSize: 13, fontWeight: FontWeight.w600)),
          Text(member.email as String,
              style: GoogleFonts.spaceMono(color: _DS.t3, fontSize: 10)),
        ])),
        if (member.isOwner as bool)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_DS.cyan, _DS.indigo]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('OWNER', style: GoogleFonts.spaceMono(
                color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
          )
        else
          _GlowIconBtn(icon: Icons.delete_outline_rounded, color: _DS.rose, onTap: onDelete),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
//  Reminder tile
// ─────────────────────────────────────────────
class _ReminderTile extends StatelessWidget {
  final dynamic reminder;
  final VoidCallback onDelete;
  const _ReminderTile({required this.reminder, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final type = reminder['type']?.toString().toUpperCase() ?? 'EMAIL';
    final triggerStr = reminder['triggerTime']?.toString() ?? '';
    final trigger = DateTime.tryParse(triggerStr)?.toLocal();
    final timeStr = trigger != null ? DateFormat('MMM d, h:mm a').format(trigger) : '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _DS.bg2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _DS.border, width: 0.6),
      ),
      child: Row(children: [
        Icon(
          type == 'EMAIL' ? Icons.email_outlined : Icons.notifications_none_rounded,
          size: 16, color: _DS.amber,
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(type, style: GoogleFonts.spaceMono(fontSize: 10, fontWeight: FontWeight.w700, color: _DS.t1)),
          Text(timeStr, style: GoogleFonts.spaceGrotesk(fontSize: 12, color: _DS.t2)),
        ])),
        _GlowIconBtn(icon: Icons.delete_outline_rounded, color: _DS.rose, onTap: onDelete),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
//  Dialog helpers
// ─────────────────────────────────────────────
class _AuroraDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget> actions;
  const _AuroraDialog({required this.title, required this.content, required this.actions});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _DS.bg2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: _DS.borderHi, width: 0.8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShaderMask(
              shaderCallback: (b) => _DS.auroraA.createShader(b),
              child: Text(title,
                  style: GoogleFonts.playfairDisplay(
                      fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
            const SizedBox(height: 16),
            content,
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
          ],
        ),
      ),
    );
  }
}

class _DialogBtn extends StatelessWidget {
  final String label;
  final Color  color;
  final VoidCallback onTap;
  const _DialogBtn(this.label, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Text(label, style: GoogleFonts.spaceGrotesk(
            color: color, fontWeight: FontWeight.w700, fontSize: 14)),
      ),
    );
  }
}

class _ChoiceSheet extends StatelessWidget {
  final String       title;
  final List<String> values;
  final String       current;
  const _ChoiceSheet({required this.title, required this.values, required this.current});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _DS.bg2,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: _DS.borderHi, width: 0.8),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 32, height: 3,
                decoration: BoxDecoration(color: _DS.borderHi, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            ShaderMask(
              shaderCallback: (b) => _DS.auroraA.createShader(b),
              child: Text(title,
                  style: GoogleFonts.playfairDisplay(
                      fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: values.map((v) {
                    final isSelected = v == current;
                    final label = switch (v) {
                      'THIS_EVENT' => 'Only this event',
                      'ALL_EVENTS' => 'All events',
                      'THIS_AND_FOLLOWING' => 'This and following',
                      _ => title.toLowerCase().contains('status')
                          ? EventUi.statusLabel(v)
                          : EventUi.typeLabel(v),
                    };
                    return ListTile(
                      title: Text(label, style: GoogleFonts.spaceGrotesk(
                          color: isSelected ? _DS.cyan : _DS.t1,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                          fontSize: 14)),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded, color: _DS.cyan, size: 18)
                          : null,
                      onTap: () => Navigator.pop(context, v),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
