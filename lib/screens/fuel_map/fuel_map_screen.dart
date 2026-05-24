import 'package:flutter/material.dart';
import 'map_viewer_screen.dart';

class FuelMapScreen extends StatelessWidget {
  const FuelMapScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const MapViewerScreen(mapType: MapType.fuel);
}
