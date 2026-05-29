import 'package:flutter/material.dart';

/// Circular avatar showing a user's initials on a deterministic background
/// color derived from their UID. Accepts an optional [imageUrl] for future
/// profile-photo support (null in v1) and optional presence fields for future
/// online-status indicators (null in v1).
class UserAvatarWidget extends StatelessWidget {
  final String name;
  final String uid;
  final double radius;
  final String? imageUrl;  // null in v1 — no profile images yet
  final bool? isOnline;    // null in v1 — presence not implemented
  final DateTime? lastSeen; // null in v1

  static const List<Color> _palette = [
    Color(0xFF6366F1), // Indigo
    Color(0xFF8B5CF6), // Violet
    Color(0xFFEC4899), // Pink
    Color(0xFFEF4444), // Red
    Color(0xFFF97316), // Orange
    Color(0xFF22C55E), // Green
    Color(0xFF14B8A6), // Teal
    Color(0xFF06B6D4), // Cyan
    Color(0xFF3B82F6), // Blue
    Color(0xFFF59E0B), // Amber
  ];

  const UserAvatarWidget({
    super.key,
    required this.name,
    required this.uid,
    this.radius = 22,
    this.imageUrl,
    this.isOnline,
    this.lastSeen,
  });

  static Color colorForUid(String uid) =>
      _palette[uid.hashCode.abs() % _palette.length];

  @override
  Widget build(BuildContext context) {
    final Widget avatar = imageUrl != null
        ? CircleAvatar(
            radius: radius,
            backgroundImage: NetworkImage(imageUrl!),
          )
        : CircleAvatar(
            radius: radius,
            backgroundColor: colorForUid(uid),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                color: Colors.white,
                fontSize: radius * 0.75,
                fontWeight: FontWeight.bold,
              ),
            ),
          );

    // Online indicator — reserved for v2 presence feature.
    if (isOnline == null) return avatar;

    return Stack(
      children: [
        avatar,
        PositionedDirectional(
          bottom: 0,
          end: 0,
          child: Container(
            width: radius * 0.55,
            height: radius * 0.55,
            decoration: BoxDecoration(
              color: isOnline! ? Colors.green : Colors.grey,
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.surface,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
