import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../../../core/constants/app_colors.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _birthdayController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _termsAccepted = false;
  bool _showSuccessModal = false;
  bool _emailSendingLoad = false;
  String _registeredEmail = '';

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _birthdayController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _getPasswordStrength(String password) {
    if (password.length < 4) return 'Very Weak';
    if (password.length < 8) return 'Weak';
    if (password.length < 12) return 'Medium';
    return 'Strong';
  }

  Color _getStrengthColor(String strength) {
    switch (strength) {
      case 'Very Weak': return const Color(0xFFFF4757);
      case 'Weak': return const Color(0xFFFFA502);
      case 'Medium': return const Color(0xFF2ED573);
      case 'Strong': return const Color(0xFF1E90FF);
      default: return Colors.grey;
    }
  }

  double _getStrengthProgress(String strength) {
    switch (strength) {
      case 'Very Weak': return 0.25;
      case 'Weak': return 0.5;
      case 'Medium': return 0.75;
      case 'Strong': return 1.0;
      default: return 0;
    }
  }

  Future<void> _selectBirthday() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (date != null) {
      _birthdayController.text = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      setState(() {});
    }
  }

  Future<void> _handleSubmit() async {
    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept the terms and conditions.')),
      );
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match.')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    _registeredEmail = _emailController.text.trim();
    final success = await auth.signup(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      birthday: _birthdayController.text.trim(),
      email: _registeredEmail,
      password: _passwordController.text,
    );

    if (!mounted) return;
    if (success) {
      setState(() => _showSuccessModal = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Registration failed.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _resendEmail() async {
    setState(() => _emailSendingLoad = true);
    final auth = context.read<AuthProvider>();
    await auth.resendVerification(_registeredEmail);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _emailSendingLoad = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final strength = _getPasswordStrength(password);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back button
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF333333)),
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 16),

                    // Logo + Title
                    Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        'Join Us Today!',
                        style: GoogleFonts.dancingScript(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        'Create your account and start your journey with us.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dancingScript(
                          fontSize: 15,
                          color: const Color(0xFF666666),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // First + Last Name
                    Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _fieldLabel('First Name'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _firstNameController,
                            style: const TextStyle(color: Color(0xFF1A1A1A)),
                            decoration: _inputDec('John'),
                            validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                          ),
                        ]),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _fieldLabel('Last Name'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _lastNameController,
                            style: const TextStyle(color: Color(0xFF1A1A1A)),
                            decoration: _inputDec('Doe'),
                            validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                          ),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 16),

                    // Birthday
                    _fieldLabel('Birthday'),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: _selectBirthday,
                      child: AbsorbPointer(
                        child: TextFormField(
                          controller: _birthdayController,
                          style: const TextStyle(color: Color(0xFF1A1A1A)),
                          decoration: _inputDec('YYYY-MM-DD').copyWith(
                            suffixIcon: const Icon(Icons.calendar_today, size: 18, color: Color(0xFF888888)),
                          ),
                          validator: (v) => v?.trim().isEmpty == true ? 'Birthday is required' : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Email
                    _fieldLabel('Email'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Color(0xFF1A1A1A)),
                      decoration: _inputDec('example@gmail.com'),
                      validator: (v) {
                        if (v?.trim().isEmpty == true) return 'Email is required';
                        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v!.trim())) return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _fieldLabel('Password'),
                        TextButton(
                          onPressed: () => setState(() => _showPassword = !_showPassword),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          child: Text(_showPassword ? 'Hide' : 'Show', style: const TextStyle(fontSize: 13, color: Color(0xFF666666))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_showPassword,
                      style: const TextStyle(color: Color(0xFF1A1A1A)),
                      decoration: _inputDec('Create a strong password'),
                      onChanged: (_) => setState(() {}),
                      validator: (v) => v?.isEmpty == true ? 'Password is required' : null,
                    ),
                    if (password.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: _getStrengthProgress(strength),
                          backgroundColor: const Color(0xFFEEEEEE),
                          valueColor: AlwaysStoppedAnimation(_getStrengthColor(strength)),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Strength: $strength',
                          style: TextStyle(fontSize: 12, color: _getStrengthColor(strength), fontWeight: FontWeight.w600)),
                    ],
                    const SizedBox(height: 16),

                    // Confirm Password
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _fieldLabel('Confirm Password'),
                        TextButton(
                          onPressed: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          child: Text(_showConfirmPassword ? 'Hide' : 'Show', style: const TextStyle(fontSize: 13, color: Color(0xFF666666))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: !_showConfirmPassword,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(color: Color(0xFF1A1A1A)),
                      decoration: _inputDec('Confirm your password').copyWith(
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: confirmPassword.isEmpty
                                ? const Color(0xFFDDDDDD)
                                : confirmPassword == password
                                    ? const Color(0xFF2ED573)
                                    : const Color(0xFFFF4757),
                          ),
                        ),
                      ),
                      validator: (v) => v?.isEmpty == true ? 'Please confirm your password' : null,
                    ),
                    if (confirmPassword.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        confirmPassword == password ? '✓ Passwords match' : '✗ Passwords do not match',
                        style: TextStyle(
                          fontSize: 12,
                          color: confirmPassword == password ? const Color(0xFF2ED573) : const Color(0xFFFF4757),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Terms
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _termsAccepted,
                          onChanged: (v) => setState(() => _termsAccepted = v!),
                          activeColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: RichText(
                              text: TextSpan(
                                style: GoogleFonts.roboto(color: const Color(0xFF666666), fontSize: 14),
                                children: [
                                  const TextSpan(text: 'I agree to the '),
                                  TextSpan(text: 'Terms & Conditions', style: GoogleFonts.roboto(color: AppColors.primary, fontWeight: FontWeight.w500)),
                                  const TextSpan(text: ' and '),
                                  TextSpan(text: 'Privacy Policy', style: GoogleFonts.roboto(color: AppColors.primary, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 15, offset: const Offset(0, 4))],
                        ),
                        child: ElevatedButton(
                          onPressed: auth.isLoading ? null : _handleSubmit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: auth.isLoading
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(Colors.white)))
                              : Text('Create Account', style: GoogleFonts.roboto(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Sign in link
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Already have an account? ', style: GoogleFonts.roboto(color: const Color(0xFF666666))),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Text('Sign in', style: GoogleFonts.roboto(color: AppColors.primary, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),

          // Success Modal
          if (_showSuccessModal)
            Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.88,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 32)],
                  ),
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(18)),
                        child: const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
                      ),
                      const SizedBox(height: 16),
                      Text('Register Successful', style: GoogleFonts.roboto(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF2ED573))),
                      const SizedBox(height: 8),
                      Text('Go to your inbox to activate your account!', textAlign: TextAlign.center, style: GoogleFonts.roboto(fontSize: 14, color: const Color(0xFF333333))),
                      const SizedBox(height: 16),
                      if (_emailSendingLoad)
                        Text('sending....', style: GoogleFonts.roboto(color: const Color(0xFF666666)))
                      else
                        TextButton(
                          onPressed: _resendEmail,
                          child: Text('Resend email', style: GoogleFonts.roboto(color: AppColors.primary, decoration: TextDecoration.underline)),
                        ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: DecoratedBox(
                          decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(12)),
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() => _showSuccessModal = false);
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            child: Text('Done', style: GoogleFonts.roboto(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String label) => Text(
    label,
    style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.w500, color: const Color(0xFF333333)),
  );

  InputDecoration _inputDec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFFAAAAAA)),
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFDDDDDD))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFDDDDDD))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );
}
