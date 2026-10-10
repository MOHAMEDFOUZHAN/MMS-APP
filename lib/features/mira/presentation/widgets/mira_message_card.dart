import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/mira_state.dart';

/// Futuristic Glass Message Card for MIRA Conversations
/// Avoids standard chat bubbles; utilizes sleek floating glass panels with glowing neon accents.
class MiraMessageCard extends StatelessWidget {
  final MiraMessage message;
  final bool isSpeakingThis;
  final VoidCallback? onPlayVoice;
  final VoidCallback? onStopVoice;

  const MiraMessageCard({
    super.key,
    required this.message,
    this.isSpeakingThis = false,
    this.onPlayVoice,
    this.onStopVoice,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isUser) {
      return _buildUserGlassPanel(context);
    }
    return _buildMiraResponsePanel(context);
  }

  // ────────────────────────────────────────────────────────────
  // User Message: Small Right-Aligned Glass Panel
  // ────────────────────────────────────────────────────────────
  Widget _buildUserGlassPanel(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxPanelWidth = screenWidth >= 600 ? 480.0 : screenWidth * 0.82;

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        constraints: BoxConstraints(maxWidth: maxPanelWidth),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0x66180838), // Translucent deep violet glass
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          ),
          border: Border.all(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.38),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'YOU',
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: const Color(0xFF8B5CF6),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.person_outline_rounded,
                  size: 11,
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.8),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              message.text,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: const Color(0xFFF8FAFC),
                height: 1.42,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // MIRA Response: Transparent Glowing Glass Content Area
  // ────────────────────────────────────────────────────────────
  Widget _buildMiraResponsePanel(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxPanelWidth = screenWidth >= 600 ? 680.0 : screenWidth * 0.94;
    final struct = message.structuredData;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
        constraints: BoxConstraints(maxWidth: maxPanelWidth),
        decoration: BoxDecoration(
          color: const Color(0xE60D0422), // Cosmic dark violet glass
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSpeakingThis
                ? const Color(0xFF22D3EE).withValues(alpha: 0.75)
                : const Color(0xFF7C3AED).withValues(alpha: 0.35),
            width: isSpeakingThis ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isSpeakingThis
                  ? const Color(0xFF22D3EE).withValues(alpha: 0.16)
                  : const Color(0xFF7C3AED).withValues(alpha: 0.10),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Bar: MIRA Badge + Live Language + Voice Controls
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 10, 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22D3EE).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF22D3EE).withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      size: 13,
                      color: Color(0xFF22D3EE),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'MIRA AI',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: const Color(0xFF22D3EE),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Text(
                      message.language.label,
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                  const Spacer(),

                  // Voice Speaker Play/Stop Button
                  if (isSpeakingThis)
                    IconButton(
                      icon: const Icon(Icons.stop_circle_rounded, size: 20, color: AppColors.danger),
                      tooltip: 'Stop speaking',
                      visualDensity: VisualDensity.compact,
                      onPressed: onStopVoice,
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.volume_up_rounded, size: 18, color: Color(0xFF8B5CF6)),
                      tooltip: 'Read response',
                      visualDensity: VisualDensity.compact,
                      onPressed: onPlayVoice,
                    ),
                ],
              ),
            ),

            // Message Text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                message.text,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFFF1F5F9),
                  height: 1.48,
                ),
              ),
            ),

            // Futuristic Structured HUD Cards (Inventory Context)
            if (struct != null) ...[
              const Divider(height: 16, color: Color(0x338B5CF6)),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
                child: _buildStructuredInfoHUD(context, struct),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // Futuristic Structured Inventory HUD
  // ────────────────────────────────────────────────────────────
  Widget _buildStructuredInfoHUD(BuildContext context, Map<String, dynamic> data) {
    final title = data['title']?.toString() ?? data['description']?.toString();
    final status = data['status']?.toString();
    final tools = data['tools_ready'] as List<dynamic>?;
    final mainValue = data['quantity'] ?? data['main_value'];
    final unit = data['unit']?.toString() ?? '';
    final lots = data['lots_count'];
    final oldestLot = data['oldest_lot']?.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Text(
            title.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: const Color(0xFF8B5CF6),
            ),
          ),

        if (mainValue != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0x331E0B4B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF22D3EE).withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$mainValue',
                  style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: const Color(0xFF22D3EE),
                  ),
                ),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(
                    unit,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFCBD5E1),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],

        if (lots != null) ...[
          const SizedBox(height: 6),
          Text(
            'Available across $lots batch/lot(s)',
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
          ),
        ],

        if (oldestLot != null) ...[
          const SizedBox(height: 4),
          Text(
            'Oldest Lot: $oldestLot',
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
          ),
        ],

        if (status != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline, size: 13, color: AppColors.warning),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    status,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        if (tools != null && tools.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'INVENTORY SYSTEM TOOLS:',
            style: GoogleFonts.inter(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: tools.map((t) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0x331E0B4B),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
                ),
                child: Text(
                  t.toString(),
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFFCBD5E1),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
