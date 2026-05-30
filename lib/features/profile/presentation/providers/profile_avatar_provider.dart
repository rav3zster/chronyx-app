import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App-defined profile avatars. These are expressive character glyphs that
/// render cleanly with no circle/square background — the glyph *is* the avatar.
///
/// Kept in-memory (like the theme selection) since the app has no local
/// persistence layer yet.
class ProfileAvatars {
  const ProfileAvatars._();

  /// Ordered list shown in the picker. Grouped loosely: creatures, then
  /// cosmic/abstract characters.
  static const List<String> all = <String>[
    '🦊',
    '🐼',
    '🐯',
    '🦁',
    '🐶',
    '🐱',
    '🐻',
    '🐨',
    '🐸',
    '🦉',
    '🐵',
    '🦄',
    '🐲',
    '🦅',
    '🐺',
    '🦋',
    '🐙',
    '🦖',
    '👾',
    '🤖',
    '👽',
    '🚀',
    '⭐',
    '🔥',
  ];

  /// Default avatar for a fresh user.
  static const String fallback = '🦊';
}

class ProfileAvatarNotifier extends StateNotifier<String> {
  ProfileAvatarNotifier() : super(ProfileAvatars.fallback);

  void select(String glyph) => state = glyph;
}

/// Currently selected profile avatar glyph.
final profileAvatarProvider =
    StateNotifierProvider<ProfileAvatarNotifier, String>(
      (ref) => ProfileAvatarNotifier(),
    );
