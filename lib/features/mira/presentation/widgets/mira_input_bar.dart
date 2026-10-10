import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/mira_state.dart';

/// Futuristic Glass Input & Voice Bar for MIRA
/// Layout:
/// ┌──────────────────────────────────────┐
/// │  Ask MIRA anything...          🎙  ➤ │
/// └──────────────────────────────────────┘
/// Includes subtle language selector, voice mode toggle, listening energy waveform.
class MiraInputBar extends StatefulWidget {
  final MiraStateMode mode;
  final MiraLanguage language;
  final bool isVoiceEnabled;
  final double audioAmplitude;
  final ValueChanged<String> onSendText;
  final VoidCallback onMicTap;
  final ValueChanged<MiraLanguage> onSelectLanguage;
  final VoidCallback onToggleVoice;
  final VoidCallback? onStopSpeaking;

  const MiraInputBar({
    super.key,
    required this.mode,
    required this.language,
    required this.isVoiceEnabled,
    this.audioAmplitude = 0.0,
    required this.onSendText,
    required this.onMicTap,
    required this.onSelectLanguage,
    required this.onToggleVoice,
    this.onStopSpeaking,
  });

  @override
  State<MiraInputBar> createState() => _MiraInputBarState();
}

class _MiraInputBarState extends State<MiraInputBar> with SingleTickerProviderStateMixin {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      HapticFeedback.lightImpact();
      widget.onSendText(text);
      _textController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isListening = widget.mode == MiraStateMode.listening;
    final isProcessing = widget.mode == MiraStateMode.processing;
    final isSpeaking = widget.mode == MiraStateMode.speaking;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xF2070119), // Deep cosmic violet glass
        border: const Border(
          top: BorderSide(color: Color(0x338B5CF6), width: 1.0),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF050019).withValues(alpha: 0.85),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        14,
        8,
        14,
        max(bottomInset, 10) + 4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Auxiliary Header: Language Selector + Voice Toggle / Speaking status
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                _buildSubtleLanguageSelector(),
                const Spacer(),
                if (isSpeaking)
                  _buildSpeakingIndicator()
                else
                  _buildVoiceModeToggle(),
              ],
            ),
          ),

          // 2. Active Mode Status Strip (when listening or processing)
          if (isListening)
            _buildListeningWaveStrip()
          else if (isProcessing)
            _buildProcessingStrip(),

          // 3. Main Futuristic Glass Input Bar
          Container(
            decoration: BoxDecoration(
              color: const Color(0x66180838), // Translucent cosmic glass
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isListening
                    ? const Color(0xFF22D3EE).withValues(alpha: 0.8)
                    : const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                width: isListening ? 1.4 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isListening ? const Color(0xFF22D3EE) : const Color(0xFF7C3AED))
                      .withValues(alpha: isListening ? 0.20 : 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                const SizedBox(width: 8),

                // Text Field
                Expanded(
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    enabled: !isProcessing,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _handleSend(),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFFF8FAFC),
                    ),
                    decoration: InputDecoration(
                      hintText: isListening
                          ? 'MIRA is listening...'
                          : 'Ask MIRA anything...',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF64748B),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),

                const SizedBox(width: 4),

                // Dedicated Microphone Button
                _buildMicrophoneButton(isListening, isProcessing),

                const SizedBox(width: 4),

                // Futuristic Send Action Button
                _buildSendButton(isProcessing),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // Dedicated Microphone Button (Glowing, Pulse in Listening)
  // ────────────────────────────────────────────────────────────
  Widget _buildMicrophoneButton(bool isListening, bool isProcessing) {
    return GestureDetector(
      onTap: isProcessing
          ? null
          : () {
              HapticFeedback.lightImpact();
              widget.onMicTap();
            },
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final pulse = isListening ? _pulseController.value : 0.0;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isListening ? 42 : 38,
            height: isListening ? 42 : 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isListening
                  ? const LinearGradient(
                      colors: [Color(0xFF22D3EE), Color(0xFF8B5CF6)],
                    )
                  : const LinearGradient(
                      colors: [Color(0x338B5CF6), Color(0x3322D3EE)],
                    ),
              border: Border.all(
                color: isListening ? const Color(0xFF22D3EE) : const Color(0x668B5CF6),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isListening ? const Color(0xFF22D3EE) : const Color(0xFF8B5CF6))
                      .withValues(alpha: isListening ? (0.4 + pulse * 0.3) : 0.15),
                  blurRadius: isListening ? 14 : 8,
                  spreadRadius: isListening ? pulse * 2 : 0,
                ),
              ],
            ),
            child: Icon(
              isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
              size: isListening ? 22 : 19,
              color: isListening ? Colors.white : const Color(0xFF22D3EE),
            ),
          );
        },
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // Send Action Button
  // ────────────────────────────────────────────────────────────
  Widget _buildSendButton(bool isProcessing) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0x337C3AED),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
        ),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: const Icon(
          Icons.arrow_upward_rounded,
          size: 19,
          color: Color(0xFFF1F5F9),
        ),
        tooltip: 'Send',
        onPressed: isProcessing ? null : _handleSend,
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // Active Listening Wave Strip
  // ────────────────────────────────────────────────────────────
  Widget _buildListeningWaveStrip() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x3322D3EE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF22D3EE).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Color(0xFF22D3EE),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'LISTENING — Speak your inquiry',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: const Color(0xFF22D3EE),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingStrip() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x338B5CF6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 1.8,
              color: Color(0xFFA78BFA),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'THINKING — Consulting inventory...',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: const Color(0xFFA78BFA),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // Speaking Indicator Pill
  // ────────────────────────────────────────────────────────────
  Widget _buildSpeakingIndicator() {
    return GestureDetector(
      onTap: widget.onStopSpeaking,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0x3306B6D4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF22D3EE).withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.stop_circle_rounded, size: 13, color: AppColors.danger),
            const SizedBox(width: 5),
            Text(
              'MIRA IS SPEAKING',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: const Color(0xFF22D3EE),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // Subtle Language Selector (EN | தமிழ் | Auto)
  // ────────────────────────────────────────────────────────────
  Widget _buildSubtleLanguageSelector() {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0x2B1A0A44),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x448B5CF6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLangOption(MiraLanguage.auto, 'Auto'),
          _buildLangOption(MiraLanguage.english, 'EN'),
          _buildLangOption(MiraLanguage.tamil, 'தமிழ்'),
        ],
      ),
    );
  }

  Widget _buildLangOption(MiraLanguage lang, String label) {
    final isSelected = widget.language == lang;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onSelectLanguage(lang);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF7C3AED).withValues(alpha: 0.35) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.7))
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? const Color(0xFFF1F5F9) : const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // Voice ON / OFF Toggle
  // ────────────────────────────────────────────────────────────
  Widget _buildVoiceModeToggle() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onToggleVoice();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: widget.isVoiceEnabled
              ? const Color(0xFF7C3AED).withValues(alpha: 0.22)
              : const Color(0x221E0B4B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.isVoiceEnabled
                ? const Color(0xFF8B5CF6).withValues(alpha: 0.45)
                : const Color(0x448B5CF6),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.isVoiceEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              size: 13,
              color: widget.isVoiceEnabled ? const Color(0xFF22D3EE) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 5),
            Text(
              widget.isVoiceEnabled ? 'Voice ON' : 'Voice OFF',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: widget.isVoiceEnabled ? const Color(0xFFF1F5F9) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
