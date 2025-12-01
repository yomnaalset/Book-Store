import 'package:flutter/material.dart';
import '../../../../../../core/constants/app_colors.dart';

class BookIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const BookIcon({super.key, this.size = 24, this.color});

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? AppColors.uranianBlue;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // Book spine
          Positioned(
            left: 0,
            top: size * 0.1,
            child: Container(
              width: size * 0.8,
              height: size * 0.8,
              decoration: BoxDecoration(
                color: iconColor,
                borderRadius: BorderRadius.circular(size * 0.05),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: size * 0.05,
                    offset: Offset(size * 0.02, size * 0.02),
                  ),
                ],
              ),
            ),
          ),
          // Book pages
          Positioned(
            left: size * 0.75,
            top: size * 0.15,
            child: Container(
              width: size * 0.2,
              height: size * 0.7,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(size * 0.03),
                  bottomRight: Radius.circular(size * 0.03),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: size * 0.02,
                    offset: Offset(size * 0.01, size * 0.01),
                  ),
                ],
              ),
            ),
          ),
          // Book title (decorative lines)
          Positioned(
            left: size * 0.1,
            top: size * 0.25,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: size * 0.5,
                  height: size * 0.05,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(size * 0.02),
                  ),
                ),
                SizedBox(height: size * 0.05),
                Container(
                  width: size * 0.4,
                  height: size * 0.05,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(size * 0.02),
                  ),
                ),
                SizedBox(height: size * 0.05),
                Container(
                  width: size * 0.3,
                  height: size * 0.05,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(size * 0.02),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AnimatedBookIcon extends StatefulWidget {
  final double size;
  final Color? color;

  const AnimatedBookIcon({super.key, this.size = 80, this.color});

  @override
  State<AnimatedBookIcon> createState() => _AnimatedBookIconState();
}

class _AnimatedBookIconState extends State<AnimatedBookIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: BookIcon(size: widget.size, color: widget.color),
        );
      },
    );
  }
}
