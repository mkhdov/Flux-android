import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/models/user_model.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/providers/theme_provider.dart';
import 'package:intl/intl.dart';

bool _isDarkTheme(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

Color _themeBg(BuildContext context) =>
    _isDarkTheme(context) ? AppColors.darkBg : AppColors.lightBg;
Color _themeCard(BuildContext context) =>
    _isDarkTheme(context) ? AppColors.darkCard : AppColors.lightCard;
Color _themeCardAlt(BuildContext context) =>
    _isDarkTheme(context) ? AppColors.darkCardAlt : AppColors.lightCardAlt;
Color _themeBorder(BuildContext context) =>
    _isDarkTheme(context) ? AppColors.darkBorder : AppColors.lightBorder;
Color _themeTextPrimary(BuildContext context) =>
    _isDarkTheme(context) ? AppColors.textPrimary : AppColors.lightTextPrimary;
Color _themeTextSecondary(BuildContext context) => _isDarkTheme(context)
    ? AppColors.textSecondary
    : AppColors.lightTextSecondary;
Color _themeTextMuted(BuildContext context) =>
    _isDarkTheme(context) ? AppColors.textMuted : AppColors.lightTextMuted;
Color _themeTextDisabled(BuildContext context) => _isDarkTheme(context)
    ? AppColors.textDisabled
    : AppColors.lightTextDisabled;
Color _themeDangerSurface(BuildContext context) =>
    _isDarkTheme(context) ? const Color(0xFF1E1010) : const Color(0xFFFFF1F0);

class SettingsScreen extends StatefulWidget {
  final GlobalKey<ScaffoldState>? scaffoldKey;
  const SettingsScreen({super.key, this.scaffoldKey});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLinkingGoogle = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    Widget topBar = Container(
      height: kToolbarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: _themeCard(context),
        border: Border(bottom: BorderSide(color: _themeBorder(context))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.menu, color: _themeTextSecondary(context)),
            onPressed: () => widget.scaffoldKey?.currentState?.openDrawer(),
          ),
          Expanded(
            child: Text(
              'Settings',
              style: GoogleFonts.roboto(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _themeTextPrimary(context),
              ),
            ),
          ),
        ],
      ),
    );

    return Column(
      children: [
        topBar,
        Expanded(
          child: Container(
            color: _themeBg(context),
            child: user == null
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : _buildBody(context, user, auth),
          ),
        ),
      ],
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
                  child: Icon(Icons.dark_mode_rounded,
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dark Mode',
                        style: GoogleFonts.roboto(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _themeTextPrimary(context)),
                      ),
                      Text(
                        'Switch between light and dark theme',
                        style: GoogleFonts.roboto(
                            fontSize: 12, color: _themeTextMuted(context)),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: context.watch<ThemeProvider>().isDarkMode,
                  onChanged: (v) =>
                      context.read<ThemeProvider>().setDarkMode(v),
                  activeThumbColor: AppColors.primary,
                  activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
                  inactiveThumbColor: _themeTextMuted(context),
                  inactiveTrackColor: _themeBorder(context),
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
                  child: Icon(Icons.notifications_outlined,
                      color: Color(0xFF3B82F6), size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notifications',
                        style: GoogleFonts.roboto(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _themeTextPrimary(context)),
                      ),
                      Text(
                        'Manage push notification preferences',
                        style: GoogleFonts.roboto(
                            fontSize: 12, color: _themeTextMuted(context)),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: _themeTextMuted(context), size: 20),
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
                  child: Icon(Icons.language_rounded,
                      color: Color(0xFF22C55E), size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Language & Region',
                        style: GoogleFonts.roboto(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _themeTextPrimary(context)),
                      ),
                      Text(
                        'English (US)',
                        style: GoogleFonts.roboto(
                            fontSize: 12, color: _themeTextMuted(context)),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: _themeTextMuted(context), size: 20),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Privacy & Security ────────────────────────────────────
          _SectionHeader(title: 'Privacy & Security'),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _showChangePasswordDialog(context, user, auth),
            child: _SettingsCard(
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3A2A2A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.lock_outline_rounded,
                        color: Color(0xFFF59E0B), size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Change Password',
                          style: GoogleFonts.roboto(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _themeTextPrimary(context)),
                        ),
                        Text(
                          'Update your account password',
                          style: GoogleFonts.roboto(
                              fontSize: 12, color: _themeTextMuted(context)),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      color: _themeTextMuted(context), size: 20),
                ],
              ),
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
                  child: Icon(Icons.info_outline_rounded,
                      color: _themeTextSecondary(context), size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'About Flux',
                        style: GoogleFonts.roboto(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _themeTextPrimary(context)),
                      ),
                      Text(
                        'Version 1.0.0',
                        style: GoogleFonts.roboto(
                            fontSize: 12, color: _themeTextMuted(context)),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: _themeTextMuted(context), size: 20),
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

  void _showChangePasswordDialog(
      BuildContext context, UserModel user, AuthProvider auth) {
    final oldPwdCtrl = TextEditingController();
    final newPwdCtrl = TextEditingController();
    final confirmPwdCtrl = TextEditingController();
    bool loading = false;
    bool success = false;
    String? error;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => Dialog(
          backgroundColor: _themeCard(context),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Change Password',
                      style: GoogleFonts.roboto(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _themeTextPrimary(context),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, size: 20),
                      color: _themeTextMuted(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                if (success) ...[
                  const SizedBox(height: 24),
                  Center(
                    child: Column(
                      children: [
                        const Icon(Icons.check_circle_outline,
                            color: Color(0xFF4CAF50), size: 48),
                        const SizedBox(height: 12),
                        Text(
                          'Password changed successfully!',
                          style: GoogleFonts.roboto(
                            fontSize: 14,
                            color: const Color(0xFF4CAF50),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Done',
                          style: GoogleFonts.roboto(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  _DialogField(
                    label: 'Current Password',
                    controller: oldPwdCtrl,
                    obscureText: true,
                    themeCardAlt: _themeCardAlt(context),
                    themeBorder: _themeBorder(context),
                    themeTextPrimary: _themeTextPrimary(context),
                    themeTextMuted: _themeTextMuted(context),
                  ),
                  const SizedBox(height: 12),
                  _DialogField(
                    label: 'New Password',
                    controller: newPwdCtrl,
                    obscureText: true,
                    themeCardAlt: _themeCardAlt(context),
                    themeBorder: _themeBorder(context),
                    themeTextPrimary: _themeTextPrimary(context),
                    themeTextMuted: _themeTextMuted(context),
                  ),
                  const SizedBox(height: 12),
                  _DialogField(
                    label: 'Confirm New Password',
                    controller: confirmPwdCtrl,
                    obscureText: true,
                    themeCardAlt: _themeCardAlt(context),
                    themeBorder: _themeBorder(context),
                    themeTextPrimary: _themeTextPrimary(context),
                    themeTextMuted: _themeTextMuted(context),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(error!,
                        style: GoogleFonts.roboto(
                            fontSize: 12, color: AppColors.error)),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _themeTextSecondary(context),
                            side: BorderSide(color: _themeBorder(context)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text('Cancel',
                              style: GoogleFonts.roboto(fontSize: 13)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: loading
                              ? null
                              : () async {
                                  if (newPwdCtrl.text.length < 8) {
                                    setDlgState(() => error =
                                        'Password must be at least 8 characters.');
                                    return;
                                  }
                                  if (newPwdCtrl.text !=
                                      confirmPwdCtrl.text) {
                                    setDlgState(
                                        () => error = 'Passwords do not match.');
                                    return;
                                  }
                                  setDlgState(() {
                                    loading = true;
                                    error = null;
                                  });
                                  try {
                                    final api = ApiClient.instance;
                                    await api.put(
                                        '/api/auth/change-password/${user.id}',
                                        data: {
                                          'oldPassword': oldPwdCtrl.text,
                                          'currentPassword': newPwdCtrl.text,
                                          'repeatedPassword':
                                              confirmPwdCtrl.text,
                                        });
                                    setDlgState(() => success = true);
                                  } on DioException catch (e) {
                                    final data = e.response?.data;
                                    setDlgState(() {
                                      loading = false;
                                      error = data is Map
                                          ? (data['errors']?['error']
                                                      ?.toString() ??
                                                  data['message']
                                                      ?.toString() ??
                                                  'Failed to change password.')
                                          : 'Failed to change password.';
                                    });
                                  } catch (_) {
                                    setDlgState(() {
                                      loading = false;
                                      error = 'An unexpected error occurred.';
                                    });
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: loading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2),
                                )
                              : Text('Change Password',
                                  style: GoogleFonts.roboto(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
  }

  Future<void> _linkGoogleNative(String userId) async {
    setState(() => _isLinkingGoogle = true);
    try {
      if (kGoogleWebClientId == 'YOUR_GOOGLE_WEB_CLIENT_ID') {
        throw Exception(
            'Please configure kGoogleWebClientId in api_constants.dart');
      }

      await GoogleSignIn.instance.initialize(
        serverClientId: kGoogleWebClientId,
      );

      await GoogleSignIn.instance.signOut(); // Ensure fresh start
      GoogleSignInAccount? account;
      try {
        account = await GoogleSignIn.instance.authenticate(
          scopeHint: ['https://www.googleapis.com/auth/calendar'],
        );
      } catch (e) {
        setState(() => _isLinkingGoogle = false);
        return; // User canceled or error
      }

      if (account == null) {
        setState(() => _isLinkingGoogle = false);
        return;
      }

      // Delay to allow the account picker UI to fully dismiss before starting the authorization UI.
      // This prevents the "onCancelled at PHASE_CLIENT_ALREADY_HIDDEN" error on Android.
      await Future.delayed(const Duration(milliseconds: 600));

      final authz =
          await GoogleSignIn.instance.authorizationClient.authorizeServer(
        ['https://www.googleapis.com/auth/calendar'],
      );
      final serverAuthCode = authz?.serverAuthCode;

      if (serverAuthCode == null) {
        throw Exception('Failed to get serverAuthCode from Google');
      }

      // Send to backend
      final api = ApiClient.instance;
      final response = await api.post('/auth/google/mobile-link?userId=$userId', data: {
        'serverAuthCode': serverAuthCode,
        'email': account.email,
      });
      final body = response.data;
      if (body is Map && body['status'] != 'success') {
        throw Exception(body['message'] ?? 'Failed to link Google account');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Successfully linked Google account!'),
              backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to link Google.'),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLinkingGoogle = false);
    }
  }

  Future<void> _linkZoom(String userId) async {
    final uri = Uri.parse('http://192.168.1.4:8083/zoom/connect/$userId');
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
          child: Icon(Icons.video_call_rounded,
              color: Color(0xFF2D8CFF), size: 20),
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
        gradient: LinearGradient(
          colors: _isDarkTheme(context)
              ? const [Color(0xFF2E1C1F), AppColors.darkCard]
              : const [Color(0xFFFFF4EE), AppColors.lightCard],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _themeBorder(context)),
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
                        color: _themeTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      u.email,
                      style: GoogleFonts.roboto(
                        fontSize: 13,
                        color: _themeTextMuted(context),
                      ),
                    ),
                    if (u.birthday.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.cake_outlined,
                              size: 12, color: _themeTextMuted(context)),
                          const SizedBox(width: 4),
                          Text(
                            u.birthday,
                            style: GoogleFonts.roboto(
                                fontSize: 12, color: _themeTextMuted(context)),
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
              icon: Icon(Icons.edit_outlined, size: 16),
              label: Text(
                'Edit Profile',
                style: GoogleFonts.roboto(
                    fontSize: 13, fontWeight: FontWeight.w500),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary, width: 1.2),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
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
          backgroundColor: _themeCard(context),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
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
                    color: _themeTextPrimary(context),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                        child: _EditField(
                            label: 'First Name', controller: firstCtrl)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _EditField(
                            label: 'Last Name', controller: lastCtrl)),
                  ],
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.tryParse(birthdayCtrl.text) ??
                          DateTime(1990, 1, 1),
                      firstDate: DateTime(1920),
                      lastDate: DateTime.now(),
                      builder: (c, child) => Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: const ColorScheme.dark(
                              primary: AppColors.primary),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) {
                      birthdayCtrl.text =
                          DateFormat('yyyy-MM-dd').format(picked);
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
                  Text(errorMsg!,
                      style: GoogleFonts.roboto(
                          fontSize: 12, color: AppColors.error)),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _themeTextSecondary(context),
                          side: BorderSide(color: _themeBorder(context)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text('Cancel',
                            style: GoogleFonts.roboto(fontSize: 13)),
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
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  await prefs.remove(kCachedUserKey);
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  // Reload user
                                  if (context.mounted) {
                                    await context
                                        .read<AuthProvider>()
                                        .checkAuthStatus();
                                    widget.onRefresh();
                                  }
                                } catch (_) {
                                  setDlgState(() {
                                    saving = false;
                                    errorMsg =
                                        'Failed to update profile. Please try again.';
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : Text('Save',
                                style: GoogleFonts.roboto(
                                    fontSize: 13, fontWeight: FontWeight.w600)),
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
        Text(label,
            style: GoogleFonts.roboto(
                fontSize: 11,
                color: _themeTextMuted(context),
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: GoogleFonts.roboto(
              fontSize: 14, color: _themeTextPrimary(context)),
          decoration: InputDecoration(
            filled: true,
            fillColor: _themeCardAlt(context),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _themeBorder(context)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _themeBorder(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
            suffixIcon: suffixIcon != null
                ? Icon(suffixIcon, color: _themeTextMuted(context), size: 18)
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
                Text(title,
                    style: GoogleFonts.roboto(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _themeTextPrimary(context))),
                Text(subtitle,
                    style: GoogleFonts.roboto(
                        fontSize: 12, color: _themeTextMuted(context))),
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(buttonLabel,
                style: GoogleFonts.roboto(
                    fontSize: 12, fontWeight: FontWeight.w600)),
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
        color: _themeDangerSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: AppColors.error, size: 20),
              const SizedBox(width: 8),
              Text(
                'Delete Account',
                style: GoogleFonts.roboto(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Deleting your account is permanent and cannot be undone. All your calendars, events, tasks, and data will be lost.',
            style: GoogleFonts.roboto(
                fontSize: 13, color: _themeTextMuted(context), height: 1.4),
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
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Delete My Account',
                    style: GoogleFonts.roboto(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
          if (_deleteStep == 1) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚠️ Are you absolutely sure?',
                    style: GoogleFonts.roboto(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.error),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'This action cannot be reversed. Your account and all associated data will be permanently deleted.',
                    style: GoogleFonts.roboto(
                        fontSize: 12,
                        color: _themeTextMuted(context),
                        height: 1.4),
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
                      foregroundColor: _themeTextSecondary(context),
                      side: BorderSide(color: _themeBorder(context)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text('No, Keep Account',
                        style: GoogleFonts.roboto(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        _deleteStep == 2 ? null : () => _deleteAccount(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _deleteStep == 2
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            'Yes, Delete',
                            style: GoogleFonts.roboto(
                                fontSize: 12, fontWeight: FontWeight.w700),
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
          const SnackBar(
              content: Text('Failed to delete account. Please try again.')),
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
        color: _themeCard(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _themeBorder(context)),
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
          color: danger
              ? AppColors.error.withValues(alpha: 0.8)
              : _themeTextMuted(context),
        ),
      ),
    );
  }
}

// ─── Dialog Field ────────────────────────────────────────────────────────────

class _DialogField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool obscureText;
  final Color themeCardAlt;
  final Color themeBorder;
  final Color themeTextPrimary;
  final Color themeTextMuted;

  const _DialogField({
    required this.label,
    required this.controller,
    this.obscureText = false,
    required this.themeCardAlt,
    required this.themeBorder,
    required this.themeTextPrimary,
    required this.themeTextMuted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.roboto(
                fontSize: 11,
                color: themeTextMuted,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          style: GoogleFonts.roboto(
              fontSize: 14, color: themeTextPrimary),
          decoration: InputDecoration(
            filled: true,
            fillColor: themeCardAlt,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: themeBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: themeBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
      ],
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
      paint
        ..style = PaintingStyle.stroke
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
