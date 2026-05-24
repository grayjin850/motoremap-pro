import 'package:flutter/material.dart';
import '../fuel_map/map_viewer_screen.dart';

class IgnitionMapScreen extends StatelessWidget {
  const IgnitionMapScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const MapViewerScreen(mapType: MapType.ignition);
}
