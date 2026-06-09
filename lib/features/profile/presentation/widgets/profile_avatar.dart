import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/services/haptic_service.dart';
import 'package:chronyx/features/profile/presentation/providers/profile_avatar_provider.dart';
import 'package:chronyx/core/widgets/press_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tappable profile avatar shown beside the greeting. The character glyph
/// renders with no enclosing circle/square — just a subtle press target.
///
/// Tapping opens [showAvatarPicker] so the user can choose an app-defined
/// character.
class ProfileAvatar extends ConsumerWidget {
  const ProfileAvatar({super.key, this.size = 40});

  /// Diameter of the tap target. The glyph scales to ~0.7 of this.
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glyph = ref.watch(profileAvatarProvider);

    return Semantics(
      button: true,
      label: 'Change profile avatar',
      child: InkWell(
        onTap: () {
          ref.read(hapticServiceProvider).selectionClick();
          showAvatarPicker(context, ref);
        },
        borderRadius: BorderRadius.circular(size),
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: Text(
              glyph,
              style: TextStyle(fontSize: size * 0.72, height: 1.0),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet to pick an app-defined avatar character.
Future<void> showAvatarPicker(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AvatarPickerSheet(ref: ref),
  );
}

class _AvatarPickerSheet extends StatelessWidget {
  const _AvatarPickerSheet({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final selected = ref.watch(profileAvatarProvider);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXxl),
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Grab handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Choose your character',
            style: textTheme.titleLarge?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pick an avatar for your home screen.',
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: ProfileAvatars.all.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              final glyph = ProfileAvatars.all[index];
              final isSelected = glyph == selected;
              return _AvatarTile(
                glyph: glyph,
                isSelected: isSelected,
                onTap: () {
                  ref.read(hapticServiceProvider).selectionClick();
                  ref.read(profileAvatarProvider.notifier).select(glyph);
                  Navigator.of(context).pop();
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AvatarTile extends StatelessWidget {
  const _AvatarTile({
    required this.glyph,
    required this.isSelected,
    required this.onTap,
  });

  final String glyph;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PressScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isSelected
              ? scheme.primary.withValues(alpha: 0.16)
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(
            color: isSelected ? scheme.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Text(glyph, style: const TextStyle(fontSize: 24)),
      ),
    );
  }
}
