import 'package:flutter/material.dart';

import '../../../models/club.dart';
import '../../../core/theme/app_theme.dart';
import '../services/yandex_map_service.dart';

/// Widget that renders an embedded Yandex Map with club markers
class YandexMapWidget extends StatefulWidget {
  final List<Club> clubs;
  final Map<String, int>? occupancy;
  final void Function(String clubId)? onMarkerTapped;

  /// When provided, the map centers on this point after init (used by the
  /// "Ближайшие" / nearby mode to focus on the user's location).
  final double? centerLat;
  final double? centerLon;

  const YandexMapWidget({
    super.key,
    required this.clubs,
    this.occupancy,
    this.onMarkerTapped,
    this.centerLat,
    this.centerLon,
  });

  @override
  State<YandexMapWidget> createState() => _YandexMapWidgetState();
}

class _YandexMapWidgetState extends State<YandexMapWidget> {
  bool _mapReady = false;
  bool _initializing = false;

  @override
  void initState() {
    super.initState();
    YandexMapService.ensureRegistered();
  }

  @override
  void dispose() {
    YandexMapService.unregisterMarkerClick();
    super.dispose();
  }

  Future<void> _initMap(int viewId) async {
    if (_initializing || _mapReady) return;
    _initializing = true;

    final containerId = 'yandex-map-$viewId';

    // Safety timeout: if map doesn't load in 15s, unblock UI
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted && !_mapReady) {
        debugPrint('[YandexMap] init timeout — forcing _mapReady=true');
        setState(() => _mapReady = true);
      }
    });

    try {
      await YandexMapService.initMap(containerId);
      if (!mounted) return;
      if (widget.onMarkerTapped != null) {
        YandexMapService.registerMarkerClick(widget.onMarkerTapped!);
      }
      YandexMapService.setMarkers(widget.clubs, occupancy: widget.occupancy);
      // Center on the user in nearby mode (if a center was supplied).
      if (widget.centerLat != null && widget.centerLon != null) {
        YandexMapService.panTo(widget.centerLat!, widget.centerLon!);
      }
      if (mounted) setState(() => _mapReady = true);
    } catch (e) {
      debugPrint('[YandexMap] init error: $e');
      if (mounted) setState(() => _mapReady = true); // unblock anyway
    }
  }

  @override
  void didUpdateWidget(YandexMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_mapReady) return;

    final clubsChanged = widget.clubs.length != oldWidget.clubs.length ||
        !identical(widget.clubs, oldWidget.clubs);

    final occupancyChanged = widget.occupancy != oldWidget.occupancy &&
        !_occupancyEquals(widget.occupancy, oldWidget.occupancy);

    if (clubsChanged || occupancyChanged) {
      // Re-render markers with fresh occupancy. Cached SVG icons keep this fast.
      YandexMapService.setMarkers(widget.clubs, occupancy: widget.occupancy);
    }

    // Center became available (location resolved after map init) — pan to it.
    final centerChanged = widget.centerLat != oldWidget.centerLat ||
        widget.centerLon != oldWidget.centerLon;
    if (centerChanged && widget.centerLat != null && widget.centerLon != null) {
      YandexMapService.panTo(widget.centerLat!, widget.centerLon!);
    }
  }

  bool _occupancyEquals(Map<String, int>? a, Map<String, int>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        HtmlElementView(
          viewType: 'yandex-map-view',
          onPlatformViewCreated: (int viewId) {
            // Tiny defer so the <div> is in the DOM before initMap reads it.
            // 50ms is enough on every browser; was 500ms as a paranoia margin.
            Future.delayed(const Duration(milliseconds: 50), () {
              if (mounted) _initMap(viewId);
            });
          },
        ),
        if (!_mapReady)
          Container(
            color: context.bg,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppTheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Загрузка карты...',
                    style: TextStyle(color: context.text3, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
