import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../presentation/providers/app_providers.dart';
import '../../application/mira_controller.dart';
import '../../domain/mira_state.dart';
import '../widgets/mira_core_wave.dart';
import '../widgets/mira_cosmic_background.dart';
import '../widgets/mira_greeting_hero.dart';
import '../widgets/mira_input_bar.dart';
import '../widgets/mira_message_card.dart';

/// Benchmark MMS — MIRA AI Assistant Futuristic Interface
/// A completely original, living AI companion experience with deep cosmic atmosphere,
/// 3D orbital dynamics, sentient digital optics, and seamless conversational transitions.
class MiraPage extends ConsumerStatefulWidget {
  const MiraPage({super.key});

  @override
  ConsumerState<MiraPage> createState() => _MiraPageState();
}

class _MiraPageState extends ConsumerState<MiraPage> {
  final _scrollController = ScrollController();

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(miraControllerProvider);
    final controller = ref.read(miraControllerProvider.notifier);

    // Profile lookup for personalized greeting
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final authUser = ref.watch(currentUserProvider);
    final userName = (profile?.fullName.trim().isNotEmpty == true)
        ? profile!.fullName.trim()
        : ((profile?.username.trim().isNotEmpty == true)
            ? profile!.username.trim()
            : (authUser?.userMetadata?['name']?.toString() ??
               authUser?.userMetadata?['full_name']?.toString() ??
               authUser?.email?.split('@').first));

