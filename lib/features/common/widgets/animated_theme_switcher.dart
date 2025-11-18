// lib/features/common/widgets/animated_theme_switcher.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/theme_provider.dart';

class AnimatedThemeSwitcher extends ConsumerWidget {
  const AnimatedThemeSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return IconButton(
      tooltip: 'Toggle ${isDark ? 'Light' : 'Dark'} Mode',
      onPressed: () {
        ref.read(themeProvider.notifier).toggleTheme(!isDark);
      },
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        transitionBuilder: (child, animation) {
          // Add a rotation and scale animation
          final rotateAnim = Tween<double>(begin: 0.5, end: 1.0).animate(animation);
          final scaleAnim = Tween<double>(begin: 0.5, end: 1.0).animate(animation);
          return RotationTransition(
            turns: rotateAnim,
            child: ScaleTransition(
              scale: scaleAnim,
              child: child,
            ),
          );
        },
        child: isDark
        // The Moon icon for dark mode
            ? const Icon(
          Icons.dark_mode_outlined,
          key: ValueKey('moon'),
        )
        // The Sun icon for light mode
            : const Icon(
          Icons.light_mode_outlined,
          key: ValueKey('sun'),
          color: Colors.orangeAccent,
        ),
      ),
    );
  }
}