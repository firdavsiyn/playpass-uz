import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;

import '../../../models/club.dart';

/// Service to interact with Yandex Maps JS API via js_interop
class YandexMapService {
  static bool _viewRegistered = false;
  static bool _polling = false;

  /// Register platform view factory (call once)
  static void ensureRegistered() {
    if (_viewRegistered) return;
    _viewRegistered = true;

    ui_web.platformViewRegistry.registerViewFactory(
      'yandex-map-view',
      (int viewId, {Object? params}) {
        final div = web.document.createElement('div') as web.HTMLDivElement;
        div.id = 'yandex-map-$viewId';
        div.style.setProperty('width', '100%');
        div.style.setProperty('height', '100%');
        return div;
      },
    );
  }

  /// Initialize the map in a given container
  static Future<void> initMap(String containerId) async {
    _eval('initYandexMap("$containerId")');
    // Wait for ymaps.ready + map creation
    await Future.delayed(const Duration(milliseconds: 3000));
  }

  /// Add club markers to the map.
  /// [occupancy] is a map of clubId → number of currently active sessions.
  /// Used to color-code marker borders: green (free) / yellow (busy) /
  /// red (full) for at-a-glance availability.
  static void setMarkers(List<Club> clubs, {Map<String, int>? occupancy}) {
    final markersData = clubs
        .where((c) {
          if (c.lat == null || c.lon == null) return false;
          final lat = c.lat!;
          final lon = c.lon!;
          return lat >= 37.0 && lat <= 46.0 && lon >= 55.0 && lon <= 74.0;
        })
        .map((c) {
          final hasPc = c.pcCount > 0;
          final hasPs = c.hasPlaystation;
          final occ = occupancy?[c.id] ?? 0;
          // Occupancy %: 0–100. -1 means no data (capacity unknown).
          int occupancyPct = -1;
          if (c.pcCount > 0) {
            occupancyPct = ((occ / c.pcCount) * 100).clamp(0, 100).round();
          }
          return {
            'id': c.id,
            'name': c.name,
            'lat': c.lat,
            'lon': c.lon,
            'tier': c.tier,
            'isOpen': c.isOpen,
            'hasPc': hasPc,
            'hasPs': hasPs,
            'occupancyPct': occupancyPct,
            'pcCount': c.pcCount,
            'occupied': occ,
          };
        })
        .toList();
    final jsonStr = jsonEncode(markersData);
    _eval('window.__tempMarkers = $jsonStr');
    _eval('addClubMarkers(JSON.stringify(window.__tempMarkers))');
  }

  /// Clear all markers
  static void clearMarkers() {
    _eval('clearClubMarkers()');
  }

  /// Pan map to a specific club location
  static void panTo(double lat, double lon) {
    _eval('panToClub($lat, $lon)');
  }

  /// Locate user. Returns null on success or an error message.
  static String? locateUser() {
    _eval('locateUser()');
    return null;
  }

  /// Check if last locateUser call had an error (polls after a delay)
  static String? getLastLocateError() {
    final err = _evalReturn('window._ymapLocateError || null');
    return err == null || err == 'null' ? null : err;
  }

  /// Start polling for marker click events from JS
  static void startMarkerClickPolling(void Function(String clubId) callback) {
    if (_polling) return;
    _polling = true;
    _eval('window._ymapClickQueue = window._ymapClickQueue || []');
    _pollLoop(callback);
  }

  static void _pollLoop(void Function(String clubId) callback) {
    if (!_polling) return;
    // Poll at 500ms (was 250ms) — 50% fewer JS calls, still feels instant
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!_polling) return;
      try {
        final raw = _evalReturn(
          '(function(){var q=window._ymapClickQueue||[];window._ymapClickQueue=[];return JSON.stringify(q);})()'
        );
        if (raw != null && raw != '[]' && raw.isNotEmpty) {
          final List<dynamic> ids = jsonDecode(raw);
          for (final id in ids) {
            callback(id.toString());
          }
        }
      } catch (_) {}
      if (_polling) _pollLoop(callback);
    });
  }

  static void stopPolling() {
    _polling = false;
  }

  // ── Low-level JS eval ──────────────────────────────────────

  static void _eval(String code) {
    try {
      _jsEval(code.toJS);
    } catch (e) {
      // ignore
    }
  }

  static String? _evalReturn(String code) {
    try {
      final result = _jsEval(code.toJS);
      if (result == null) return null;
      return (result as JSString).toDart;
    } catch (_) {
      return null;
    }
  }
}

@JS('eval')
external JSAny? _jsEval(JSString code);
