import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

// ═══════════════════════════════════════════════════════════════════
// NEO-BRUTALIST SNACKBAR
// A custom overlay-based notification pill with:
//   • 5 notification types (error, success, warning, info, loading)
//   • Dark/light adaptive color palettes
//   • Dynamic positioning (top or bottom)
//   • Smooth slide + fade animations
// ═══════════════════════════════════════════════════════════════════

enum NeoSnackbarType { error, success, warning, info, loading }

enum NeoSnackbarPosition { top, bottom }

class NeoSnackBar {
  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;
  static VoidCallback? _hideAction;

  /// Show a neo-brutalist pill notification.
  ///
  /// [context] — BuildContext (must have an Overlay ancestor).
  /// [message] — The text to display.
  /// [type]    — Determines color palette and icon.
  /// [position] — Whether to slide in from top or bottom.
  /// [duration] — Auto-dismiss delay. Pass `null` for loading to persist.
  static void show(
    BuildContext context, {
    required String message,
    NeoSnackbarType type = NeoSnackbarType.info,
    NeoSnackbarPosition position = NeoSnackbarPosition.bottom,
    Duration? duration = const Duration(seconds: 3),
  }) {
    // Dismiss any existing notification instantly
    dismiss();

    final overlay = Overlay.of(context);
    final isDark = AppColors.isDark(context);
    final colors = _getColors(type, isDark);
    final mediaQuery = MediaQuery.of(context);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _NeoSnackbarWidget(
        message: message,
        type: type,
        position: position,
        colors: colors,
        isDark: isDark,
        mediaQuery: mediaQuery,
        onDismiss: () {
          _removeEntry();
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);

    // Auto-dismiss (skip for loading type if duration is null)
    if (duration != null) {
      _dismissTimer = Timer(duration, () {
        dismiss();
      });
    }
  }

  /// Dismiss the current notification with animation.
  static void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;

    if (_hideAction != null) {
      _hideAction?.call();
    } else {
      _removeEntry();
    }
  }

  static void _removeEntry() {
    _hideAction = null;
    _currentEntry?.remove();
    _currentEntry = null;
  }

  // ──────────────────────────────────────────────
  // COLOR MATRIX
  // ──────────────────────────────────────────────

