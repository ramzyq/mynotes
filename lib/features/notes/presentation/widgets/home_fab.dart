import 'package:flutter/material.dart';

class HomeFab extends StatelessWidget {
  final VoidCallback? onPressed;

  const HomeFab({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 40,
      right: 40,
      bottom: 36,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFA78BFA), Color(0xFF7C5CF5)]),
              boxShadow: const [BoxShadow(color: Color(0x6B7C5CF5), blurRadius: 30, offset: Offset(0, 10)), BoxShadow(color: Color(0x337C5CF5), blurRadius: 6, offset: Offset(0, 2))],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
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
                Text(
                  'New note',
                  style: TextStyle(color: Colors.white, fontFamily: 'Geist', fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.25),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
