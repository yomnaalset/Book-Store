import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class BookstoreLogo extends StatelessWidget {
  final double size;
  final bool showShadow;

  const BookstoreLogo({super.key, this.size = 80, this.showShadow = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: showShadow
          ? const BoxDecoration(
              color: AppColors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            )
          : null,
      child: ClipRRect(
        borderRadius: showShadow
            ? BorderRadius.circular(size / 2)
            : BorderRadius.zero,
        child: Image.asset(
          'assets/images/new_bookstore_logo.jpg',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // Fallback to a simple colored container if image fails to load
            return Container(
              width: size,
              height: size,
              decoration: const BoxDecoration(
                color: AppColors.uranianBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.book, color: Colors.white, size: 40),
            );
          },
        ),
      ),
    );
  }
}

class AnimatedBookstoreLogo extends StatefulWidget {
  final double size;
  final bool showShadow;

  const AnimatedBookstoreLogo({
    super.key,
    this.size = 80,
    this.showShadow = true,
  });

  @override
  State<AnimatedBookstoreLogo> createState() => _AnimatedBookstoreLogoState();
}

class _AnimatedBookstoreLogoState extends State<AnimatedBookstoreLogo>
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
          child: BookstoreLogo(
            size: widget.size,
            showShadow: widget.showShadow,
          ),
        );
      },
    );
  }
}
