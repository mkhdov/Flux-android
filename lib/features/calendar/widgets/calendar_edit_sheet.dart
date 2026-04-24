import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/calendar_provider.dart';
import '../models/calendar_model.dart';
import '../../../core/constants/app_colors.dart';

class CalendarEditSheet extends StatefulWidget {
  final CalendarModel calendar;
  final String userId;

  const CalendarEditSheet({super.key, required this.calendar, required this.userId});

  @override
  State<CalendarEditSheet> createState() => _CalendarEditSheetState();
}

class _CalendarEditSheetState extends State<CalendarEditSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  String _selectedColor = '#6366F1';
  bool _isLoading = false;
  bool _showDeleteConfirm = false;
  bool _deleteLoading = false;
  String? _error;

  static const _colors = [
    '#6366F1', '#EC4899', '#F59E0B', '#10B981',
    '#3B82F6', '#EF4444', '#8B5CF6', '#14B8A6',
  ];

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.calendar.title);
    _descCtrl = TextEditingController(text: widget.calendar.description);
    _selectedColor = widget.calendar.colorHex;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Calendar name is required.');
      return;
    }
    setState(() { _isLoading = true; _error = null; });
    final provider = context.read<CalendarProvider>();
    final success = await provider.updateCalendar(
      id: widget.calendar.id,
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      colorHex: _selectedColor,
      timezone: widget.calendar.timezone,
      userId: widget.userId,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (success) {
      Navigator.pop(context);
    } else {
      setState(() => _error = 'Failed to update calendar.');
    }
  }

  Future<void> _setAsPrimary() async {
    setState(() => _isLoading = true);
    final provider = context.read<CalendarProvider>();
    await provider.setPrimaryCalendar(widget.calendar.id, widget.userId);
    if (!mounted) return;
    setState(() => _isLoading = false);
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    setState(() => _deleteLoading = true);
    final provider = context.read<CalendarProvider>();
    final success = await provider.deleteCalendar(calendarId: widget.calendar.id, userId: widget.userId);
    if (!mounted) return;
    setState(() => _deleteLoading = false);
    if (success) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFF3A3A3C), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('Edit Calendar', style: GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 20),

            // Title
            _label('Calendar Name'),
            const SizedBox(height: 6),
            _textField(_titleCtrl, 'Calendar name'),
            const SizedBox(height: 14),

            // Description
            _label('Description'),
            const SizedBox(height: 6),
            _textField(_descCtrl, 'Optional description', maxLines: 2),
            const SizedBox(height: 14),

            // Colors
            _label('Color'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: _colors.map((hex) {
                final colorVal = Color(int.parse('FF${hex.substring(1)}', radix: 16));
                final isSelected = _selectedColor == hex;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = hex),
                  child: Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: colorVal, shape: BoxShape.circle,
                      border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
                    ),
                    child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                  ),
                );
              }).toList(),
            ),

            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: GoogleFonts.roboto(color: AppColors.error, fontSize: 13)),
            ],
            const SizedBox(height: 20),

            // Actions
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading ? null : _setAsPrimary,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text('Set Primary', style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(10)),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                        : Text('Save', style: GoogleFonts.roboto(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 10),

            if (!_showDeleteConfirm)
              TextButton.icon(
                onPressed: () => setState(() => _showDeleteConfirm = true),
                icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 18),
                label: Text('Delete Calendar', style: GoogleFonts.roboto(color: AppColors.error)),
              )
            else
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Text('This will permanently delete the calendar and all events. Are you sure?',
                        style: GoogleFonts.roboto(color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => setState(() => _showDeleteConfirm = false),
                          child: Text('Cancel', style: GoogleFonts.roboto(color: AppColors.textMuted)),
                        ),
                      ),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _deleteLoading ? null : _delete,
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
                          child: _deleteLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                              : Text('Yes, Delete', style: GoogleFonts.roboto(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text, style: GoogleFonts.roboto(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary));

  Widget _textField(TextEditingController ctrl, String hint, {int maxLines = 1}) => TextField(
    controller: ctrl,
    maxLines: maxLines,
    style: GoogleFonts.roboto(color: AppColors.textPrimary, fontSize: 14),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.roboto(color: AppColors.textDisabled),
      filled: true,
      fillColor: const Color(0xFF2A2A2C),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
  );
}
