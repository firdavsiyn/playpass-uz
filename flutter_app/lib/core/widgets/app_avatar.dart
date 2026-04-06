import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../theme/app_theme.dart';

/// Переиспользуемый аватар с поддержкой изображения и fallback на инициалы.
///
/// Аналог shadcn Avatar: показывает [imageUrl] если задан,
/// иначе отображает первую букву [name] на градиентном фоне.
class AppAvatar extends StatelessWidget {
  /// URL изображения (из Supabase Storage, Unsplash и т.д.)
  final String? imageUrl;

  /// Имя пользователя — первая буква используется как fallback
  final String? name;

  /// Диаметр аватара (по умолчанию 40)
  final double size;

  /// Градиент фона для fallback (по умолчанию primary → primary/60%)
  final List<Color>? gradientColors;

  /// Цвет рамки (null — без рамки)
  final Color? borderColor;

  /// Толщина рамки
  final double borderWidth;

  /// Callback при нажатии
  final VoidCallback? onTap;

  const AppAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.size = 40,
    this.gradientColors,
    this.borderColor,
    this.borderWidth = 2,
    this.onTap,
  });

  // ── Presets ──────────────────────────────────────────────

  /// Маленький аватар (24px) — для списков, чатов
  const AppAvatar.small({
    super.key,
    this.imageUrl,
    this.name,
    this.gradientColors,
    this.borderColor,
    this.borderWidth = 1.5,
    this.onTap,
  }) : size = 24;

  /// Средний аватар (40px) — по умолчанию
  const AppAvatar.medium({
    super.key,
    this.imageUrl,
    this.name,
    this.gradientColors,
    this.borderColor,
    this.borderWidth = 2,
    this.onTap,
  }) : size = 40;

  /// Большой аватар (72px) — для профиля
  const AppAvatar.large({
    super.key,
    this.imageUrl,
    this.name,
    this.gradientColors,
    this.borderColor,
    this.borderWidth = 2.5,
    this.onTap,
  }) : size = 72;

  String get _initial {
    if (name != null && name!.isNotEmpty) return name![0].toUpperCase();
    return 'G';
  }

  List<Color> get _gradient =>
      gradientColors ??
      [AppTheme.primary, AppTheme.primary.withValues(alpha: 0.6)];

  double get _fontSize => (size * 0.4).clamp(10, 32);

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    Widget avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: hasImage ? null : LinearGradient(
          colors: _gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: borderColor != null
            ? Border.all(color: borderColor!, width: borderWidth)
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage ? _buildImage() : _buildFallback(),
    );

    if (onTap != null) {
      avatar = GestureDetector(onTap: onTap, child: avatar);
    }

    return avatar;
  }

  Widget _buildImage() {
    return CachedNetworkImage(
      imageUrl: imageUrl!,
      width: size,
      height: size,
      fit: BoxFit.cover,
      placeholder: (_, __) => _buildFallback(),
      errorWidget: (_, __, ___) => _buildFallback(),
    );
  }

  Widget _buildFallback() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: _gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          _initial,
          style: TextStyle(
            color: Colors.white,
            fontSize: _fontSize,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Группа аватаров с наложением (для отображения участников, команд и т.д.)
class AppAvatarGroup extends StatelessWidget {
  final List<AppAvatar> avatars;

  /// Смещение наложения (по умолчанию 0.3 от размера)
  final double overlapFraction;

  /// Максимум видимых аватаров (остальные показываются как "+N")
  final int maxVisible;

  const AppAvatarGroup({
    super.key,
    required this.avatars,
    this.overlapFraction = 0.3,
    this.maxVisible = 4,
  });

  @override
  Widget build(BuildContext context) {
    final visible = avatars.take(maxVisible).toList();
    final extra = avatars.length - maxVisible;
    final size = visible.isNotEmpty ? visible.first.size : 40.0;
    final overlap = size * overlapFraction;

    return SizedBox(
      height: size,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < visible.length; i++)
            Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : overlap * -1 + overlap),
              child: AppAvatar(
                imageUrl: visible[i].imageUrl,
                name: visible[i].name,
                size: size,
                borderColor: context.bg,
                borderWidth: 2,
              ),
            ),
          if (extra > 0)
            Padding(
              padding: EdgeInsets.only(left: overlap * -1 + overlap),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.card,
                  border: Border.all(color: context.bg, width: 2),
                ),
                child: Center(
                  child: Text(
                    '+$extra',
                    style: TextStyle(
                      color: context.text2,
                      fontSize: size * 0.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
