import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

// ─── Colors (espelho de _C em home_screen) ────────────────────────────────────

class _C {
  static const bg      = Color(0xFFF7F6F2);
  static const surface = Color(0xFFFFFFFF);
  static const primary = Color(0xFF1A1A2E);
  static const accent  = Color(0xFFFF5C3A);
  static const border  = Color(0xFFEAEAE6);
}

// ─── Map Result ───────────────────────────────────────────────────────────────

class MapResult {
  final bool confirmed;
  final String destinoText;
  final LatLng destinoCoords;
  const MapResult({required this.confirmed, required this.destinoText, required this.destinoCoords});
}

// ─── Map Modal ────────────────────────────────────────────────────────────────

class MapModal extends StatefulWidget {
  final String origemText;
  final String destinoText;
  final LatLng origemCoords;
  final LatLng destinoCoords;

  const MapModal({
    super.key,
    required this.origemText,
    required this.destinoText,
    required this.origemCoords,
    required this.destinoCoords,
  });

  @override
  State<MapModal> createState() => _MapModalState();
}

class _MapModalState extends State<MapModal> {
  GoogleMapController? _mapCtrl;
  bool _reverseGeocoding = false;

  late LatLng _destinoCoords;
  late String _destinoText;

  @override
  void initState() {
    super.initState();
    _destinoCoords = widget.destinoCoords;
    _destinoText   = widget.destinoText;
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _onDestinoDragEnd(LatLng pos) async {
    setState(() {
      _destinoCoords = pos;
      _reverseGeocoding = true;
    });

    try {
      final uri = Uri.parse('https://maps.googleapis.com/maps/api/geocode/json').replace(
        queryParameters: {
          'latlng':   '${pos.latitude},${pos.longitude}',
          'key':      AppConfig.googleMapsKey,
          'region':   'ie',
          'language': 'pt',
        },
      );
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data    = jsonDecode(response.body) as Map<String, dynamic>;
        final results = data['results'] as List<dynamic>;
        if (results.isNotEmpty && mounted) {
          setState(() {
            _destinoText = (results.first as Map<String, dynamic>)['formatted_address'] as String;
          });
        }
      }
    } catch (_) {}

    if (mounted) setState(() => _reverseGeocoding = false);
  }

  void _onMapCreated(GoogleMapController ctrl) {
    _mapCtrl = ctrl;
    final bounds = LatLngBounds(
      southwest: LatLng(
        min(widget.origemCoords.latitude,  _destinoCoords.latitude),
        min(widget.origemCoords.longitude, _destinoCoords.longitude),
      ),
      northeast: LatLng(
        max(widget.origemCoords.latitude,  _destinoCoords.latitude),
        max(widget.origemCoords.longitude, _destinoCoords.longitude),
      ),
    );
    ctrl.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: _C.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),

          // Endereços
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _C.bg, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Column(
                    children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: _C.primary)),
                      Container(width: 1.5, height: 22, color: _C.border),
                      Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: _C.accent)),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.origemText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _C.primary), overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(_destinoText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _C.primary), overflow: TextOverflow.ellipsis),
                            ),
                            if (_reverseGeocoding)
                              const SizedBox(
                                width: 12, height: 12,
                                child: CircularProgressIndicator(strokeWidth: 1.5, color: _C.accent),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Dica
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Toque no mapa para mover o destino',
              style: const TextStyle(fontSize: 11, color: Color(0xFF8A8A99), fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ),

          // Mapa
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(
                      (widget.origemCoords.latitude  + widget.destinoCoords.latitude)  / 2,
                      (widget.origemCoords.longitude + widget.destinoCoords.longitude) / 2,
                    ),
                    zoom: 12,
                  ),
                  onMapCreated: _onMapCreated,
                  onTap: _onDestinoDragEnd,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  markers: {
                    Marker(
                      markerId: const MarkerId('origem'),
                      position: widget.origemCoords,
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                    ),
                    Marker(
                      markerId: const MarkerId('destino'),
                      position: _destinoCoords,
                      draggable: true,
                      onDragEnd: _onDestinoDragEnd,
                    ),
                  },
                ),
              ),
            ),
          ),

          // Botões
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(MapResult(confirmed: false, destinoText: _destinoText, destinoCoords: _destinoCoords)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _C.primary,
                      side: const BorderSide(color: _C.border),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(MapResult(confirmed: true, destinoText: _destinoText, destinoCoords: _destinoCoords)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _C.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('Confirmar', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
