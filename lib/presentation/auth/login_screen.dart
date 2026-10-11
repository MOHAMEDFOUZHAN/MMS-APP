import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/factory_constants.dart';
import '../../core/services/app_update_service.dart';
import '../../core/theme/glass_widgets.dart';
import '../providers/app_providers.dart';
import '../owner/owner_login_screen.dart';
import '../../shared/widgets/maple_pro_footer.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isTeaLogin = false;
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _updateTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        AppUpdateService.instance.checkAndPromptUpdate(context: context);
      }
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authNotifierProvider.notifier).signIn(
          _usernameController.text.trim(),
          _passwordController.text,
        );

    if (!mounted) return;

    if (!success) {
      final error = ref.read(authNotifierProvider).errorMessage ?? 'Login failed. Please verify credentials.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(error)),
            ],
          ),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.status == AuthStatus.loading;

    return Scaffold(
      body: AmbientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo & Branding
                      Container(
                        width: 84,
                        height: 84,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 18,
                              spreadRadius: 2,
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        FactoryConstants.appName,
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Material Management & Inward System',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Glass Login Card
                      GlassCard(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Dedicated Login Mode Switcher
                            Container(
                              margin: const EdgeInsets.only(bottom: 20),
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: const Color(0x330F172A),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.glassBorder),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          _isTeaLogin = false;
                                          if (_usernameController.text == 'bm' ||
                                              _usernameController.text == 'tea' ||
                                              _usernameController.text == 'tea123') {
                                            _usernameController.clear();
                                            _passwordController.clear();
                                          }
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        decoration: BoxDecoration(
                                          color: !_isTeaLogin
                                              ? AppColors.primary.withValues(alpha: 0.22)
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(8),
                                          border: !_isTeaLogin
                                              ? Border.all(color: AppColors.primaryLight.withValues(alpha: 0.4))
                                              : null,
                                        ),
                                        child: Text(
                                          'Standard Login',
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: !_isTeaLogin ? FontWeight.bold : FontWeight.w500,
                                            color: !_isTeaLogin ? AppColors.textPrimary : AppColors.textMuted,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          _isTeaLogin = true;
                                          _usernameController.text = 'bm';
                                          _passwordController.text = 'tea123';
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        decoration: BoxDecoration(
                                          color: _isTeaLogin
                                              ? const Color(0xFF10B981).withValues(alpha: 0.22)
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(8),
                                          border: _isTeaLogin
                                              ? Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.45))
                                              : null,
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.eco_rounded, size: 14, color: Color(0xFF10B981)),
                                            const SizedBox(width: 5),
                                            Text(
                                              'Tea Login',
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: _isTeaLogin ? FontWeight.bold : FontWeight.w500,
                                                color: _isTeaLogin ? Colors.white : AppColors.textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Text(
                              _isTeaLogin ? 'Tea Department Sign In' : 'Sign In',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isTeaLogin
                                  ? 'Restricted phone terminal (Transfers, Storage, Dispatch)'
                                  : 'Enter your authorized credentials',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: _isTeaLogin ? const Color(0xFF10B981) : AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Username / Email input
                            TextFormField(
                              controller: _usernameController,
                              keyboardType: TextInputType.text,
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                              decoration: InputDecoration(
                                labelText: 'Username or Email',
                                hintText: _isTeaLogin ? 'bm' : 'Enter username or email',
                                prefixIcon: Icon(
                                  _isTeaLogin ? Icons.badge_outlined : Icons.person_outline,
                                  size: 20,
                                  color: _isTeaLogin ? const Color(0xFF10B981) : null,
                                ),
                              ),
                              onChanged: (val) {
                                final clean = val.trim().toLowerCase();
                                if (clean == 'tea' || clean == 'bm' || clean == 'tea123') {
                                  if (!_isTeaLogin) {
                                    setState(() => _isTeaLogin = true);
                                  }
                                } else if (_isTeaLogin && (clean == 'admin' || clean == 'owner')) {
                                  setState(() => _isTeaLogin = false);
                                }
                              },
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Please enter your username or email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Password input (starts blank, no hardcoded passwords)
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                              decoration: InputDecoration(
                                labelText: 'Password',
                                hintText: _isTeaLogin ? 'Enter Tea password' : 'Enter password',
                                prefixIcon: const Icon(Icons.lock_outline, size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                    size: 20,
                                    color: AppColors.textSecondary,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Please enter your password';
                                }
                                return null;
                              },
                              onFieldSubmitted: (_) => _handleLogin(),
                            ),
                            const SizedBox(height: 24),

                            // Sign In Button
                            GlassButton(
                              text: _isTeaLogin ? 'Sign In as Tea User' : 'Sign In to MMS',
                              isLoading: isLoading,
                              icon: Icons.login_rounded,
                              onPressed: _handleLogin,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Executive Owner Access Link
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const OwnerLoginScreen()),
                          );
                        },
                        icon: const Icon(Icons.admin_panel_settings_outlined, size: 16, color: Color(0xFFF59E0B)),
                        label: Text(
                          'Management Login',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: const Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Powered by MAPLE PRO Footer
                      const MapleProFooter(
                        padding: EdgeInsets.symmetric(vertical: 4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