    // Scroll down whenever message count changes
    ref.listen<MiraState>(miraControllerProvider, (prev, next) {
      if (prev?.messages.length != next.messages.length) {
        _scrollToBottom();
      }
    });

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTablet = screenWidth >= 600;
    final hasMessages = state.messages.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF050019),
      resizeToAvoidBottomInset: true,
      body: MiraCosmicBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // 1. Futuristic Header Bar
              _buildHeaderBar(context, state, controller),

              // 2. Main Center Body (Dynamic Transition between Hero & Chat)
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isTablet ? 840 : double.infinity,
                    ),
                    child: hasMessages
                        ? _buildConversationLayout(context, state, controller, isTablet)
                        : _buildHeroEmptyLayout(context, state, controller, userName, isTablet),
                  ),
                ),
              ),

              // 3. Futuristic Glass Input Bar
              MiraInputBar(
                mode: state.mode,
                language: state.language,
                isVoiceEnabled: state.isVoiceEnabled,
                audioAmplitude: state.audioAmplitude,
                onSendText: controller.submitTextQuery,
                onMicTap: () {
                  if (state.mode == MiraStateMode.listening) {
                    controller.stopVoiceInput();
                  } else {
                    controller.startVoiceInput();
                  }
                },
                onSelectLanguage: controller.setLanguage,
                onToggleVoice: controller.toggleVoiceMode,
                onStopSpeaking: controller.stopSpeaking,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // Futuristic Header Bar
  // ────────────────────────────────────────────────────────────
  Widget _buildHeaderBar(
    BuildContext context,
    MiraState state,
    MiraController controller,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0x66090022),
        border: Border(
          bottom: BorderSide(color: Color(0x228B5CF6), width: 1.0),
        ),
      ),
      child: Row(
        children: [
          // Back Button
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: Color(0xFFE2E8F0),
            ),
            tooltip: 'Return to MMS',
            onPressed: () => Navigator.of(context).pop(),
          ),

          const SizedBox(width: 4),

          // MIRA AI Hologram Icon
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF22D3EE).withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF22D3EE).withValues(alpha: 0.35),
              ),
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 14,
              color: Color(0xFF22D3EE),
            ),
          ),

          const SizedBox(width: 10),

          // Title & Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'MIRA',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.0,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        'AI OS',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: const Color(0xFFA78BFA),
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Benchmark MMS Inventory Companion',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),

          // Live State Pill
          _buildLiveStatePill(state.mode),

          // Reset Session Button
          IconButton(
            icon: const Icon(
              Icons.restart_alt_rounded,
              size: 20,
              color: Color(0xFF94A3B8),
            ),
            tooltip: 'New conversation',
            onPressed: () {
              HapticFeedback.lightImpact();
              controller.clearSession();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLiveStatePill(MiraStateMode mode) {
    final (label, color) = switch (mode) {
      MiraStateMode.idle => ('Ready', const Color(0xFF10B981)),
      MiraStateMode.listening => ('Listening', const Color(0xFF22D3EE)),
      MiraStateMode.processing => ('Thinking', const Color(0xFFA78BFA)),
      MiraStateMode.speaking => ('Speaking', const Color(0xFF38BDF8)),
      MiraStateMode.responding => ('Active', const Color(0xFFEC4899)),
      MiraStateMode.error => ('Alert', AppColors.danger),
    };

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // Initial Hero State (Empty Conversation)
  // ────────────────────────────────────────────────────────────
  Widget _buildHeroEmptyLayout(
    BuildContext context,
    MiraState state,
    MiraController controller,
    String? userName,
    bool isTablet,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 32 : 16,
            vertical: 16,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - 32,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Large Living MIRA AI Entity & Orbital Visual
                MiraCoreWave(
                  mode: state.mode,
                  audioAmplitude: state.audioAmplitude,
                  size: isTablet ? 260 : 210,
                  showLabel: true,
                  onCoreTap: () {
                    if (state.mode == MiraStateMode.speaking) {
                      controller.stopSpeaking();
                    } else if (state.mode == MiraStateMode.listening) {
                      controller.stopVoiceInput();
                    } else {
                      controller.startVoiceInput();
                    }
                  },
                ),

                const SizedBox(height: 18),

                // 2. Premium Greeting & Quick Action Chips
                MiraGreetingHero(
                  userName: userName,
                  onSelectAction: controller.submitTextQuery,
                ),

                // 3. Error state banner (if applicable)
                if (state.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 16, color: AppColors.danger),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            state.errorMessage!,
                            style: const TextStyle(fontSize: 12, color: AppColors.danger),
                          ),
                        ),
                        TextButton(
                          onPressed: controller.retry,
                          child: const Text('Try Again', style: TextStyle(fontSize: 12, color: Color(0xFF22D3EE))),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ────────────────────────────────────────────────────────────
  // Active Conversation State (Continuous Transition)
  // ────────────────────────────────────────────────────────────
  Widget _buildConversationLayout(
    BuildContext context,
    MiraState state,
    MiraController controller,
    bool isTablet,
  ) {
    return Column(
      children: [
        // Compact Top MIRA Companion Bar (Continuously alive)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              MiraCoreWave(
                mode: state.mode,
                audioAmplitude: state.audioAmplitude,
                size: 96,
                showLabel: false,
                onCoreTap: () {
                  if (state.mode == MiraStateMode.speaking) {
                    controller.stopSpeaking();
                  } else if (state.mode == MiraStateMode.listening) {
                    controller.stopVoiceInput();
                  } else {
                    controller.startVoiceInput();
                  }
                },
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      state.statusMessage,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: state.mode == MiraStateMode.error
                            ? AppColors.danger
                            : const Color(0xFF22D3EE),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tap companion or mic below to speak',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 1, color: Color(0x228B5CF6)),

        // Message Feed
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 24 : 14,
              vertical: 12,
            ),
            physics: const BouncingScrollPhysics(),
            itemCount: state.messages.length,
            itemBuilder: (context, index) {
              final msg = state.messages[index];
              return MiraMessageCard(
                message: msg,
                isSpeakingThis: state.currentSpokenMessageId == msg.id,
                onPlayVoice: () => controller.submitTextQuery(msg.text),
                onStopVoice: controller.stopSpeaking,
              );
            },
          ),
        ),
      ],
    );
  }
}
