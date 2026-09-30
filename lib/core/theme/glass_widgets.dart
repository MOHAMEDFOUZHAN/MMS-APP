import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import 'app_theme.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final VoidCallback? onTap;
  final double blur;
  final List<BoxShadow>? boxShadow;
  final Color? accentColor;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = AppTheme.radiusLg,
    this.backgroundColor,
    this.borderColor,
    this.onTap,
    this.blur = 20.0,
    this.boxShadow,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? const Color(0xCC1E293B),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ??
              (accentColor != null
                  ? accentColor!.withValues(alpha: 0.35)
                  : AppColors.glassBorder),
          width: 1,
        ),
        boxShadow: boxShadow ??
            (accentColor != null
                ? AppColors.neonGlow(accentColor!)
                : AppColors.glassShadow),
      ),
      child: child,
    );

    if (margin != null) {
      card = Padding(padding: margin!, child: card);
    }

    if (onTap != null) {
      card = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        splashColor: AppColors.primary.withValues(alpha: 0.15),
        highlightColor: AppColors.primary.withValues(alpha: 0.05),
        child: card,
      );
    }

    return card;
  }
}

class GlassButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;
  final bool isLoading;
  final bool isOutlined;
  final double? width;
  final double height;
  final EdgeInsetsGeometry? padding;
  final double? fontSize;
  final double? iconSize;
  final double? spacing;

  const GlassButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.color = AppColors.primary,
    this.isLoading = false,
    this.isOutlined = false,
    this.width,
    this.height = 42,
    this.padding,
    this.fontSize,
    this.iconSize,
    this.spacing,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = onPressed == null ? AppColors.textMuted : color;
    final effectivePadding = padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 6);

    if (isOutlined) {
      return SizedBox(
        width: width,
        height: height,
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: effectiveColor.withValues(alpha: 0.6), width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            backgroundColor: effectiveColor.withValues(alpha: 0.08),
            padding: effectivePadding,
            minimumSize: Size(width ?? 0, height),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: _buildChild(context, effectiveColor),
        ),
      );
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        boxShadow: onPressed == null
            ? null
            : [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: effectiveColor,
          disabledBackgroundColor: const Color(0x331E293B),
          elevation: 0,
          padding: effectivePadding,
          minimumSize: Size(width ?? 0, height),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
        ),
        child: _buildChild(context, Colors.white),
      ),
    );
  }

  Widget _buildChild(BuildContext context, Color textColor) {
    if (isLoading) {
      return SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(textColor),
        ),
      );
    }

    final textWidget = Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      style: GoogleFonts.inter(
        color: textColor,
        fontWeight: FontWeight.w700,
        fontSize: fontSize ?? 13.5,
      ),
    );

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: iconSize ?? 17, color: textColor),
          SizedBox(width: spacing ?? 6),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: textWidget,
            ),
          ),
        ],
      );
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.center,
      child: textWidget,
    );
  }
}

class NeonPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool isSelected;

  const NeonPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isSelected ? 0.25 : 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: isSelected ? 0.7 : 0.3),
          width: 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 10,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: content,
      );
    }

    return content;
  }
}

class AmbientBackground extends StatelessWidget {
  final Widget child;

  const AmbientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.background,
              Color(0xFF131B36),
              AppColors.backgroundDarker,
            ],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Subtle radial purple ambient glow top-right
            Positioned(
              top: -100,
              right: -100,
              child: IgnorePointer(
                child: Container(
                  width: 350,
                  height: 350,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Subtle cyan glow bottom-left
            Positioned(
              bottom: -80,
              left: -80,
              child: IgnorePointer(
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.accent.withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}
