import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Premium "Powered by MAPLE PRO" branding footer with Calama typography and Maple Pro logo.
class MapleProFooter extends StatelessWidget {
  final bool compact;
  final bool showLogo;
  final Color? textColor;
  final Color? mapleColor;
  final EdgeInsetsGeometry padding;

  const MapleProFooter({
    super.key,
    this.compact = false,
    this.showLogo = true,
    this.textColor,
    this.mapleColor,
    this.padding = const EdgeInsets.symmetric(vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
          if (showLogo) ...[
            Container(
              width: compact ? 18 : 22,
              height: compact ? 18 : 22,
              alignment: Alignment.center,
              child: Image.asset(
                'assets/images/maple_pro_logo.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.eco_rounded,
                  size: 16,
                  color: Color(0xFFF59E0B),
                ),
              ),
            ),
            const SizedBox(width: 7),
          ],
          Text(
            'Powered by ',
            style: GoogleFonts.inter(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.4,
              color: textColor ?? const Color(0xFF94A3B8),
            ),
          ),
          Text(
            'MAPLE PRO',
            style: TextStyle(
              fontFamily: 'Calama',
              fontSize: compact ? 13 : 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: mapleColor ?? const Color(0xFFF59E0B),
            ),
          ),
        ],
      ),
    ),
  );
  }
}
