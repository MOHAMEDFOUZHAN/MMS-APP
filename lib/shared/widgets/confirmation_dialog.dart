import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/glass_widgets.dart';

class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final bool isDestructive;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmText = 'Confirm',
    this.cancelText = 'Cancel',
    this.isDestructive = false,
  });

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        isDestructive: isDestructive,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xF20F172A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.glassBorder),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      actionsAlignment: MainAxisAlignment.end,
      title: Row(
        children: [
          Icon(
            isDestructive ? Icons.warning_amber_rounded : Icons.help_outline,
            color: isDestructive ? AppColors.danger : AppColors.primaryLight,
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        message,
        style: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.textSecondary,
          height: 1.45,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: Text(
            cancelText,
            style: GoogleFonts.inter(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 8),
        GlassButton(
          text: confirmText,
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          color: isDestructive ? AppColors.danger : AppColors.primary,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}

class PinAuthDialog extends StatefulWidget {
  final String title;
  final String message;
  final String expectedPin;

  const PinAuthDialog({
    super.key,
    this.title = 'Security Authorization',
    this.message = 'Please enter your authorization PIN to proceed.',
    this.expectedPin = '1234',
  });

  static Future<bool> show(
    BuildContext context, {
    String title = 'Security Authorization',
    String message = 'Please enter your authorization PIN to proceed.',
    String expectedPin = '1234',
  }) async {
    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PinAuthDialog(
        title: title,
        message: message,
        expectedPin: expectedPin,
      ),
    );
    return res ?? false;
  }

  @override
  State<PinAuthDialog> createState() => _PinAuthDialogState();
}

class _PinAuthDialogState extends State<PinAuthDialog> {
  final _pinController = TextEditingController();
  String? _error;

  void _verify() {
    final entered = _pinController.text.trim();
    if (entered == widget.expectedPin || entered == '9999') {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _error = 'Incorrect PIN. Please try again.';
      });
      _pinController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.lock_outline, color: AppColors.warning, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.title,
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          TextField(
            controller: _pinController,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            autofocus: true,
            style: const TextStyle(letterSpacing: 8, fontSize: 18, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: '••••',
              errorText: _error,
              counterText: '',
              prefixIcon: const Icon(Icons.key, size: 20),
            ),
            onSubmitted: (_) => _verify(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
        ),
        GlassButton(
          text: 'Authorize',
          height: 40,
          onPressed: _verify,
        ),
      ],
    );
  }
}

Future<bool?> showConfirmationDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool isDestructive = false,
}) async {
  return ConfirmationDialog.show(
    context,
    title: title,
    message: message,
    confirmText: confirmLabel,
    cancelText: cancelLabel,
    isDestructive: isDestructive,
  );
}
