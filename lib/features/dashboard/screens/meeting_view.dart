import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../calendar/providers/calendar_provider.dart';
import '../../calendar/models/event_model.dart';
import '../../../core/constants/app_colors.dart';
import '../../calendar/widgets/event_detail_sheet.dart';

class MeetingView extends StatefulWidget {
  const MeetingView({super.key});

  @override
  State<MeetingView> createState() => _MeetingViewState();
}

class _MeetingViewState extends State<MeetingView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final calProvider = context.read<CalendarProvider>();
      if (calProvider.selectedCalendar != null) {
        calProvider.loadMeetings(calProvider.selectedCalendar!.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final calProvider = context.watch<CalendarProvider>();
    final meetings = calProvider.meetings;
    final isLoading = calProvider.isLoadingMeetings;

    return Column(
      children: [
        _buildTabs(calProvider),
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : meetings.isEmpty
                  ? _buildEmptyState(calProvider.meetingsFilter)
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: meetings.length,
                      itemBuilder: (context, index) {
                        return _MeetingCard(meeting: meetings[index]);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildTabs(CalendarProvider calProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          _TabButton(
            label: 'Today',
            isActive: calProvider.meetingsFilter == 'today',
            onTap: () => calProvider.loadMeetings(calProvider.selectedCalendar!.id, filter: 'today'),
          ),
          const SizedBox(width: 8),
          _TabButton(
            label: 'Upcoming',
            isActive: calProvider.meetingsFilter == 'upcoming',
            onTap: () => calProvider.loadMeetings(calProvider.selectedCalendar!.id, filter: 'upcoming'),
          ),
          const SizedBox(width: 8),
          _TabButton(
            label: 'Past',
            isActive: calProvider.meetingsFilter == 'past',
            onTap: () => calProvider.loadMeetings(calProvider.selectedCalendar!.id, filter: 'past'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String filter) {
    String message = 'No meetings for today';
    if (filter == 'upcoming') message = 'No upcoming meetings';
    if (filter == 'past') message = 'No past meetings';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.video_camera_back_outlined, size: 64, color: Colors.grey.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.roboto(
              fontSize: 16,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.primary.withOpacity(0.5) : Colors.grey.withOpacity(0.2),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.roboto(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive ? AppColors.primary : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _MeetingCard extends StatelessWidget {
  final EventModel meeting;

  const _MeetingCard({required this.meeting});

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(meeting.colorHex);
    final startTime = meeting.startDateTime != null ? DateFormat('h:mm a').format(meeting.startDateTime!) : '';
    final endTime = meeting.endDateTime != null ? DateFormat('h:mm a').format(meeting.endDateTime!) : '';
    final date = meeting.startDateTime != null ? DateFormat('EEE, MMM d').format(meeting.startDateTime!) : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: InkWell(
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => EventDetailSheet(eventId: meeting.id),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              meeting.title,
                              style: GoogleFonts.roboto(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _buildStatusBadge(meeting.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 14, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            '$date  •  $startTime - $endTime',
                            style: GoogleFonts.roboto(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      if (meeting.meetingLink != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.videocam_outlined, size: 14, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              meeting.meetingPlatform ?? 'Video Call',
                              style: GoogleFonts.roboto(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
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
      ),
    );
  }

  Widget _buildStatusBadge(String? status) {
    Color color = Colors.grey;
    String label = status ?? 'Upcoming';

    switch (status?.toUpperCase()) {
      case 'COMPLETED':
        color = Colors.green;
        label = 'Completed';
        break;
      case 'CANCELLED':
        color = Colors.red;
        label = 'Cancelled';
        break;
      case 'POSTPONED':
        color = Colors.orange;
        label = 'Postponed';
        break;
      default:
        color = AppColors.primary;
        label = 'Upcoming';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.roboto(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Color _parseColor(String? colorHex) {
    if (colorHex == null || colorHex.isEmpty) return AppColors.primary;
    try {
      String hex = colorHex.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }
}
