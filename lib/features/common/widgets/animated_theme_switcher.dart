// lib/features/common/widgets/animated_theme_switcher.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Needed for Haptic Feedback
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/theme_provider.dart';

class AnimatedThemeSwitcher extends ConsumerWidget {
  const AnimatedThemeSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the themeProvider so widget rebuilds on theme change
    ref.watch(themeProvider);

    // Determine actual brightness from ThemeData to respect system mode
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    final notifier = ref.read(themeProvider.notifier);

    // Premium Color Palettes
    final bgColor = isDark
        ? Colors.indigoAccent.withValues(alpha: 0.15)
        : Colors.orange.withValues(alpha: 0.15);

    final borderColor = isDark
        ? Colors.indigoAccent.withValues(alpha: 0.4)
        : Colors.orange.withValues(alpha: 0.4);

    final iconColor = isDark
        ? Colors.indigoAccent.shade100
        : Colors.orange.shade700;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: () {
          // Premium micro-interaction: Subtle vibration on tap
          HapticFeedback.lightImpact();

          if (isDark) {
            notifier.setTheme(ThemeMode.light);
          } else {
            notifier.setTheme(ThemeMode.dark);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Animated Icon
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                switchInCurve: Curves.elasticOut, // Gives a satisfying "pop"
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return RotationTransition(
                    turns: Tween<double>(begin: 0.5, end: 1.0).animate(animation),
                    child: FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: animation,
                        child: child,
                      ),
                    ),
                  );
                },
                child: isDark
                    ? Icon(Icons.nightlight_round, key: const ValueKey('moon'), color: iconColor, size: 20)
                    : Icon(Icons.wb_sunny_rounded, key: const ValueKey('sun'), color: iconColor, size: 20),
              ),
              const SizedBox(width: 8),

              // 2. Animated Text Label
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                          begin: const Offset(0.0, 0.2),
                          end: Offset.zero
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  isDark ? 'Dark' : 'Light',
                  key: ValueKey(isDark ? 'dark_text' : 'light_text'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: iconColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}