// lib/features/common/widgets/animated_theme_switcher.dart
import 'package:flutter/material.dart';
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

    return IconButton(
      tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
      onPressed: () {
        if (isDark) {
          notifier.setTheme(ThemeMode.light);
        } else {
          notifier.setTheme(ThemeMode.dark);
        }
      },
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        transitionBuilder: (child, animation) {
          final rotateAnim = Tween<double>(begin: 0.75, end: 1.0).animate(animation);
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
            ? const Icon(
          Icons.dark_mode_outlined,
          key: ValueKey('moon'),
        )
            : const Icon(
          Icons.light_mode_outlined,
          key: ValueKey('sun'),
          color: Colors.orangeAccent,
        ),
      ),
    );
  }
}
