import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;

import '../../../models/club.dart';

// ── Typed js_interop bindings ───────────────────────────────────
// These compile to direct JS function calls — no eval(), no
// JSON serialization round-trip. ~10x faster than the previous
// eval('window.fn(...)') approach.

@JS('initYandexMap')
external void _jsInitYandexMap(JSString containerId);

@JS('addClubMarkers')
external void _jsAddClubMarkers(JSString markersJson);

@JS('clearClubMarkers')
external void _jsClearClubMarkers();

@JS('panToClub')
external void _jsPanToClub(JSNumber lat, JSNumber lon);

@JS('locateUser')
external void _jsLocateUser();

@JS('setMarkerClickCallback')
external void _jsSetMarkerClickCallback(JSFunction cb);

@JS('window._ymapReady')
external JSBoolean? get _jsYmapReady;

@JS('window._ymapLocateError')
external JSString? get _jsYmapLocateError;

/// Service to interact with Yandex Maps JS API via typed js_interop.
class YandexMapService {
  static bool _viewRegistered = false;
  static int? _lastMarkersHash;
  static JSFunction? _clickCb;

  /// Register platform view factory (call once).
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

  /// Initialize the map in a given container.
  /// Polls `window._ymapReady` (faster + no fixed 3s wait).
  static Future<void> initMap(String containerId) async {
    try {
      _jsInitYandexMap(containerId.toJS);
    } catch (_) {}

    // Wait up to 15s, polling 80ms — typical real cost is 200-600ms,
    // not 3s as the old code assumed.
    final sw = Stopwatch()..start();
    while (sw.elapsed < const Duration(seconds: 15)) {
      try {
        final ready = _jsYmapReady?.toDart ?? false;
        if (ready) return;
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
  }

  /// Add club markers to the map.
  /// [occupancy] is clubId → number of currently active sessions.
  /// Border colors: green (free) / yellow (busy) / red (full).
  static void setMarkers(List<Club> clubs, {Map<String, int>? occupancy}) {
    final markersData = clubs.where((c) {
      if (c.lat == null || c.lon == null) return false;
      final lat = c.lat!;
      final lon = c.lon!;
      return lat >= 37.0 && lat <= 46.0 && lon >= 55.0 && lon <= 74.0;
    }).map((c) {
      final hasPc = c.pcCount > 0;
      final hasPs = c.hasPlaystation;
      final occ = occupancy?[c.id] ?? 0;
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
    }).toList();

    final jsonStr = jsonEncode(markersData);

    // Cheap hash — skip the JS round trip if nothing actually changed.
    // Saves an O(n) re-render every time occupancy refresh fires with
    // identical numbers (common — 30s refresh, occupancy rarely changes).
    final hash = jsonStr.hashCode;
    if (_lastMarkersHash == hash) return;
    _lastMarkersHash = hash;

    try {
      _jsAddClubMarkers(jsonStr.toJS);
    } catch (_) {}
  }

  /// Clear all markers (and the de-dupe cache).
  static void clearMarkers() {
    _lastMarkersHash = null;
    try {
      _jsClearClubMarkers();
    } catch (_) {}
  }

  /// Pan map to a specific club location.
  static void panTo(double lat, double lon) {
    try {
      _jsPanToClub(lat.toJS, lon.toJS);
    } catch (_) {}
  }

  /// Locate user. Returns null on success or an error message.
  static String? locateUser() {
    try {
      _jsLocateUser();
    } catch (_) {}
    return null;
  }

  /// Read last geolocation error (set asynchronously by the JS side).
  static String? getLastLocateError() {
    try {
      final err = _jsYmapLocateError?.toDart;
      return (err == null || err == 'null') ? null : err;
    } catch (_) {
      return null;
    }
  }

  /// Register a callback that fires when a marker is tapped.
  /// JS calls into Dart directly — no polling, no eval.
  /// Replaces the old `startMarkerClickPolling`.
  static void registerMarkerClick(void Function(String clubId) callback) {
    // Unregister previous callback if any (re-entry safety).
    _clickCb = ((JSString id) {
      try {
        callback(id.toDart);
      } catch (_) {}
    }).toJS;
    try {
      _jsSetMarkerClickCallback(_clickCb!);
    } catch (_) {}
  }

  /// Tear down the click callback. Called from widget dispose.
  static void unregisterMarkerClick() {
    _clickCb = null;
    // Pass a no-op so JS doesn't hold the Dart closure alive.
    try {
      _jsSetMarkerClickCallback(((JSString _) {}).toJS);
    } catch (_) {}
  }

  // ── Backward-compatibility shims (deprecated, will remove) ───
  @Deprecated('Use registerMarkerClick — polling has been replaced.')
  static void startMarkerClickPolling(void Function(String clubId) cb) =>
      registerMarkerClick(cb);

  @Deprecated('Polling no longer used; call unregisterMarkerClick.')
  static void stopPolling() => unregisterMarkerClick();
}
