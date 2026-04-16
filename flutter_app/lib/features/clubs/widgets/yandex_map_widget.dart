import 'package:flutter/material.dart';

import '../../../models/club.dart';
import '../../../core/theme/app_theme.dart';
import '../services/yandex_map_service.dart';

/// Widget that renders an embedded Yandex Map with club markers
class YandexMapWidget extends StatefulWidget {
  final List<Club> clubs;
  final Map<String, int>? occupancy;
  final void Function(String clubId)? onMarkerTapped;

  const YandexMapWidget({
    super.key,
    required this.clubs,
    this.occupancy,
    this.onMarkerTapped,
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

  Future<void> _initMap(int viewId) async {
    if (_initializing || _mapReady) return;
    _initializing = true;

    final containerId = 'yandex-map-$viewId';

    try {
      await YandexMapService.initMap(containerId);

      if (!mounted) return;

      // Set up marker click polling
      if (widget.onMarkerTapped != null) {
        YandexMapService.startMarkerClickPolling(widget.onMarkerTapped!);
      }

      // Add initial markers
      YandexMapService.setMarkers(widget.clubs, occupancy: widget.occupancy);

      if (mounted) setState(() => _mapReady = true);
    } catch (e) {
      debugPrint('[YandexMap] init error: $e');
    }
  }

  @override
  void didUpdateWidget(YandexMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_mapReady) return;

    // Only rebuild markers if club list actually changed (by length or identity).
    // Occupancy changes alone don't re-add markers — they update via a cheaper path.
    final clubsChanged = widget.clubs.length != oldWidget.clubs.length ||
        !identical(widget.clubs, oldWidget.clubs);

    if (clubsChanged) {
      YandexMapService.setMarkers(widget.clubs, occupancy: widget.occupancy);
    } else if (widget.occupancy != oldWidget.occupancy) {
      // Skip full re-add: occupancy is a transient state; the map already has
      // markers. Re-setting them causes flicker and jank during pan/zoom.
      // Users will see updated % on next data refresh.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        HtmlElementView(
          viewType: 'yandex-map-view',
          onPlatformViewCreated: (int viewId) {
            // Delay to let the DOM element render
            Future.delayed(const Duration(milliseconds: 500), () {
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
