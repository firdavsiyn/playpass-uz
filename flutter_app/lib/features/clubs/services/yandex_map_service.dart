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

  /// Add club markers to the map
  static void setMarkers(List<Club> clubs) {
    final markersData = clubs
        .where((c) => c.lat != null && c.lon != null)
        .map((c) => {
              'id': c.id,
              'name': c.name,
              'lat': c.lat,
              'lon': c.lon,
              'tier': c.tier ?? 'standard',
              'isOpen': c.isOpen,
            })
        .toList();
    // Use single quotes in the JSON to avoid escaping issues with eval
    final jsonStr = jsonEncode(markersData);
    // Pass via a temp global variable to avoid quote escaping issues
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

  /// Start polling for marker click events from JS
  static void startMarkerClickPolling(void Function(String clubId) callback) {
    if (_polling) return;
    _polling = true;
    _eval('window._ymapClickQueue = window._ymapClickQueue || []');
    _pollLoop(callback);
  }

  static void _pollLoop(void Function(String clubId) callback) {
    Future.delayed(const Duration(milliseconds: 250), () {
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
