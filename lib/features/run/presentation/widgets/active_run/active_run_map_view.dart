import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../../../core/theme/app_colors.dart';

class ActiveRunMapView extends StatelessWidget {
  final bool isDark;
  final bool hasPermissions;
  final bool isFinished;
  final bool isMapReady;
  final String? mapStyle;
  final double safeTopInset;
  final double? distanceGoal;
  final List<List<LatLng>> routePoints;
  final Set<Circle> circles;
  final Set<Marker> markers;
  final FutureOr<void> Function(GoogleMapController) onMapCreated;

  const ActiveRunMapView({
    super.key,
    required this.isDark,
    required this.hasPermissions,
    required this.isFinished,
    required this.isMapReady,
    required this.mapStyle,
    required this.safeTopInset,
    required this.distanceGoal,
    required this.routePoints,
    this.circles = const {},
    this.markers = const {},
    required this.onMapCreated,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(target: LatLng(0, 0), zoom: 15),
            myLocationEnabled: hasPermissions,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapType: MapType.normal,
            style: mapStyle,
            circles: circles,
            padding: EdgeInsets.only(
              bottom: (distanceGoal != null && distanceGoal! > 0) ? 380 : 280,
              top: safeTopInset + 60,
            ),
            onMapCreated: onMapCreated,
            markers: markers,
            polylines: routePoints.asMap().entries.map((entry) {
              final int idx = entry.key;
              final List<LatLng> segment = entry.value;
              return Polyline(
                polylineId: PolylineId('route_$idx'),
                points: segment,
                color: AppColors.primaryNeon,
                width: 5,
                startCap: Cap.roundCap,
                endCap: Cap.roundCap,
              );
            }).toSet(),
          ),
          if (!isMapReady && isDark)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(color: const Color(0xFF1d2c2c)),
              ),
            ),
        ],
      ),
    );
  }
}
