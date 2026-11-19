import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oreguru/core/constants/app_colors.dart';
import 'package:oreguru/core/widgets/clay_container.dart';

/// 누를 때 점토가 말랑하게 들어가는(scale 0.96 + 햅틱 피드백) 클레이 버튼
/// 기본 borderRadius는 Figma `node 2:149`/`4:361`/`4:363`의 18px(`AppRadii.buttonInput`) 적용
class ClayButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final ClaySurfaceVariant variant;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final double? width;
  final double? height;
  final Border? border;

  const ClayButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.variant = ClaySurfaceVariant.accent,
    this.borderRadius = AppRadii.buttonInput,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
    this.width,
    this.height,
    this.border,
  });

  @override
  State<ClayButton> createState() => _ClayButtonState();
}

class _ClayButtonState extends State<ClayButton> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed == null) return;
    setState(() => _isPressed = true);
    HapticFeedback.lightImpact();
  }

  void _handleTapUp(TapUpDetails details) {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  void _handleTapCancel() {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null;

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onPressed,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: isDisabled ? 0.55 : 1.0,
        child: AnimatedScale(
          scale: _isPressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOutBack,
          child: ClayContainer(
            variant: widget.variant,
            borderRadius: widget.borderRadius,
            padding: widget.padding,
            width: widget.width,
            height: widget.height,
            isPressed: _isPressed,
            border: widget.border,
            child: Center(child: widget.child),
          ),
        ),
      ),
    );
  }
}
