import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/models/user_model.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDarkMode = true;
  bool _isLinkingGoogle = false;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['https://www.googleapis.com/auth/calendar'],
    serverClientId: kGoogleWebClientId, // Make sure you configure this!
    forceCodeForRefreshToken: true,
  );

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1C1E),
        elevation: 0,
        title: Text(
          'Settings',
          style: GoogleFonts.roboto(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textSecondary),
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _buildBody(context, user, auth),
    );
  }

  Widget _buildBody(BuildContext context, UserModel user, AuthProvider auth) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Profile Card ──────────────────────────────────────────
          _ProfileCard(user: user, onRefresh: () => setState(() {})),

          const SizedBox(height: 24),

          // ── Account Linking ───────────────────────────────────────
          _SectionHeader(title: 'Connected Accounts'),
          const SizedBox(height: 12),
          _AccountLinkCard(
            icon: _googleIcon(),
            title: 'Google Account',
            subtitle: 'Sync calendar & contacts',
            buttonLabel: _isLinkingGoogle ? 'Loading...' : 'Connect',
            buttonColor: const Color(0xFF4285F4),
            onTap: _isLinkingGoogle ? () {} : () => _linkGoogleNative(user.id),
          ),
          const SizedBox(height: 10),
          _AccountLinkCard(
            icon: _zoomIcon(),
            title: 'Zoom',
            subtitle: 'Schedule & join meetings',
            buttonLabel: 'Connect',
            buttonColor: const Color(0xFF2D8CFF),
            onTap: () => _linkZoom(user.id),
          ),

          const SizedBox(height: 24),

          // ── Appearance ────────────────────────────────────────────
          _SectionHeader(title: 'Appearance'),
          const SizedBox(height: 12),
          _SettingsCard(
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A40),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.dark_mode_rounded, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dark Mode',
                        style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                      ),
                      Text(
                        'Switch between light and dark theme',
                        style: GoogleFonts.roboto(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isDarkMode,
                  onChanged: (v) => setState(() => _isDarkMode = v),
                  activeColor: AppColors.primary,
                  activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
                  inactiveThumbColor: AppColors.textMuted,
                  inactiveTrackColor: const Color(0xFF2D2D2D),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          _SettingsCard(
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A3540),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.notifications_outlined, color: Color(0xFF3B82F6), size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notifications',
                        style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                      ),
                      Text(
                        'Manage push notification preferences',
                        style: GoogleFonts.roboto(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
              ],
            ),
          ),

          const SizedBox(height: 10),

          _SettingsCard(
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A3A2A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.language_rounded, color: Color(0xFF22C55E), size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Language & Region',
                        style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                      ),
                      Text(
                        'English (US)',
                        style: GoogleFonts.roboto(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Privacy & Security ────────────────────────────────────
          _SectionHeader(title: 'Privacy & Security'),
          const SizedBox(height: 12),
          _SettingsCard(
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A2A2A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.lock_outline_rounded, color: Color(0xFFF59E0B), size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Change Password',
                        style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                      ),
                      Text(
                        'Update your account password',
                        style: GoogleFonts.roboto(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
              ],
            ),
          ),

          const SizedBox(height: 10),

          _SettingsCard(
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.info_outline_rounded, color: AppColors.textSecondary, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'About Flux',
                        style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                      ),
                      Text(
                        'Version 1.0.0',
                        style: GoogleFonts.roboto(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ── Danger Zone ───────────────────────────────────────────
          _SectionHeader(title: 'Danger Zone', danger: true),
          const SizedBox(height: 12),
          _DangerZone(userId: user.id, auth: auth),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<void> _linkGoogleNative(String userId) async {
    setState(() => _isLinkingGoogle = true);
    try {
      if (kGoogleWebClientId == 'YOUR_GOOGLE_WEB_CLIENT_ID') {
        throw Exception('Please configure kGoogleWebClientId in api_constants.dart');
      }

      await _googleSignIn.signOut(); // Ensure fresh start
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      
      if (account == null) {
        setState(() => _isLinkingGoogle = false);
        return; // User canceled
      }

      if (account.serverAuthCode == null) {
        throw Exception('Failed to get serverAuthCode from Google');
      }

      // Send to backend
      final api = ApiClient.instance;
      await api.post('/api/auth/google/mobile-link?userId=$userId', data: {
        'serverAuthCode': account.serverAuthCode,
        'email': account.email,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully linked Google account!'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to link Google: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLinkingGoogle = false);
    }
  }

  Future<void> _linkZoom(String userId) async {
    final uri = Uri.parse('http://192.168.1.17/zoom/connect/$userId');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Zoom auth link')),
        );
      }
    }
  }

  Widget _googleIcon() => Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF1A2A4A),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(7),
        child: CustomPaint(painter: _GoogleLogoPainter()),
      );

  Widget _zoomIcon() => Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF1A2D4A),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Icon(Icons.video_call_rounded, color: Color(0xFF2D8CFF), size: 20),
        ),
      );
}

