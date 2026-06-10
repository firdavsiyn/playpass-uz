import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../constants/app_constants.dart';

/// Thin wrapper around Sentry initialization.
///
/// If [AppConstants.sentryDsn] is empty, Sentry is disabled and all
/// helper methods become no-ops. This keeps dev builds clean and avoids
/// sending noise to prod Sentry project.
class AppMonitoring {
  static bool _enabled = false;
  static bool get enabled => _enabled;

  /// Call in main() before runApp(). Runs the app inside Sentry's zone
  /// so unhandled exceptions and async errors are captured automatically.
  static Future<void> init(Future<void> Function() appRunner) async {
    final dsn = AppConstants.sentryDsn;
    if (dsn.isEmpty) {
      // Sentry disabled — run app directly
      await appRunner();
      return;
    }

    _enabled = true;
    await SentryFlutter.init(
      (options) {
        options.dsn = dsn;
        options.environment = AppConstants.environment;
        options.release = 'playpass@${AppConstants.appVersion}';

        // Performance monitoring: sample 20% in prod, 100% in dev
        options.tracesSampleRate = kReleaseMode ? 0.2 : 1.0;

        // Capture failed HTTP requests + navigation breadcrumbs
        options.autoAppStart = true;
        options.attachScreenshot = false; // privacy: don't auto-attach
        // attachViewHierarchy is experimental in sentry_flutter — explicitly
        // off, but accessed via a guarded ignore so future API changes won't
        // hard-break our build.
        // ignore: experimental_member_use
        options.attachViewHierarchy = false;

        // Suppress known-noise errors
        options.beforeSend = (event, hint) {
          final exception = event.exceptions?.firstOrNull?.value ?? '';
          if (exception.contains('Network is unreachable') ||
              exception.contains('Connection refused') ||
              exception.contains('SocketException: Failed host lookup')) {
            // User is offline — not our bug
            return null;
          }
          return event;
        };
      },
      appRunner: appRunner,
    );
  }

  /// Manually report an error (for caught exceptions you want tracked)
  static Future<void> captureException(
    dynamic error, {
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) async {
    if (!_enabled) {
      debugPrint('[Monitoring] $error\n$stackTrace');
      return;
    }
    await Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (scope) {
        if (extra != null) {
          for (final e in extra.entries) {
            scope.setExtra(e.key, e.value);
          }
        }
      },
    );
  }

  /// Log a message (info-level)
  static Future<void> captureMessage(String msg, {SentryLevel? level}) async {
    if (!_enabled) {
      debugPrint('[Monitoring] $msg');
      return;
    }
    await Sentry.captureMessage(msg, level: level);
  }

  /// Tag the current user so issues group by user
  static Future<void> setUser({required String id, String? email}) async {
    if (!_enabled) return;
    await Sentry.configureScope((scope) {
      scope.setUser(SentryUser(id: id, email: email));
    });
  }

  /// Clear user (on logout)
  static Future<void> clearUser() async {
    if (!_enabled) return;
    await Sentry.configureScope((scope) => scope.setUser(null));
  }

  /// Leave a breadcrumb for context in future error reports
  static void addBreadcrumb(String message,
      {String? category, Map<String, dynamic>? data}) {
    if (!_enabled) return;
    Sentry.addBreadcrumb(Breadcrumb(
      message: message,
      category: category,
      data: data,
      timestamp: DateTime.now(),
    ));
  }
}
