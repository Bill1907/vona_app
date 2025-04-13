import 'dart:ui';
import 'package:flutter/material.dart';

class AnimatedGradientBackground extends StatefulWidget {
  final bool isActive;

  const AnimatedGradientBackground({
    super.key,
    this.isActive = false,
  });

  @override
  State<AnimatedGradientBackground> createState() =>
      _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState extends State<AnimatedGradientBackground>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late AnimationController _slideController;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _slideController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat(reverse: true);

    _slideAnimation = Tween<double>(
      begin: -20.0,
      end: 20.0,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final combinedAnimation =
        Listenable.merge([_scaleAnimation, _slideAnimation]);

    return Stack(
      children: [
        Positioned(
          left: -90 + _slideAnimation.value,
          bottom: 0,
          child: AnimatedBuilder(
            animation: combinedAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: widget.isActive ? _scaleAnimation.value : 1.0,
                child: Container(
                  width: 246,
                  height: 246,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF3A70EF).withAlpha(128),
                        const Color(0xFF3A70EF).withAlpha(0),
                      ],
                      stops: const [0.3, 1.0],
                      radius: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3A70EF).withAlpha(77),
                        blurRadius: 150,
                        spreadRadius: 50,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Positioned(
          left: 104 + _slideAnimation.value,
          bottom: 124,
          child: AnimatedBuilder(
            animation: combinedAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: widget.isActive ? _scaleAnimation.value : 1.0,
                child: Container(
                  width: 191,
                  height: 191,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF9C27B0).withAlpha(84),
                        const Color(0xFF9C27B0).withAlpha(0),
                      ],
                      stops: const [0.3, 1.0],
                      radius: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF9C27B0).withAlpha(77),
                        blurRadius: 150,
                        spreadRadius: 50,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Positioned(
          right: -78 - _slideAnimation.value,
          bottom: 0,
          child: AnimatedBuilder(
            animation: combinedAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: widget.isActive ? _scaleAnimation.value : 1.0,
                child: Container(
                  width: 283,
                  height: 283,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF00BCD4).withAlpha(128),
                        const Color(0xFF00BCD4).withAlpha(0),
                      ],
                      stops: const [0.3, 1.0],
                      radius: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00BCD4).withAlpha(77),
                        blurRadius: 150,
                        spreadRadius: 50,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 33.0, sigmaY: 33.0),
            child: Container(
              color: Colors.black.withAlpha(51),
            ),
          ),
        ),
      ],
    );
  }
}