  static _NeoSnackbarColors _getColors(NeoSnackbarType type, bool isDark) {
    switch (type) {
      case NeoSnackbarType.error:
        return isDark
            ? _NeoSnackbarColors(
                background: const Color(0xFF3D1C1C),
                text: const Color(0xFFFFB4AB),
                border: AppColors.danger,
                icon: const Color(0xFFFFB4AB),
                shadow: Colors.white.withValues(alpha: 0.1),
              )
            : _NeoSnackbarColors(
                background: const Color(0xFFFFDAD4),
                text: const Color(0xFF930006),
                border: AppColors.danger,
                icon: const Color(0xFF930006),
                shadow: Colors.black,
              );

      case NeoSnackbarType.success:
        return isDark
            ? _NeoSnackbarColors(
                background: const Color(0xFF1C3D2A),
                text: const Color(0xFFA8F0C0),
                border: AppColors.success,
                icon: const Color(0xFFA8F0C0),
                shadow: Colors.white.withValues(alpha: 0.1),
              )
            : _NeoSnackbarColors(
                background: const Color(0xFFD4F5E0),
                text: const Color(0xFF0A5C2B),
                border: AppColors.success,
                icon: const Color(0xFF0A5C2B),
                shadow: Colors.black,
              );

      case NeoSnackbarType.warning:
        return isDark
            ? _NeoSnackbarColors(
                background: const Color(0xFF3D321C),
                text: const Color(0xFFFFD580),
                border: AppColors.warning,
                icon: const Color(0xFFFFD580),
                shadow: Colors.white.withValues(alpha: 0.1),
              )
            : _NeoSnackbarColors(
                background: const Color(0xFFFFF0D4),
                text: const Color(0xFF6B4A00),
                border: AppColors.warning,
                icon: const Color(0xFF6B4A00),
                shadow: Colors.black,
              );

      case NeoSnackbarType.info:
        return isDark
            ? _NeoSnackbarColors(
                background: const Color(0xFF1A2D35),
                text: const Color(0xFF80E8F0),
                border: AppColors.primary,
                icon: const Color(0xFF80E8F0),
                shadow: Colors.white.withValues(alpha: 0.1),
              )
            : _NeoSnackbarColors(
                background: const Color(0xFFD4F5F7),
                text: const Color(0xFF00626A),
                border: AppColors.primary,
                icon: const Color(0xFF00626A),
                shadow: Colors.black,
              );

      case NeoSnackbarType.loading:
        return isDark
            ? _NeoSnackbarColors(
                background: AppColors.surfaceDark,
                text: AppColors.textPrimaryDark,
                border: AppColors.borderDark,
                icon: AppColors.primary,
                shadow: Colors.white.withValues(alpha: 0.1),
              )
            : _NeoSnackbarColors(
                background: AppColors.surfaceLight,
                text: AppColors.textPrimaryLight,
                border: AppColors.borderLight,
                icon: AppColors.primary,
                shadow: Colors.black,
              );
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
// INTERNAL COLOR DATA CLASS
// ═══════════════════════════════════════════════════════════════════

class _NeoSnackbarColors {
  final Color background;
  final Color text;
  final Color border;
  final Color icon;
  final Color shadow;

  const _NeoSnackbarColors({
    required this.background,
    required this.text,
    required this.border,
    required this.icon,
    required this.shadow,
  });
}

// ═══════════════════════════════════════════════════════════════════
// ANIMATED OVERLAY WIDGET
// ═══════════════════════════════════════════════════════════════════

class _NeoSnackbarWidget extends StatefulWidget {
  final String message;
  final NeoSnackbarType type;
  final NeoSnackbarPosition position;
  final _NeoSnackbarColors colors;
  final bool isDark;
  final MediaQueryData mediaQuery;
  final VoidCallback onDismiss;

  const _NeoSnackbarWidget({
    required this.message,
    required this.type,
    required this.position,
    required this.colors,
    required this.isDark,
    required this.mediaQuery,
    required this.onDismiss,
  });

  @override
  State<_NeoSnackbarWidget> createState() => _NeoSnackbarWidgetState();
}

class _NeoSnackbarWidgetState extends State<_NeoSnackbarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      reverseDuration: const Duration(milliseconds: 250),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    _slideAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    // Register hide action to the static controller
    NeoSnackBar._hideAction = () {
      if (mounted) {
        _controller.reverse().then((_) {
          if (mounted) widget.onDismiss();
        });
      }
    };

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  IconData _iconForType(NeoSnackbarType type) {
    switch (type) {
      case NeoSnackbarType.error:
        return Icons.error_outline;
      case NeoSnackbarType.success:
        return Icons.check_circle_outline;
      case NeoSnackbarType.warning:
        return Icons.warning_amber_rounded;
      case NeoSnackbarType.info:
        return Icons.info_outline;
      case NeoSnackbarType.loading:
        return Icons.hourglass_empty; // fallback, actual uses spinner
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = widget.mediaQuery.padding.top + 16;
    final bottomPadding = widget.mediaQuery.padding.bottom + 80;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Symmetrical slide: start at -100 offset (off-screen) and end at 0.
        // For 'top', -100 offset means shifting UP (out of view).
        // For 'bottom', -100 offset means shifting DOWN (out of view).
        final slideOffset = (1.0 - _slideAnimation.value) * -100;

        return Positioned(
          top: widget.position == NeoSnackbarPosition.top
              ? topPadding + slideOffset
              : null,
          bottom: widget.position == NeoSnackbarPosition.bottom
              ? bottomPadding + slideOffset
              : null,
          left: 0,
          right: 0,
          child: Opacity(
            opacity: _fadeAnimation.value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: Center(
        child: GestureDetector(
          onTap: widget.onDismiss,
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: widget.mediaQuery.size.width * 0.85,
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: widget.colors.background,
                borderRadius: BorderRadius.circular(50),
                border: Border.all(
                  color: widget.colors.border,
                  width: AppColors.brutalBorderWidth,
                ),
                boxShadow: [
                  BoxShadow(
                    offset: AppColors.brutalShadowOffset,
                    color: widget.colors.shadow,
                    blurRadius: 0,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon or loading spinner
                  if (widget.type == NeoSnackbarType.loading)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            widget.colors.icon),
                      ),
                    )
                  else
                    Icon(
                      _iconForType(widget.type),
                      color: widget.colors.icon,
                      size: 20,
                    ),
                  const SizedBox(width: 12),
                  // Message text
                  Flexible(
                    child: Text(
                      widget.message,
                      style: TextStyle(
                        color: widget.colors.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
