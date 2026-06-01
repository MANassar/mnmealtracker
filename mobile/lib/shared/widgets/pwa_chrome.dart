import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

Color providerColor(BuildContext context, String? provider) {
  final c = context.appColors;
  if (provider == 'anthropic') return c.accent;
  if (provider == 'user' || provider == 'manual') return c.plum;
  return c.oai;
}

Color providerBg(BuildContext context, String? provider) =>
    providerColor(context, provider).withValues(alpha: 0.12);

String providerLabel(String? provider) {
  if (provider == 'anthropic') return 'Claude';
  if (provider == 'openai') return 'GPT-4o';
  if (provider == 'user' || provider == 'manual') return 'User';
  return 'Server';
}

class PwaTopBar extends StatelessWidget {
  final String? eyebrow;
  final String? title;
  final VoidCallback? onSettings;
  final Widget? leading;
  final Widget? trailing;
  final bool showBorder;

  const PwaTopBar({
    super.key,
    this.eyebrow,
    this.title,
    this.onSettings,
    this.leading,
    this.trailing,
    this.showBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        decoration: BoxDecoration(
          border:
              showBorder ? Border(bottom: BorderSide(color: c.border)) : null,
        ),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Text(
                title ?? eyebrow ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: title != null ? c.text : c.muted,
                  fontFamily: title != null ? 'Playfair Display' : null,
                  fontSize: title != null ? 24 : 10,
                  fontWeight: title != null ? FontWeight.w400 : FontWeight.w600,
                  letterSpacing: title != null ? 0 : 1.8,
                ),
              ),
            ),
            trailing ??
                (onSettings == null
                    ? const SizedBox.shrink()
                    : IconButton(
                        onPressed: onSettings,
                        icon: Icon(Icons.settings_outlined, color: c.muted),
                        style: IconButton.styleFrom(
                          minimumSize: const Size(44, 44),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      )),
          ],
        ),
      ),
    );
  }
}

class CalorieRing extends StatelessWidget {
  final double consumed;
  final double target;

  const CalorieRing({
    super.key,
    required this.consumed,
    required this.target,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final over = target > 0 && consumed > target;
    return SizedBox(
      width: 144,
      height: 144,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size.square(144),
            painter: _RingPainter(
              pct: target <= 0 ? 0 : (consumed / target).clamp(0.0, 1.0),
              track: c.card,
              fill: over ? c.danger : c.accent,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                consumed.round().toString(),
                style: TextStyle(
                  color: over ? c.danger : c.text,
                  fontFamily: 'Playfair Display',
                  fontSize: 28,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '/ ${target.round()} kcal',
                style: TextStyle(
                  color: over ? c.danger : c.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double pct;
  final Color track;
  final Color fill;

  const _RingPainter({
    required this.pct,
    required this.track,
    required this.fill,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 9.0;
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * (56 / 144);
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    final fillPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = fill;

    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * pct,
      false,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      pct != oldDelegate.pct ||
      track != oldDelegate.track ||
      fill != oldDelegate.fill;
}

class MacroProgressBar extends StatelessWidget {
  final String label;
  final double value;
  final double max;
  final Color color;

  const MacroProgressBar({
    super.key,
    required this.label,
    required this.value,
    required this.max,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final pct = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    final over = max > 0 && value > max;
    final labelColor = over ? c.danger : c.muted;
    final valueColor = over ? c.danger : c.text;
    final fillColor = over ? c.danger : color;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
              ),
              Text(
                '${value.toStringAsFixed(0)}g',
                style: TextStyle(
                  color: valueColor,
                  fontSize: 11,
                  fontFamily: 'DM Mono',
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 3,
              backgroundColor: c.card,
              valueColor: AlwaysStoppedAnimation(fillColor),
            ),
          ),
        ],
      ),
    );
  }
}

class PwaButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final bool filled;
  final double height;

  const PwaButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.color,
    this.filled = true,
    this.height = 46,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return SizedBox(
      height: height,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: filled ? color : Colors.transparent,
          foregroundColor: filled ? AppColors.darkBg : color,
          disabledBackgroundColor: c.muted,
          disabledForegroundColor: c.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(height >= 50 ? 14 : 10),
            side: BorderSide(color: filled ? color : color),
          ),
          padding: EdgeInsets.symmetric(horizontal: height < 40 ? 8 : 14),
          textStyle: TextStyle(
            fontSize: height < 40 ? 11 : 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
