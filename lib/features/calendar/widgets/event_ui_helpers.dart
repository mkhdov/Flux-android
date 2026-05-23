import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/event_model.dart';
import '../../../core/constants/app_colors.dart';

/// Labels and chips aligned with Flux-web `EventDetailDrawer` conventions.
abstract final class EventUi {
  static const List<String> eventTypeValues = [
    'OTHERS', 'MEETING', 'WORK', 'TASK', 'REMINDER', 'STUDY',
    'APPOINTMENT', 'BIRTHDAY', 'HOLIDAY', 'ROUTE',
  ];

  static const List<String> statusValues = [
    'NOTSTARTED', 'COMPLETED', 'CANCELLED', 'POSTPONED',
  ];

  static String typeLabel(String? raw) {
    if (raw == null || raw.isEmpty) return 'Other';
    final u = raw.toUpperCase();
    switch (u) {
      case 'MEETING': return 'Meeting';
      case 'WORK': return 'Work';
      case 'TASK': return 'Task';
      case 'REMINDER': return 'Reminder';
      case 'STUDY': return 'Study';
      case 'APPOINTMENT': return 'Appointment';
      case 'BIRTHDAY': return 'Birthday';
      case 'HOLIDAY': return 'Holiday';
      case 'ROUTE': return 'Route';
      case 'OTHERS': return 'Other';
      default: return raw.replaceAll('_', ' ');
    }
  }

  static String statusLabel(String? raw) {
    final u = (raw ?? 'NOTSTARTED').toUpperCase();
    switch (u) {
      case 'NOTSTARTED': return 'Not started';
      case 'COMPLETED': return 'Completed';
      case 'CANCELLED': return 'Cancelled';
      case 'POSTPONED': return 'Postponed';
      default: return u.replaceAll('_', ' ');
    }
  }

  static Color statusAccent(String? raw) {
    final u = (raw ?? 'NOTSTARTED').toUpperCase();
    switch (u) {
      case 'COMPLETED': return const Color(0xFF22C55E); // Green
      case 'CANCELLED': return const Color(0xFFEF4444); // Red
      case 'POSTPONED': return const Color(0xFFF59E0B); // Orange/Warning
      case 'NOTSTARTED':
      default: return const Color(0xFF94A3B8); // Grey (Slate 400)
    }
  }

  /// Compact row: icons for location / attachments / subtasks (removed status chip to save space).
  static Widget dailyFooter(EventModel e, {double iconSize = 12}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (e.hasLocation)
          _tinyIcon(Icons.place_outlined, AppColors.textMuted, iconSize, 'Location'),
        if (e.hasConference)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: _tinyIcon(Icons.video_call_rounded, AppColors.textMuted, iconSize, 'Conference'),
          ),
        if (e.hasAttachments)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: _tinyIcon(Icons.attach_file_rounded, AppColors.textMuted, iconSize, 'Attachments'),
          ),
        if (e.hasSubtasks)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: _tinyIcon(Icons.checklist_rounded, AppColors.textMuted, iconSize, 'Subtasks'),
          ),
      ],
    );
  }

  static Widget statusDot(String? status, {double size = 7}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: statusAccent(status),
        shape: BoxShape.circle,
      ),
    );
  }

  static Widget metaRow(
    EventModel e, {
    bool showStatus = true,
    double iconSize = 14,
  }) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (showStatus)
          statusChip(e.status),
        if (e.type != null && e.type!.isNotEmpty)
          typeChip(e.type!, e.effectiveColor),
        if (e.hasLocation)
          _tinyIcon(Icons.place_outlined, AppColors.textMuted, iconSize, 'Location'),
        if (e.hasConference)
          _tinyIcon(Icons.video_call_rounded, AppColors.textMuted, iconSize, 'Conference'),
        if (e.hasAttachments)
          _tinyIcon(Icons.attach_file_rounded, AppColors.textMuted, iconSize, 'Attachments'),
        if (e.hasSubtasks)
          _tinyIcon(Icons.checklist_rounded, AppColors.textMuted, iconSize, 'Subtasks'),
      ],
    );
  }

  static Widget statusChip(String? status) {
    final c = statusAccent(status);
    final label = statusLabel(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withOpacity(0.35)),
      ),
      child: Text(
        label,
        style: GoogleFonts.roboto(fontSize: 10, fontWeight: FontWeight.w700, color: c, height: 1.1),
      ),
    );
  }

  static Widget typeChip(String type, String colorHex) {
    Color c;
    try {
      final h = colorHex.replaceFirst('#', '');
      c = Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      c = AppColors.primary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withOpacity(0.35)),
      ),
      child: Text(
        typeLabel(type),
        style: GoogleFonts.roboto(fontSize: 10, fontWeight: FontWeight.w700, color: c, height: 1.1),
      ),
    );
  }

  static Widget _tinyIcon(IconData icon, Color color, double size, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: Icon(icon, size: size, color: color),
    );
  }
}
