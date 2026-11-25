import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:musify/services/auth_service.dart';
import 'package:musify/services/router_service.dart';
import 'package:musify/utilities/flutter_toast.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  bool _isOtpSent = false;
  bool _loading = false;
  String? _verificationId;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handlePostLogin() async {
    if (mounted) {
      context.go(NavigationManager.homePath);
    }
  }

  void _sendOtp() {
    final rawPhone = _phoneController.text.trim();
    final cleanPhone = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.length < 10) {
      showToast(context, 'Please enter a valid 10-digit mobile number');
      return;
    }

    setState(() {
      _isOtpSent = true;
    });
    showToast(context, 'OTP Sent! (Testing OTP: 0000)');

    // Trigger Firebase Phone Auth in background if real SMS is configured
    AuthService.instance.sendPhoneOtp(
      phoneNumber: rawPhone,
      onCodeSent: (verId) {
        if (mounted) setState(() => _verificationId = verId);
      },
      onError: (_) {},
    );
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty) {
      showToast(context, 'Please enter OTP (use 0000)');
      return;
    }

    setState(() => _loading = true);
    try {
      final success = await AuthService.instance.signInWithPhone(
        phoneNumber: _phoneController.text.trim(),
        otp: otp,
        verificationId: _verificationId,
      );

      if (success) {
        await _handlePostLogin();
      } else {
        if (mounted) {
          showToast(
            context,
            'Invalid OTP or verification failed',
            icon: FluentIcons.error_circle_24_regular,
          );
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _loading = true);
    try {
      final user = await AuthService.instance.signInWithGoogle();
      if (user != null) {
        await _handlePostLogin();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static const Color _brandRed = Color(0xFFE11D48);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fieldFill = isDark
        ? colorScheme.surfaceContainerLow
        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.45);

    InputDecoration modernDecoration({
      required String hintText,
      required Widget prefixIcon,
    }) {
      return InputDecoration(
        prefixIcon: prefixIcon,
        hintText: hintText,
        hintStyle: TextStyle(
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
          fontSize: 14.5,
        ),
        filled: true,
        fillColor: fieldFill,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _brandRed, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          // Ambient top crimson glow
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 340,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _brandRed.withValues(alpha: isDark ? 0.22 : 0.14),
                    _brandRed.withValues(alpha: isDark ? 0.06 : 0.04),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // App Logo squircle with crimson glow
                      Center(
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: _brandRed.withValues(alpha: 0.35),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _brandRed.withValues(alpha: 0.28),
                                blurRadius: 28,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.asset(
                              'assets/app_logo.png',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => ColoredBox(
                                color: colorScheme.surfaceContainerHigh,
                                child: const Icon(
                                  FluentIcons.music_note_2_24_filled,
                                  size: 42,
                                  color: _brandRed,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),

                      // Two-tone NitMusic Branding
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Nit',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.8,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const Text(
                            'Music',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.8,
                              color: _brandRed,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Stream & sync your favorite tracks',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14.5,
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 36),

                      // Section label
                      Row(
                        children: [
                          const Icon(
                            FluentIcons.phone_24_regular,
                            size: 18,
                            color: _brandRed,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isOtpSent ? 'Verify OTP' : 'Mobile Number',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (!_isOtpSent) ...[
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: modernDecoration(
                            hintText: 'Enter 10-digit mobile number',
                            prefixIcon: Padding(
                              padding: const EdgeInsets.only(left: 16, right: 10),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    '+91',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: _brandRed,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    width: 1,
                                    height: 20,
                                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 54,
                          child: FilledButton.icon(
                            onPressed: _loading ? null : _sendOtp,
                            style: FilledButton.styleFrom(
                              backgroundColor: _brandRed,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shadowColor: _brandRed.withValues(alpha: 0.45),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: const Icon(FluentIcons.send_24_regular, size: 18),
                            label: const Text(
                              'Send OTP',
                              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Code sent to +91 ${_phoneController.text.trim()}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isOtpSent = false;
                                  _otpController.clear();
                                });
                              },
                              style: TextButton.styleFrom(foregroundColor: _brandRed),
                              child: const Text(
                                'Change',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          autofocus: true,
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2,
                          ),
                          decoration: modernDecoration(
                            hintText: 'Enter OTP (Testing OTP: 0000)',
                            prefixIcon: const Icon(
                              FluentIcons.password_24_regular,
                              color: _brandRed,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 54,
                          child: FilledButton.icon(
                            onPressed: _loading ? null : _verifyOtp,
                            style: FilledButton.styleFrom(
                              backgroundColor: _brandRed,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shadowColor: _brandRed.withValues(alpha: 0.45),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: _loading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(FluentIcons.checkmark_24_regular, size: 18),
                            label: Text(
                              _loading ? 'Verifying...' : 'Verify & Get Started',
                              style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 26),
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              'OR',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),

                      SizedBox(
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: _loading ? null : _handleGoogleSignIn,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: fieldFill,
                            foregroundColor: colorScheme.onSurface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            side: BorderSide(
                              color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                            ),
                          ),
                          icon: const Icon(
                            FluentIcons.person_add_24_regular,
                            size: 19,
                            color: _brandRed,
                          ),
                          label: const Text(
                            'Continue with Google',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
