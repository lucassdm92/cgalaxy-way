import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../services/delivery_service.dart';
import '../services/session_service.dart';
import '../data/dial_codes.dart';
import 'map_modal.dart';
import 'pedidos_screen.dart';

// ─── Colors ──────────────────────────────────────────────────────────────────

class _C {
  static const bg      = Color(0xFFF7F6F2);
  static const surface = Color(0xFFFFFFFF);
  static const primary = Color(0xFF1A1A2E);
  static const accent  = Color(0xFFFF5C3A);
  static const muted   = Color(0xFF8A8A99);
  static const border  = Color(0xFFEAEAE6);
}

// ─── Models ───────────────────────────────────────────────────────────────────

class _PriceResponse {
  final int id;
  final double totalPrice;

  const _PriceResponse({
    required this.id,
    required this.totalPrice,
  });

  factory _PriceResponse.fromJson(Map<String, dynamic> json) => _PriceResponse(
        id:         json['id'] as int,
        totalPrice: (json['total_price'] as num).toDouble(),
      );

  String get totalFormatado =>
      'R\$ ${totalPrice.toStringAsFixed(2).replaceAll('.', ',')}';
}

// ─── Home Screen ─────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _originCtrl = TextEditingController(
    text: SessionService.instance.client?.address ?? '',
  );
  final _destCtrl = TextEditingController();
  int _tab = 0;

  @override
  void dispose() {
    _originCtrl.dispose();
    _destCtrl.dispose();
    super.dispose();
  }

  void _swap() {
    final t = _originCtrl.text;
    _originCtrl.text = _destCtrl.text;
    _destCtrl.text   = t;
  }

  Future<void> _calcularRota() async {
    if (_originCtrl.text.trim().isEmpty || _destCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha os dois endereços.')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _LoadingDialog(),
    );

    try {
      final origemCoords = await _geocode(_originCtrl.text.trim());
      final destinoCoords = await _geocode(_destCtrl.text.trim());

      if (!mounted) return;
      Navigator.of(context).pop();

      if (origemCoords == null || destinoCoords == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível localizar um dos endereços.'),
            backgroundColor: Color(0xFFC62828),
          ),
        );
        return;
      }

      final result = await showModalBottomSheet<MapResult>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        enableDrag: false,
        builder: (_) => MapModal(
          origemText:    _originCtrl.text.trim(),
          destinoText:   _destCtrl.text.trim(),
          origemCoords:  origemCoords,
          destinoCoords: destinoCoords,
        ),
      );

      if (result == null || !result.confirmed || !mounted) return;

      _destCtrl.text = result.destinoText;
      final finalDestinoCoords = result.destinoCoords;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _LoadingDialog(),
      );

      final now  = DateTime.now();
      final date = '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}'
                   'T${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}:${now.second.toString().padLeft(2,'0')}';

      final distanceMeters = await _roadDistanceMeters(origemCoords, finalDestinoCoords);

      debugPrint('[PriceRequest] origin: ${_originCtrl.text.trim()}');
      debugPrint('[PriceRequest] destination: ${_destCtrl.text.trim()}');
      debugPrint('[PriceRequest] origemCoords: ${origemCoords.latitude}, ${origemCoords.longitude}');
      debugPrint('[PriceRequest] destinoCoords: ${finalDestinoCoords.latitude}, ${finalDestinoCoords.longitude}');
      debugPrint('[PriceRequest] distanceMeters: $distanceMeters');

      final response = await http
          .post(
            Uri.parse(AppConfig.precos),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${SessionService.instance.token}',
            },
            body: jsonEncode({
              'date':        date,
              'username':    SessionService.instance.username,
              if (distanceMeters != null) 'distance_meters': distanceMeters,
            }),
          )
          .timeout(AppConfig.timeout);

      if (!mounted) return;
      Navigator.of(context).pop();

      if (response.statusCode == 200 || response.statusCode == 201) {
        final price = _PriceResponse.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (_) => _EntregaModal(
            frete:           price,
            origem:          _originCtrl.text.trim(),
            destino:         _destCtrl.text.trim(),
            origemCoords:    origemCoords,
            destinoCoords:   finalDestinoCoords,
            distanceMeters:  distanceMeters,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro do servidor (${response.statusCode}).'),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst || r is! DialogRoute);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e'), backgroundColor: const Color(0xFFC62828)),
      );
    }
  }

  Future<int?> _roadDistanceMeters(LatLng origin, LatLng destination) async {
    try {
      final response = await http
          .post(
            Uri.parse('https://routes.googleapis.com/directions/v2:computeRoutes'),
            headers: {
              'Content-Type':      'application/json',
              'X-Goog-Api-Key':    AppConfig.googleMapsKey,
              'X-Goog-FieldMask':  'routes.distanceMeters',
            },
            body: jsonEncode({
              'origin': {
                'location': {
                  'latLng': {'latitude': origin.latitude, 'longitude': origin.longitude},
                },
              },
              'destination': {
                'location': {
                  'latLng': {'latitude': destination.latitude, 'longitude': destination.longitude},
                },
              },
              'travelMode': 'DRIVE',
            }),
          )
          .timeout(AppConfig.timeout);
      if (response.statusCode == 200) {
        final data   = jsonDecode(response.body) as Map<String, dynamic>;
        final routes = data['routes'] as List<dynamic>;
        if (routes.isNotEmpty) {
          return (routes.first as Map<String, dynamic>)['distanceMeters'] as int;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<LatLng?> _geocode(String address) async {
    try {
      final uri = Uri.parse('https://maps.googleapis.com/maps/api/geocode/json').replace(
        queryParameters: {
          'address': address,
          'key': AppConfig.googleMapsKey,
          'region': (SessionService.instance.client?.countryCode ?? 'ie').toLowerCase(),
          'components': 'country:${(SessionService.instance.client?.countryCode ?? 'IE').toUpperCase()}',
        },
      );
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final results = data['results'] as List<dynamic>;
        if (results.isNotEmpty) {
          final loc = (results.first as Map<String, dynamic>)['geometry']['location'];
          return LatLng(loc['lat'] as double, loc['lng'] as double);
        }
      }
    } catch (_) {}
    return null;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _tab == 1
                  ? const PedidosScreen()
                  : SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 20),
                          _buildHeroBanner(),
                          const SizedBox(height: 24),
                          _buildSectionTitle('Nova entrega'),
                          const SizedBox(height: 12),
                          _buildFormCard(),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
            ),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final clientName = SessionService.instance.client?.name ?? 'GalaxyWay';
    final initials   = clientName
        .trim()
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              clientName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _C.primary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 22,
            backgroundColor: _C.accent,
            child: Text(
              initials,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero Banner ───────────────────────────────────────────────────────────

  Widget _buildHeroBanner() {
    final screenWidth = MediaQuery.of(context).size.width;
    final bannerWidth = screenWidth - 48;
    final titleSize   = (bannerWidth * 0.072).clamp(20.0, 34.0);
    final subtitleSize = (bannerWidth * 0.032).clamp(11.0, 16.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: AspectRatio(
        aspectRatio: 16 / 7,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D1A),
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            children: [

              // Imagem cobrindo o banner inteiro
              Positioned.fill(
                child: Image.asset(
                  'assets/images/astronauta.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
              ),

              // Texto sobreposto
              Positioned(
                left: bannerWidth * 0.05,
                bottom: bannerWidth * 0.05,
                right: bannerWidth * 0.05,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Galaxy Go',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: titleSize,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        height: 1,
                      ),
                    ),
                    SizedBox(height: bannerWidth * 0.015),
                    Text(
                      'Venha fazer parte dessa galaxia',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: subtitleSize,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  // ── Section Title ─────────────────────────────────────────────────────────

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _C.primary),
      ),
    );
  }

  // ── Form Card ─────────────────────────────────────────────────────────────

  Widget _buildFormCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            _buildAddressField(_originCtrl, 'Endereço de origem...', _C.primary),

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Row(
                children: [
                  const SizedBox(width: 4),
                  Container(width: 1.5, height: 12, color: _C.border),
                  const SizedBox(width: 8),
                  Text('até', style: TextStyle(fontSize: 11, color: _C.muted)),
                  const Spacer(),
                  GestureDetector(
                    onTap: _swap,
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _C.border),
                        color: _C.surface,
                      ),
                      child: const Center(child: Text('⇅', style: TextStyle(fontSize: 14))),
                    ),
                  ),
                ],
              ),
            ),

            _buildAddressField(_destCtrl, 'Endereço de destino...', _C.accent),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _calcularRota,
                icon: const Icon(Icons.route_rounded, size: 18),
                label: const Text(
                  'Calcular Rota',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildAddressField(TextEditingController ctrl, String hint, Color dot) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(color: _C.bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: dot)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: ctrl,
              style: const TextStyle(fontSize: 14, color: _C.primary),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: _C.muted, fontSize: 14),
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom Nav ────────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    const items = [
      (Icons.home_rounded,       'Home'),
      (Icons.inventory_2_rounded,'Pedidos'),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      decoration: const BoxDecoration(
        color: _C.surface,
        border: Border(top: BorderSide(color: _C.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (i) {
          final active = i == _tab;
          return GestureDetector(
            onTap: () => setState(() => _tab = i),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(items[i].$1, color: active ? _C.accent : _C.muted, size: 24),
                const SizedBox(height: 4),
                Text(
                  items[i].$2,
                  style: TextStyle(
                    fontSize: 10,
                    color: active ? _C.accent : _C.muted,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                if (active) ...[
                  const SizedBox(height: 3),
                  Container(
                    width: 5, height: 5,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: _C.accent),
                  ),
                ],
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ─── Map Modal → ver map_modal.dart ──────────────────────────────────────────


// ─── Loading Dialog ───────────────────────────────────────────────────────────

class _LoadingDialog extends StatelessWidget {
  const _LoadingDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
          decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(20)),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 52, height: 52,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(_C.accent),
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Calculando rota...',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _C.primary),
              ),
              SizedBox(height: 6),
              Text(
                'Aguarde um momento',
                style: TextStyle(fontSize: 12, color: _C.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Modal de Entrega ─────────────────────────────────────────────────────────

class _EntregaModal extends StatefulWidget {
  final _PriceResponse frete;
  final String origem;
  final String destino;
  final LatLng origemCoords;
  final LatLng destinoCoords;
  final int? distanceMeters;

  const _EntregaModal({
    required this.frete,
    required this.origem,
    required this.destino,
    required this.origemCoords,
    required this.destinoCoords,
    this.distanceMeters,
  });

  @override
  State<_EntregaModal> createState() => _EntregaModalState();
}

class _EntregaModalState extends State<_EntregaModal> {
  final _nomeCtrl     = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _notaCtrl     = TextEditingController();
  DialCountry _dialCountry = kDialCodes.firstWhere((c) => c.code == 'PT');
  bool _loading = false;

  String get _telefoneCompleto {
    final num = _telefoneCtrl.text.trim();
    return num.isEmpty ? '' : '${_dialCountry.dial}$num';
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _telefoneCtrl.dispose();
    _emailCtrl.dispose();
    _notaCtrl.dispose();
    super.dispose();
  }

  Future<void> _showCountryPicker() async {
    final searchCtrl = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          final filtered = searchCtrl.text.isEmpty
              ? kDialCodes
              : kDialCodes
                  .where((c) =>
                      c.name.toLowerCase().contains(searchCtrl.text.toLowerCase()) ||
                      c.dial.contains(searchCtrl.text))
                  .toList();
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.75,
            decoration: const BoxDecoration(
              color: _C.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: _C.border, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(color: _C.bg, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        const Icon(Icons.search, size: 18, color: _C.muted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: searchCtrl,
                            autofocus: true,
                            style: const TextStyle(fontSize: 14, color: _C.primary),
                            decoration: const InputDecoration(
                              hintText: 'Pesquisar país...',
                              hintStyle: TextStyle(color: _C.muted, fontSize: 14),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 10),
                              border: InputBorder.none,
                            ),
                            onChanged: (_) => setModal(() {}),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final c = filtered[i];
                      return ListTile(
                        leading: Text(c.flag, style: const TextStyle(fontSize: 22)),
                        title: Text(c.name, style: const TextStyle(fontSize: 14, color: _C.primary)),
                        trailing: Text(c.dial, style: const TextStyle(fontSize: 13, color: _C.muted)),
                        onTap: () {
                          setState(() => _dialCountry = c);
                          Navigator.of(ctx).pop();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    searchCtrl.dispose();
  }

  Future<void> _aceitar() async {
    if (_nomeCtrl.text.trim().isEmpty || _telefoneCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha o nome e o telefone do cliente.')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await DeliveryService.instance.requestDelivery(
        priceCalculationId: widget.frete.id,
        origin:             widget.origem,
        destination:        widget.destino,
        customerName:       _nomeCtrl.text.trim(),
        customerPhone:      _telefoneCompleto,
        customerEmail:      _emailCtrl.text.trim(),
        customerNote:       _notaCtrl.text.trim(),
        originLat:          widget.origemCoords.latitude,
        originLng:          widget.origemCoords.longitude,
        destLat:            widget.destinoCoords.latitude,
        destLng:            widget.destinoCoords.longitude,
        distanceMeters:     widget.distanceMeters,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pedido confirmado! Buscando rider...'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: const Color(0xFFC62828),
        ),
      );
    }
  }

  Widget _buildField({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType inputType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _C.muted)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(color: _C.bg, borderRadius: BorderRadius.circular(12)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Icon(icon, size: 18, color: _C.muted),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: ctrl,
                  keyboardType: inputType,
                  maxLines: maxLines,
                  style: const TextStyle(fontSize: 14, color: _C.primary),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(color: _C.muted, fontSize: 14),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      decoration: const BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: _C.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            'Valor da entrega',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _C.primary),
          ),
          const SizedBox(height: 16),

          // Rota
          Container(
            padding: const EdgeInsets.all(14),
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
                      Text(widget.origem,  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _C.primary)),
                      const SizedBox(height: 8),
                      Text(widget.destino, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _C.primary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Preço
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _C.bg, borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Distância', style: TextStyle(fontSize: 13, color: _C.muted)),
                    Text(
                      widget.distanceMeters != null
                          ? '${(widget.distanceMeters! / 1000.0).toStringAsFixed(2).replaceAll('.', ',')} km'
                          : '—',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _C.primary),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(color: _C.border, height: 1),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _C.primary)),
                    Text(
                      widget.frete.totalFormatado,
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: _C.accent),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Dados do cliente
          _buildField(
            ctrl:  _nomeCtrl,
            label: 'Nome do cliente',
            hint:  'Ex: João Silva',
            icon:  Icons.person_outline_rounded,
          ),
          const SizedBox(height: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Telefone',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _C.muted),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(color: _C.bg, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _showCountryPicker,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_dialCountry.flag, style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 4),
                          Text(
                            _dialCountry.dial,
                            style: const TextStyle(fontSize: 14, color: _C.primary, fontWeight: FontWeight.w600),
                          ),
                          const Icon(Icons.arrow_drop_down, size: 18, color: _C.muted),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 20, color: _C.border, margin: const EdgeInsets.symmetric(horizontal: 10)),
                    Expanded(
                      child: TextField(
                        controller: _telefoneCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: const TextStyle(fontSize: 14, color: _C.primary),
                        decoration: const InputDecoration(
                          hintText: '912 345 678',
                          hintStyle: TextStyle(color: _C.muted, fontSize: 14),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildField(
            ctrl:        _emailCtrl,
            label:       'Email do cliente',
            hint:        'Ex: joao@email.com',
            icon:        Icons.email_outlined,
            inputType:   TextInputType.emailAddress,
          ),
          const SizedBox(height: 10),
          _buildField(
            ctrl:      _notaCtrl,
            label:     'Nota',
            hint:      'Instruções para o rider...',
            icon:      Icons.notes_rounded,
            maxLines:  3,
          ),
          const SizedBox(height: 24),

          // Botões
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _C.primary,
                    side: const BorderSide(color: _C.border),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Recusar', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _loading ? null : _aceitar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.accent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _C.accent.withValues(alpha: 0.6),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                        )
                      : const Text('Aceitar', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ],
          ),
        ],
      ),
        ),
      ),
    );
  }
}

// ─── Country dial code ────────────────────────────────────────────────────────


// ─── Star widget (banner) ─────────────────────────────────────────────────────

class _Star extends StatelessWidget {
  final double left;
  final double top;
  final double size;

  const _Star({required this.left, required this.top, required this.size});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top:  top,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}
