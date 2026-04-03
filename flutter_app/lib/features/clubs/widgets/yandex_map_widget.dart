import 'package:flutter/material.dart';

import '../../../models/club.dart';
import '../../../core/theme/app_theme.dart';
import '../services/yandex_map_service.dart';

/// Widget that renders an embedded Yandex Map with club markers
class YandexMapWidget extends StatefulWidget {
  final List<Club> clubs;
  final void Function(String clubId)? onMarkerTapped;

  const YandexMapWidget({
    super.key,
    required this.clubs,
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
      YandexMapService.setMarkers(widget.clubs);

      if (mounted) setState(() => _mapReady = true);
    } catch (e) {
      debugPrint('[YandexMap] init error: $e');
    }
  }

  @override
  void didUpdateWidget(YandexMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_mapReady && widget.clubs != oldWidget.clubs) {
      YandexMapService.clearMarkers();
      YandexMapService.setMarkers(widget.clubs);
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
            color: AppTheme.bgDark,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppTheme.primary),
                  SizedBox(height: 16),
                  Text(
                    'Загрузка карты...',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
