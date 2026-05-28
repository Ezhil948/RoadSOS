import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_theme.dart';

class SlideToConfirm extends StatefulWidget {
  final VoidCallback onConfirm;
  final String label;

  const SlideToConfirm({
    super.key,
    required this.onConfirm,
    this.label = "SLIDE TO ARRIVE >>",
  });

  @override
  State<SlideToConfirm> createState() => _SlideToConfirmState();
}

class _SlideToConfirmState extends State<SlideToConfirm> with SingleTickerProviderStateMixin {
  double _dragPosition = 0;
  bool _confirmed = false;
  late AnimationController _animController;
  final double _thumbSize = 56.0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animController.addListener(() {
      setState(() {
        _dragPosition = _animController.value * _dragPosition;
      });
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details, double maxWidth) {
    if (_confirmed) return;
    setState(() {
      _dragPosition += details.delta.dx;
      if (_dragPosition < 0) _dragPosition = 0;
      if (_dragPosition > maxWidth - _thumbSize) {
        _dragPosition = maxWidth - _thumbSize;
      }
    });
  }

  void _onDragEnd(DragEndDetails details, double maxWidth) {
    if (_confirmed) return;
    if (_dragPosition > (maxWidth - _thumbSize) * 0.9) {
      setState(() {
        _confirmed = true;
        _dragPosition = maxWidth - _thumbSize;
      });
      HapticFeedback.heavyImpact();
      widget.onConfirm();
    } else {
      _animController.forward(from: 0).then((_) {
        _animController.reset();
        setState(() {
          _dragPosition = 0;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final opacity = 1.0 - (_dragPosition / (maxWidth - _thumbSize));
        return Container(
          height: _thumbSize,
          decoration: BoxDecoration(
            color: kDarkBorder,
            borderRadius: BorderRadius.circular(_thumbSize / 2),
          ),
          child: Stack(
            children: [
              Center(
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Text(
                    widget.label,
                    style: AppTheme.monoMd.copyWith(color: kDarkText),
                  ),
                ),
              ),
              Positioned(
                left: _dragPosition,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) => _onDragUpdate(details, maxWidth),
                  onHorizontalDragEnd: (details) => _onDragEnd(details, maxWidth),
                  child: Container(
                    height: _thumbSize,
                    width: _thumbSize,
                    decoration: BoxDecoration(
                      color: kAccentGreen,
                      borderRadius: BorderRadius.circular(_thumbSize / 2),
                    ),
                    child: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 24),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
