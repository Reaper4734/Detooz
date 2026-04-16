import 'package:flutter/material.dart';
import 'neo_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/api_service.dart';

/// Shows a friendly offline card when an [OfflineException] is caught,
/// a generic error card for other errors, and the normal child otherwise.
///
/// Usage with Riverpod AsyncValue:
/// ```dart
/// final stats = ref.watch(userStatsProvider);
/// return OfflineAwareBuilder(
///   asyncValue: stats,
///   onRetry: () => ref.read(userStatsProvider.notifier).loadStats(),
///   builder: (data) => Text(data.toString()),
/// );
/// ```
class OfflineAwareBuilder<T> extends StatelessWidget {
  final AsyncValue<T> asyncValue;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;
  final Widget? loadingWidget;

  const OfflineAwareBuilder({
    super.key,
    required this.asyncValue,
    required this.builder,
    this.onRetry,
    this.loadingWidget,
  });

  @override
  Widget build(BuildContext context) {
    return asyncValue.when(
      data: builder,
      loading: () => loadingWidget ?? const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, _) {
        if (error is OfflineException) {
          return _OfflineCard(
            message: error.message,
            onRetry: onRetry,
          );
        }
        return _ErrorCard(
          message: error.toString().replaceAll('Exception: ', ''),
          onRetry: onRetry,
        );
      },
    );
  }
}

/// Standalone offline card — use directly when you detect offline state
/// outside of an AsyncValue context.
class OfflineCard extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;

  const OfflineCard({super.key, this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return _OfflineCard(
      message: message ?? 'No internet connection',
      onRetry: onRetry,
    );
  }
}

// ── Internal widgets ──

class _OfflineCard extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _OfflineCard({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              "You're Offline",
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _ErrorCard({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: theme.colorScheme.error.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'Something Went Wrong',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Helper to show an offline-aware snackbar.
/// Use this when an imperative API call (button tap) fails.
void showOfflineSnackBar(BuildContext context, Object error) {
  final message = error is OfflineException
      ? error.message
      : error.toString().replaceAll('Exception: ', '');

  final type = error is OfflineException
      ? NeoSnackbarType.warning
      : NeoSnackbarType.error;

  NeoSnackBar.show(
    context,
    message: message,
    type: type,
    position: NeoSnackbarPosition.bottom,
    duration: const Duration(seconds: 4),
  );
}