// ─── Profile Card ────────────────────────────────────────────────────────────

class _ProfileCard extends StatefulWidget {
  final UserModel user;
  final VoidCallback onRefresh;

  const _ProfileCard({required this.user, required this.onRefresh});

  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard> {
  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1C1C2E), Color(0xFF1C1C1E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2D2D2D)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    u.initials,
                    style: GoogleFonts.roboto(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      u.fullName,
                      style: GoogleFonts.roboto(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      u.email,
                      style: GoogleFonts.roboto(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                    if (u.birthday.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.cake_outlined, size: 12, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            u.birthday,
                            style: GoogleFonts.roboto(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showEditDialog(context),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: Text(
                'Edit Profile',
                style: GoogleFonts.roboto(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary, width: 1.2),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDialog(BuildContext context) async {
    final u = widget.user;
    final firstCtrl = TextEditingController(text: u.firstname);
    final lastCtrl = TextEditingController(text: u.lastname);
    final birthdayCtrl = TextEditingController(text: u.birthday);
    bool saving = false;
    String? errorMsg;

    await showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => Dialog(
          backgroundColor: const Color(0xFF1C1C2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit Profile',
                  style: GoogleFonts.roboto(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _EditField(label: 'First Name', controller: firstCtrl)),
                    const SizedBox(width: 12),
                    Expanded(child: _EditField(label: 'Last Name', controller: lastCtrl)),
                  ],
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.tryParse(birthdayCtrl.text) ?? DateTime(1990, 1, 1),
                      firstDate: DateTime(1920),
                      lastDate: DateTime.now(),
                      builder: (c, child) => Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: const ColorScheme.dark(primary: AppColors.primary),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) {
                      birthdayCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
                    }
                  },
                  child: AbsorbPointer(
                    child: _EditField(
                      label: 'Birthday',
                      controller: birthdayCtrl,
                      suffixIcon: Icons.calendar_today_outlined,
                    ),
                  ),
                ),
                if (errorMsg != null) ...[
                  const SizedBox(height: 10),
                  Text(errorMsg!, style: GoogleFonts.roboto(fontSize: 12, color: AppColors.error)),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: const BorderSide(color: Color(0xFF3D3D3D)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text('Cancel', style: GoogleFonts.roboto(fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: saving
                            ? null
                            : () async {
                                setDlgState(() {
                                  saving = true;
                                  errorMsg = null;
                                });
                                try {
                                  final api = ApiClient.instance;
                                  await api.put('/users/${u.id}', data: {
                                    'firstname': firstCtrl.text.trim(),
                                    'lastname': lastCtrl.text.trim(),
                                    'birthday': birthdayCtrl.text.trim(),
                                  });
                                  // Clear cached user
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.remove(kCachedUserKey);
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  // Reload user
                                  if (context.mounted) {
                                    await context.read<AuthProvider>().checkAuthStatus();
                                    widget.onRefresh();
                                  }
                                } catch (_) {
                                  setDlgState(() {
                                    saving = false;
                                    errorMsg = 'Failed to update profile. Please try again.';
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text('Save', style: GoogleFonts.roboto(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Edit Field ──────────────────────────────────────────────────────────────

class _EditField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final IconData? suffixIcon;

  const _EditField({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.roboto(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: GoogleFonts.roboto(fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF121220),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF2D2D2D)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF2D2D2D)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
            suffixIcon: suffixIcon != null
                ? Icon(suffixIcon, color: AppColors.textMuted, size: 18)
                : null,
          ),
        ),
      ],
    );
  }
}

// ─── Account Link Card ───────────────────────────────────────────────────────

class _AccountLinkCard extends StatelessWidget {
  final Widget icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final Color buttonColor;
  final VoidCallback onTap;

  const _AccountLinkCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.buttonColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      child: Row(
        children: [
          icon,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                Text(subtitle, style: GoogleFonts.roboto(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              backgroundColor: buttonColor.withValues(alpha: 0.12),
              foregroundColor: buttonColor,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(buttonLabel, style: GoogleFonts.roboto(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ─── Danger Zone ─────────────────────────────────────────────────────────────

class _DangerZone extends StatefulWidget {
  final String userId;
  final AuthProvider auth;

  const _DangerZone({required this.userId, required this.auth});

  @override
  State<_DangerZone> createState() => _DangerZoneState();
}

class _DangerZoneState extends State<_DangerZone> {
  int _deleteStep = 0; // 0=show button, 1=first warning, 2=deleting

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1010),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20),
              const SizedBox(width: 8),
              Text(
                'Delete Account',
                style: GoogleFonts.roboto(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.error),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Deleting your account is permanent and cannot be undone. All your calendars, events, tasks, and data will be lost.',
            style: GoogleFonts.roboto(fontSize: 13, color: AppColors.textMuted, height: 1.4),
          ),
          const SizedBox(height: 16),

          if (_deleteStep == 0)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => setState(() => _deleteStep = 1),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Delete My Account', style: GoogleFonts.roboto(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),

          if (_deleteStep == 1) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚠️ Are you absolutely sure?',
                    style: GoogleFonts.roboto(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.error),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'This action cannot be reversed. Your account and all associated data will be permanently deleted.',
                    style: GoogleFonts.roboto(fontSize: 12, color: AppColors.textMuted, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _deleteStep = 0),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: Color(0xFF3D3D3D)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text('No, Keep Account', style: GoogleFonts.roboto(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _deleteStep == 2 ? null : () => _deleteAccount(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _deleteStep == 2
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            'Yes, Delete',
                            style: GoogleFonts.roboto(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context) async {
    setState(() => _deleteStep = 2);
    try {
      final api = ApiClient.instance;
      await api.delete('/users/${widget.userId}');
      await widget.auth.logout();
      // Auth provider will navigate away due to status change
    } catch (_) {
      if (mounted) {
        setState(() => _deleteStep = 1);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete account. Please try again.')),
        );
      }
    }
  }
}

// ─── Shared Widgets ──────────────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  final Widget child;
  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2D2D2D)),
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool danger;

  const _SectionHeader({required this.title, this.danger = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.roboto(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: danger ? AppColors.error.withValues(alpha: 0.8) : AppColors.textMuted,
        ),
      ),
    );
  }
}

// ─── Google Logo painter ─────────────────────────────────────────────────────

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const c = Offset(11, 11);
    final paint = Paint()..style = PaintingStyle.fill;

    // Simplified G
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: 10),
      -0.5,
      3.14,
      false,
      paint..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFF4285F4),
    );

    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF4285F4);
    canvas.drawRect(Rect.fromLTWH(c.dx - 1, c.dy - 1.5, 9, 3), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
