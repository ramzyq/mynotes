import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

class HomeFab extends StatelessWidget {
  final VoidCallback? onPressed;

  const HomeFab({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 36,
      child: Center(
        child: GlassButton.custom(
          onTap: onPressed ?? () {},
          enabled: onPressed != null,
          width: 224,
          height: 54,
          glowColor: const Color(0xFF7C5CF5),
          glowRadius: 1.4,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), shape: BoxShape.circle),
                child: const Icon(Icons.add, size: 14, color: Colors.white),
              ),
              const SizedBox(width: 9),
              const Text(
                'Start writing',
                style: TextStyle(color: Colors.white, fontFamily: 'Geist', fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: -0.25),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
