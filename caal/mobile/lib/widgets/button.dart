import 'package:flutter/material.dart';

/// Button shown when disconnected to start a new conversation
class Button extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isProgressing;
  final String text;

  const Button({
    super.key,
    required this.text,
    required this.onPressed,
    this.isProgressing = false,
  });

  @override
  Widget build(BuildContext ctx) => TextButton(
        onPressed: isProgressing ? null : onPressed,
        style: TextButton.styleFrom(
          backgroundColor: Theme.of(ctx).buttonTheme.colorScheme?.surface,
          foregroundColor: const Color(0xFF171717),  // Dark text to match web frontend
          // surfaceTintColor: Colors.white,
          disabledForegroundColor: const Color(0xFF171717),
          // disabledIconColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),  // More rounded to match web frontend
          ),
        ),
        child: Row(
          spacing: 15,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isProgressing)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF171717)),
                ),
              ),
            Text(
              text.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
}
