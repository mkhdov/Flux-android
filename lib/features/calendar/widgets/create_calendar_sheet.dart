import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/calendar_provider.dart';
import '../../../core/constants/app_colors.dart';

class CreateCalendarSheet extends StatefulWidget {
  final String userId;
  const CreateCalendarSheet({super.key, required this.userId});

  @override
  State<CreateCalendarSheet> createState() => _CreateCalendarSheetState();
}

class _CreateCalendarSheetState extends State<CreateCalendarSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedColor = '#6366F1';
  bool _isPrimary = false;
  bool _isLoading = false;
  String? _error;

  static const _colors = [
    '#6366F1', '#EC4899', '#F59E0B', '#10B981',
    '#3B82F6', '#EF4444', '#8B5CF6', '#14B8A6',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty) {
      setState(() => _error = 'Calendar name is required.');
      return;
    }
    setState(() { _isLoading = true; _error = null; });
    final provider = context.read<CalendarProvider>();
    final result = await provider.createCalendar(
      userId: widget.userId,
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      colorHex: _selectedColor,
      timezone: DateTime.now().timeZoneName,
      isPrimary: _isPrimary,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result != null) {
      Navigator.pop(context);
    } else {
      setState(() => _error = 'Failed to create calendar. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetWrapper(
      title: 'New Calendar',
      icon: Icons.calendar_month,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('Calendar Name *'),
          const SizedBox(height: 6),
          _textField(_titleController, 'e.g. Work, Personal'),
          const SizedBox(height: 16),
          _fieldLabel('Description'),
          const SizedBox(height: 6),
          _textField(_descController, 'Optional description', maxLines: 2),
          const SizedBox(height: 16),
          _fieldLabel('Color'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            children: _colors.map((hex) {
              final colorVal = Color(int.parse('FF${hex.substring(1)}', radix: 16));
              final isSelected = _selectedColor == hex;
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = hex),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: colorVal,
                    shape: BoxShape.circle,
                    border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
                    boxShadow: isSelected ? [BoxShadow(color: colorVal.withValues(alpha: 0.5), blurRadius: 8)] : null,
                  ),
                  child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Switch(
                value: _isPrimary,
                onChanged: (v) => setState(() => _isPrimary = v),
                activeThumbColor: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text('Set as primary calendar', style: GoogleFonts.roboto(color: AppColors.textSecondary, fontSize: 14)),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: GoogleFonts.roboto(color: AppColors.error, fontSize: 13)),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(12)),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                    : Text('Create Calendar', style: GoogleFonts.roboto(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared Widgets ────────────────────────────────────────────────────────────

class _SheetWrapper extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SheetWrapper({required this.title, required this.icon, required this.child});

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
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFF3A3A3C), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            // Header
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Text(title, style: GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

Widget _fieldLabel(String label) => Padding(
  padding: const EdgeInsets.only(bottom: 0),
  child: Text(label, style: GoogleFonts.roboto(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
);

Widget _textField(TextEditingController ctrl, String hint, {int maxLines = 1}) => TextField(
  controller: ctrl,
  maxLines: maxLines,
  style: GoogleFonts.roboto(color: AppColors.textPrimary, fontSize: 14),
  decoration: InputDecoration(
    hintText: hint,
    hintStyle: GoogleFonts.roboto(color: AppColors.textDisabled, fontSize: 14),
    filled: true,
    fillColor: const Color(0xFF2A2A2C),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  ),
);
