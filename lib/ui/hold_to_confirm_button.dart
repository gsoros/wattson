import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../util/app_log.dart';

// ---------------------------------------------------------------------------
// Hold-to-confirm button
// ---------------------------------------------------------------------------
//
// Used for destructive / easy-to-miss actions (pause, stop, resume) so they
// can't be triggered by an accidental tap. The user must press and hold; an
// indicator fills over ~2.5 s and the action only fires once the indicator
// completes. Releasing early cancels.

class HoldToConfirmButton extends StatefulWidget {
  const HoldToConfirmButton({
    required Key key,
    required this.icon,
    required this.backgroundColor,
    required this.onConfirmed,
    this.iconColor = Colors.white,
    this.tooltip,
  }) : super(key: key);

  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback onConfirmed;
  final String? tooltip;

  @override
  State<HoldToConfirmButton> createState() => _HoldToConfirmButtonState();
}

class _HoldToConfirmButtonState extends State<HoldToConfirmButton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final _buttonKey = GlobalKey();
  final _stackKey = GlobalKey();
  //static final _log = AppLog.logFor('_HoldToConfirmButtonState');

  /// True once a full hold completes, so the trailing tap (which fires after
  /// the finger lifts) doesn't also pop the "press and hold" hint.
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500))..addStatusListener(_onStatus);
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _confirmed = true;
      widget.onConfirmed();
    }
  }

  void _start() {
    _confirmed = false;
    _controller.forward();
  }

  void _cancel() {
    switch (_controller.status) {
      case AnimationStatus.forward:
        _controller.reverse();
      case AnimationStatus.completed:
        _controller.value = 0; // reset after the user releases
      case AnimationStatus.reverse:
      case AnimationStatus.dismissed:
        break;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    //final screenWidth = MediaQuery.of(context).size.width;
    //final screenHeight = MediaQuery.of(context).size.height;

    return Semantics(
      button: true,
      label: widget.tooltip,
      child: GestureDetector(
        onTapDown: (_) => _start(),
        onTapUp: (_) => _cancel(),
        onTapCancel: () => _cancel(),
        onTap: () {
          // A quick tap (no hold) shouldn't fire the action — instead hint
          // the user that a press-and-hold is required. Skip the hint when a
          // full hold just completed (the action already fired).
          if (_confirmed) return;
          final hint = widget.tooltip?.replaceFirst('Hold to', 'Press and hold to');
          if (hint != null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(hint), duration: const Duration(seconds: 1)));
          }
        },
        child: SizedBox(
          width: 72,
          height: 72,
          child: Stack(
            key: _stackKey,
            // Allow the feedback to overflow the button so a finger resting on it
            // doesn't obscure the animation.
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Draw feeback only while the user is holding.
              if (_controller.value > 0)
                // Large, obvious ring
                SizedBox(
                  width: 512,
                  height: 512,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) => CircularProgressIndicator(
                      value: _controller.value,
                      strokeWidth: 64,
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(128),
                      valueColor: AlwaysStoppedAnimation(widget.iconColor),
                    ),
                  ),
                ),
              /*
              // Cyclist animation drawn across full screen while holding.
              // Positioned + OverflowBox lets the CustomPaint escape the 52×52
              // SizedBox constraint. The canvas origin is placed at the screen's
              // top-left so global coordinates (from _getButtonCenter) map
              // directly to canvas coordinates.
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => CustomPaint(
                    size: Size(screenWidth, screenHeight),
                    painter: _CyclistPainter(progress: _controller.value, screenWidth: screenWidth, color: widget.iconColor),
                  ),
                ),
              */
              Container(
                key: _buttonKey,
                width: 90,
                height: 90,
                decoration: BoxDecoration(shape: BoxShape.circle, color: widget.backgroundColor),
                child: Icon(widget.icon, color: widget.iconColor, size: 40),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cyclist painter (stick figure riding across screen)
// Work-in-progress: not yet used.
// ---------------------------------------------------------------------------
// ignore: unused_element
class _CyclistPainter extends CustomPainter {
  _CyclistPainter({
    required this.progress,
    required this.screenWidth,
    // ignore: unused_element_parameter
    this.startX = -200.0,
    required this.color,
  });

  // ignore: unused_field
  static final _log = AppLog.logFor('_CyclistPainter');

  final double progress; // 0.0 → 1.0
  final double screenWidth;
  final double startX;
  final Color color;

  // MTB proportions (approximate, stylized)
  static const double _wheelRadius = 16.0; // ~29" wheel scaled
  static const double _bikeLength = 68.0; // wheelbase-ish
  static const double _crankLength = 14.0; // 170mm crank scaled
  static const double _thighLength = 22.0;
  static const double _shinLength = 20.0;
  static const double _torsoLength = 28.0;
  static const double _headRadius = 7.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Build an uphill slope path
    final startY = -100.0; // start above button
    final endX = screenWidth - _wheelRadius; // off right edge
    final endY = -200.0;

    final path = Path()
      ..moveTo(startX, startY)
      ..quadraticBezierTo((startX + endX) / 2, startY - 40, endX, endY); // gentle arc upward

    final pathMetrics = path.computeMetrics().toList();
    final totalLength = pathMetrics.first.length;
    final distance = progress * totalLength;

    // Get position and tangent at current progress
    final tangent = pathMetrics.first.getTangentForOffset(distance)!;
    final pos = tangent.position;
    final angle = tangent.angle * -1; // slope angle

    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(angle);

    // Pedal phase: 4 full crank rotations over the hold duration
    final pedalPhase = progress * 4 * 2 * math.pi;

    // --- Draw bike frame (MTB geometry) ---
    // Bottom bracket at origin
    final bb = Offset(0, 0);

    // Wheel centers (rear and front)
    final rearWheel = Offset(-_bikeLength * 0.44, 0);
    final frontWheel = Offset(_bikeLength * 0.56, 0);

    // Wheels with spokes
    _drawWheel(canvas, rearWheel, _wheelRadius, pedalPhase, paint);
    _drawWheel(canvas, frontWheel, _wheelRadius, pedalPhase, paint);

    // Frame tubes
    // Chainstay: rear wheel -> BB
    canvas.drawLine(rearWheel, bb, paint);
    // Seatstay: rear wheel -> seat tube top
    final seatTubeTop = Offset(-_bikeLength * 0.12, -_torsoLength * 1.1);
    canvas.drawLine(rearWheel, seatTubeTop, paint);
    // Seat tube: BB -> seat tube top
    canvas.drawLine(bb, seatTubeTop, paint);
    // Top tube: seat tube top -> head tube top
    final headTubeTop = Offset(_bikeLength * 0.35, -_torsoLength * 0.85);
    canvas.drawLine(seatTubeTop, headTubeTop, paint);
    // Down tube: BB -> head tube bottom
    final headTubeBottom = Offset(_bikeLength * 0.35, -_torsoLength * 0.45);
    canvas.drawLine(bb, headTubeBottom, paint);
    // Head tube: head tube bottom -> head tube top
    canvas.drawLine(headTubeBottom, headTubeTop, paint);
    // Fork: head tube bottom -> front wheel
    canvas.drawLine(headTubeBottom, frontWheel, paint);

    // --- Draw cyclist ---
    // Saddle position (on seat tube)
    final saddle = Offset(-_bikeLength * 0.12, -_torsoLength * 1.1);

    // Hip joint (slightly behind saddle, at saddle height)
    final hip = saddle + const Offset(-4, 0);

    // Shoulders (torso leaned forward ~35 deg from vertical)
    final torsoAngle = -math.pi / 2 + 0.6; // ~35 deg forward from vertical
    final shoulders = hip + Offset(math.cos(torsoAngle) * _torsoLength, math.sin(torsoAngle) * _torsoLength);

    // Head
    final headCenter = shoulders + Offset(math.cos(torsoAngle) * 8, math.sin(torsoAngle) * 8);
    canvas.drawCircle(headCenter, _headRadius, paint);

    // Torso
    canvas.drawLine(hip, shoulders, paint);

    // Arms to handlebars (handlebar at headTubeTop + small offset forward/up)
    final handlebar = headTubeTop + const Offset(8, -6);
    canvas.drawLine(shoulders, handlebar, paint);

    // --- Legs with proper pedal geometry ---
    // Cranks rotate around BB. Pedals stay horizontal (parallel to ground).
    // Since we rotate the whole canvas by slope angle, "horizontal" in world space
    // means we need to counter-rotate the pedal angle by the slope angle.
    // But simpler: compute pedal positions in bike frame (before slope rotation),
    // then the feet stay horizontal in world space automatically.

    // Right crank (drive side, visible)
    final rightCrankAngle = pedalPhase;
    final rightPedal = bb + Offset(math.cos(rightCrankAngle) * _crankLength, math.sin(rightCrankAngle) * _crankLength);

    // Left crank (opposite)
    final leftCrankAngle = pedalPhase + math.pi;
    final leftPedal = bb + Offset(math.cos(leftCrankAngle) * _crankLength, math.sin(leftCrankAngle) * _crankLength);

    // Solve IK for both legs: hip -> knee -> pedal (ankle)
    // Pedals stay horizontal in world space, so ankle angle = -slope angle
    // But since we're in the rotated canvas, "horizontal" = angle 0 in this coordinate system
    // So ankle is at pedal position, and we want foot to be horizontal (angle 0)

    final rightKnee = _solveKnee(hip, rightPedal, _thighLength, _shinLength, true);
    final leftKnee = _solveKnee(hip, leftPedal, _thighLength, _shinLength, false);

    // Draw right leg (thigh + shin)
    canvas.drawLine(hip, rightKnee, paint);
    canvas.drawLine(rightKnee, rightPedal, paint);
    // Pedal/foot (small horizontal line at pedal)
    _drawPedal(canvas, rightPedal, 0, paint);

    // Draw left leg
    canvas.drawLine(hip, leftKnee, paint);
    canvas.drawLine(leftKnee, leftPedal, paint);
    _drawPedal(canvas, leftPedal, 0, paint);

    canvas.restore();
  }

  void _drawWheel(Canvas canvas, Offset center, double radius, double pedalPhase, Paint paint) {
    canvas.drawCircle(center, radius, paint);
    // 6 spokes, rotating with wheel
    // Wheel rotation = distance traveled / radius. Approximate with pedal phase * gear ratio.
    final wheelRotation = pedalPhase * 2.5; // ~2.5 wheel revs per crank rev
    for (int i = 0; i < 6; i++) {
      final spokeAngle = wheelRotation + i * math.pi / 3;
      canvas.drawLine(center, center + Offset(math.cos(spokeAngle) * radius, math.sin(spokeAngle) * radius), paint);
    }
    // Tire outline (slightly larger)
    canvas.drawCircle(center, radius + 1, paint);
  }

  void _drawPedal(Canvas canvas, Offset pedalPos, double angle, Paint paint) {
    // Small horizontal pedal platform
    const pedalHalfLength = 6.0;
    canvas.drawLine(pedalPos + Offset(-pedalHalfLength, 0), pedalPos + Offset(pedalHalfLength, 0), paint);
  }

  /// 2-link IK: hip -> knee -> ankle (pedal).
  /// Returns knee position. Thigh and shin lengths can differ.
  Offset _solveKnee(Offset hip, Offset ankle, double thighLen, double shinLen, bool rightSide) {
    final dx = ankle.dx - hip.dx;
    final dy = ankle.dy - hip.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    final maxReach = thighLen + shinLen;
    final clampedDist = dist.clamp(0.001, maxReach);

    // Law of cosines: angle at knee
    final cosKnee = (thighLen * thighLen + shinLen * shinLen - clampedDist * clampedDist) / (2 * thighLen * shinLen);
    final kneeAngle = math.acos(cosKnee.clamp(-1, 1));

    // Angle from hip to ankle
    final baseAngle = math.atan2(dy, dx);
    // Knee bends forward (right leg) or backward (left leg)
    final kneeOffsetAngle = rightSide ? -kneeAngle : kneeAngle;

    return hip + Offset(math.cos(baseAngle + kneeOffsetAngle) * thighLen, math.sin(baseAngle + kneeOffsetAngle) * thighLen);
  }

  @override
  bool shouldRepaint(covariant _CyclistPainter old) => old.progress != progress || old.screenWidth != screenWidth || old.color != color;
}
