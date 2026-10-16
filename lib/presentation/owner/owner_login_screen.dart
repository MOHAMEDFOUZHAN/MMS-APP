import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/app_update_service.dart';
import '../providers/owner_providers.dart';
import 'owner_shell_screen.dart';
import '../../shared/widgets/maple_pro_footer.dart';

class OwnerLoginScreen extends ConsumerStatefulWidget {
  const OwnerLoginScreen({super.key});

  @override
  ConsumerState<OwnerLoginScreen> createState() => _OwnerLoginScreenState();
}

class _OwnerLoginScreenState extends ConsumerState<OwnerLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: 'bm');
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  bool _obscurePassword = true;
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
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleOwnerLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(ownerAuthNotifierProvider.notifier).signInOwner(
          _emailController.text.trim(),
          _passwordController.text,
        );

    if (!mounted) return;

    if (success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OwnerShellScreen()),
      );
    } else {
      final error = ref.read(ownerAuthNotifierProvider).errorMessage ??
          'Access Denied: Verification failed. Authorized management access only.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.shield_outlined, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  error,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(ownerAuthNotifierProvider);
    final isLoading = authState.status == OwnerAuthStatus.loading;

    return Scaffold(
      backgroundColor: const Color(0xFF030712), // Deep obsidian background
      body: Stack(
        children: [
          // Background ambient gradient glow (Ignored so touches pass through)
          IgnorePointer(
            child: Stack(
              children: [
                Positioned(
                  top: -120,
                  left: -80,
                  child: Container(
                    width: 320,
                    height: 320,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFD97706).withValues(alpha: 0.18),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -100,
                  right: -80,
                  child: Container(
                    width: 360,
                    height: 360,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF6366F1).withValues(alpha: 0.15),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final screenWidth = constraints.maxWidth;
                final screenHeight = constraints.maxHeight;

                // Responsive metrics
                final isCompactWidth = screenWidth < 360;
                final isCompactHeight = screenHeight < 640;

                final horizontalScreenPadding = isCompactWidth ? 16.0 : (screenWidth < 600 ? 24.0 : 32.0);
                final verticalScreenPadding = isCompactHeight ? 12.0 : 24.0;

                final badgeSize = isCompactHeight ? 56.0 : (isCompactWidth ? 60.0 : 68.0);
                final badgeIconSize = isCompactHeight ? 26.0 : (isCompactWidth ? 28.0 : 32.0);

                final titleGap = isCompactHeight ? 12.0 : 20.0;
                final formGap = isCompactHeight ? 18.0 : 28.0;
                final cardInteriorPadding = isCompactWidth
                    ? const EdgeInsets.symmetric(horizontal: 16, vertical: 20)
                    : EdgeInsets.all(isCompactHeight ? 20 : 28);

                final fieldGap = isCompactHeight ? 14.0 : 20.0;
                final buttonGap = isCompactHeight ? 20.0 : 26.0;

                return SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: screenHeight,
                    ),
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalScreenPadding,
                          vertical: verticalScreenPadding,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Executive Seal Badge
                                Center(
                                  child: Container(
                                    width: badgeSize,
                                    height: badgeSize,
                                    padding: EdgeInsets.all(isCompactHeight ? 10 : 14),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF1F2937), Color(0xFF111827)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      border: Border.all(
                                        color: const Color(0xFFD97706).withValues(alpha: 0.6),
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFD97706).withValues(alpha: 0.2),
                                          blurRadius: 24,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.admin_panel_settings_rounded,
                                      color: const Color(0xFFF59E0B),
                                      size: badgeIconSize,
                                    ),
                                  ),
                                ),
                                SizedBox(height: titleGap),

                                // Title
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'BENCHMARK MMS',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                      fontSize: isCompactWidth ? 18 : 20,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 2.0,
                                      color: const Color(0xFFF3F4F6),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'MANAGEMENT ACCESS',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: isCompactWidth ? 2.0 : 3.5,
                                      color: const Color(0xFFF59E0B),
                                    ),
                                  ),
                                ),
                                SizedBox(height: formGap),

                                  // Executive Glass Form Card
                                  Container(
                                    padding: cardInteriorPadding,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF111827).withValues(alpha: 0.85),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: const Color(0xFF374151).withValues(alpha: 0.8),
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.5),
                                          blurRadius: 24,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        // Email / ID Field
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            'MANAGEMENT USERNAME / ID',
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 1.0,
                                              color: const Color(0xFF9CA3AF),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        TextFormField(
                                          controller: _emailController,
                                          keyboardType: TextInputType.text,
                                          textInputAction: TextInputAction.next,
                                          onFieldSubmitted: (_) {
                                            FocusScope.of(context).requestFocus(_passwordFocusNode);
                                          },
                                          style: const TextStyle(color: Colors.white, fontSize: 14),
                                          decoration: InputDecoration(
                                            hintText: 'bm',
                                            hintStyle: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                                            prefixIcon: const Icon(Icons.person_outline, size: 20, color: Color(0xFF9CA3AF)),
                                            filled: true,
                                            fillColor: const Color(0xFF030712).withValues(alpha: 0.6),
                                            contentPadding: EdgeInsets.symmetric(
                                              horizontal: isCompactWidth ? 12 : 16,
                                              vertical: isCompactHeight ? 12 : 14,
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: const BorderSide(color: Color(0xFF374151)),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
                                            ),
                                            errorBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: const BorderSide(color: AppColors.danger),
                                            ),
                                            focusedErrorBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
                                            ),
                                            errorMaxLines: 2,
                                            errorStyle: GoogleFonts.inter(fontSize: 11, color: AppColors.danger),
                                          ),
                                          validator: (val) {
                                            if (val == null || val.trim().isEmpty) {
                                              return 'Please enter username or ID';
                                            }
                                            return null;
                                          },
                                        ),
                                        SizedBox(height: fieldGap),

                                        // Password Field
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            'PASSWORD',
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 1.0,
                                              color: const Color(0xFF9CA3AF),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        TextFormField(
                                          controller: _passwordController,
                                          focusNode: _passwordFocusNode,
                                          obscureText: _obscurePassword,
                                          textInputAction: TextInputAction.done,
                                          style: const TextStyle(color: Colors.white, fontSize: 14),
                                          decoration: InputDecoration(
                                            hintText: 'Enter password',
                                            hintStyle: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                                            prefixIcon: const Icon(Icons.lock_outline, size: 20, color: Color(0xFF9CA3AF)),
                                            suffixIcon: IconButton(
                                              icon: Icon(
                                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                                size: 18,
                                                color: const Color(0xFF9CA3AF),
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  _obscurePassword = !_obscurePassword;
                                                });
                                              },
                                            ),
                                            filled: true,
                                            fillColor: const Color(0xFF030712).withValues(alpha: 0.6),
                                            contentPadding: EdgeInsets.symmetric(
                                              horizontal: isCompactWidth ? 12 : 16,
                                              vertical: isCompactHeight ? 12 : 14,
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: const BorderSide(color: Color(0xFF374151)),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
                                            ),
                                            errorBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: const BorderSide(color: AppColors.danger),
                                            ),
                                            focusedErrorBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
                                            ),
                                            errorMaxLines: 2,
                                            errorStyle: GoogleFonts.inter(fontSize: 11, color: AppColors.danger),
                                          ),
                                          validator: (val) {
                                            if (val == null || val.trim().isEmpty) {
                                              return 'Please enter your password';
                                            }
                                            return null;
                                          },
                                          onFieldSubmitted: (_) => _handleOwnerLogin(),
                                        ),
                                        SizedBox(height: buttonGap),

                                        // SIGN IN Button
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(minHeight: 48),
                                          child: ElevatedButton(
                                            onPressed: isLoading ? null : _handleOwnerLogin,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFFF59E0B),
                                              foregroundColor: Colors.black,
                                              disabledBackgroundColor: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                                              padding: EdgeInsets.symmetric(
                                                vertical: isCompactHeight ? 14 : 16,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              elevation: 4,
                                            ),
                                            child: isLoading
                                                ? const SizedBox(
                                                    height: 20,
                                                    width: 20,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                                    ),
                                                  )
                                                : FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    child: Row(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        const Icon(Icons.lock_open_rounded, size: 18, color: Colors.black),
                                                        const SizedBox(width: 8),
                                                        Text(
                                                          'SIGN IN',
                                                          style: GoogleFonts.inter(
                                                            fontSize: 13,
                                                            fontWeight: FontWeight.w800,
                                                            letterSpacing: 1.5,
                                                            color: Colors.black,
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
                                  SizedBox(height: isCompactHeight ? 16 : 24),

                                  // Mandatory Security Message (No emojis, wrap-safe)
                                  Center(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.verified_user_outlined,
                                            size: 14,
                                            color: Color(0xFF9CA3AF),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Authorized management access only.',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: const Color(0xFF9CA3AF),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: isCompactHeight ? 12 : 20),

                                  // Switch to Operator Portal Link
                                  Center(
                                    child: TextButton.icon(
                                      onPressed: () {
                                        Navigator.pop(context);
                                      },
                                      icon: const Icon(Icons.arrow_back_rounded, size: 16, color: Color(0xFF6B7280)),
                                      label: Text(
                                        'Operator Login',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF9CA3AF),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Center(
                                    child: MapleProFooter(
                                      compact: true,
                                      mapleColor: Color(0xFFF59E0B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
            ),
          ),
        ],
      ),
    );
  }
}
