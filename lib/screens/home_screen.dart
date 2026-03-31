import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/delivery.dart';
import '../services/delivery_service.dart';
import '../services/session_service.dart';

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
  final double distanceKm;

  const _PriceResponse({
    required this.id,
    required this.totalPrice,
    required this.distanceKm,
  });

  factory _PriceResponse.fromJson(Map<String, dynamic> json) => _PriceResponse(
        id:         json['id'] as int,
        totalPrice: (json['total_price'] as num).toDouble(),
        distanceKm: (json['distance_km'] as num).toDouble(),
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
  final _originCtrl = TextEditingController();
  final _destCtrl   = TextEditingController();
  int _tab = 0;

  List<Delivery> _entregas    = [];
  bool           _loadingPedidos = false;
  String?        _erroPedidos;

  @override
  void initState() {
    super.initState();
    _fetchEntregas();
  }

  Future<void> _fetchEntregas() async {
    final clientId = SessionService.instance.clientId;
    if (clientId == null) return;

    setState(() { _loadingPedidos = true; _erroPedidos = null; });

    try {
      final entregas = await DeliveryService.instance.fetchByClient(clientId);
      if (!mounted) return;
      setState(() { _entregas = entregas; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _erroPedidos = e.toString(); });
    } finally {
      if (mounted) setState(() { _loadingPedidos = false; });
    }
  }

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

    bool dialogAberto = true;

    try {
      final now  = DateTime.now();
      final date = '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}'
                   'T${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}:${now.second.toString().padLeft(2,'0')}';

      final response = await http
          .post(
            Uri.parse(AppConfig.precos),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'origin':      _originCtrl.text.trim(),
              'destination': _destCtrl.text.trim(),
              'date':        date,
              'user_ip':     '192.168.1.1',
              'clientId':   SessionService.instance.clientId,
            }),
          )
          .timeout(AppConfig.timeout);

      if (!mounted) return;
      Navigator.of(context).pop();
      dialogAberto = false;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final price = _PriceResponse.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (_) => _EntregaModal(
            frete:   price,
            origem:  _originCtrl.text.trim(),
            destino: _destCtrl.text.trim(),
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
      if (dialogAberto) Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e'), backgroundColor: const Color(0xFFC62828)),
      );
    }
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
                  ? _buildPedidosTab()
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
    final clientName = SessionService.instance.clientName ?? 'GalaxyWay';
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        height: 170,
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D1A),
          borderRadius: BorderRadius.circular(20),
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            // Estrelas de fundo
            ..._stars,

            // Planeta grande decorativo (direita)
            Positioned(
              top: -45, right: -45,
              child: Container(
                width: 150, height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _C.accent.withValues(alpha: 0.12),
                ),
              ),
            ),
            // Planeta pequeno (esquerda baixo)
            Positioned(
              bottom: -25, left: 100,
              child: Container(
                width: 70, height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF7B2FFF).withValues(alpha: 0.15),
                ),
              ),
            ),

            // Conteúdo
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
              child: Row(
                children: [
                  // Texto
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Galaxy',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Explore os planetas.\nEntregas em toda a galáxia.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 12,
                            height: 1.55,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Ilustração
                  Image.asset(
                    'assets/images/astronauta.png',
                    height: 140,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Estrelas espalhadas no banner
  static const _stars = [
    _Star(left:  18, top: 22, size: 2),
    _Star(left:  55, top: 12, size: 1.5),
    _Star(left:  90, top: 38, size: 1),
    _Star(left:  35, top: 65, size: 1.5),
    _Star(left: 130, top: 18, size: 1),
    _Star(left: 160, top: 50, size: 2),
    _Star(left: 115, top: 80, size: 1),
    _Star(left:  20, top: 110, size: 1.5),
    _Star(left:  70, top: 130, size: 1),
    _Star(left: 145, top: 130, size: 2),
  ];

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
            _buildAddressField(ctrl: _originCtrl, hint: 'Endereço de origem...', dot: _C.primary),

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

            _buildAddressField(ctrl: _destCtrl, hint: 'Endereço de destino...', dot: _C.accent),

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

  Widget _buildAddressField({
    required TextEditingController ctrl,
    required String hint,
    required Color dot,
  }) {
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

  // ── Pedidos Tab ───────────────────────────────────────────────────────────

  Widget _buildPedidosTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Meus Pedidos',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _C.primary),
              ),
              if (_loadingPedidos)
                const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _C.accent),
                )
              else
                IconButton(
                  onPressed: _fetchEntregas,
                  icon: const Icon(Icons.refresh_rounded, color: _C.muted, size: 22),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),
        Expanded(
          child: _buildPedidosBody(),
        ),
      ],
    );
  }

  Widget _buildPedidosBody() {
    if (_loadingPedidos && _entregas.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: _C.accent),
      );
    }

    if (_erroPedidos != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: _C.muted),
            const SizedBox(height: 12),
            Text(
              _erroPedidos!,
              style: const TextStyle(fontSize: 13, color: _C.muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _fetchEntregas,
              child: const Text('Tentar novamente', style: TextStyle(color: _C.accent)),
            ),
          ],
        ),
      );
    }

    if (_entregas.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_rounded, size: 48, color: _C.muted),
            SizedBox(height: 12),
            Text('Nenhuma entrega encontrada.', style: TextStyle(fontSize: 13, color: _C.muted)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _C.accent,
      onRefresh: _fetchEntregas,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        itemCount: _entregas.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _buildEntregaCard(_entregas[i]),
      ),
    );
  }

  Widget _buildEntregaCard(Delivery d) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '#GW-${d.id}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _C.primary),
              ),
              Text(
                d.customerName,
                style: const TextStyle(fontSize: 12, color: _C.muted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Column(
                children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: _C.primary)),
                  Container(width: 1.5, height: 18, color: _C.border),
                  Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: _C.accent)),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.origin,      style: const TextStyle(fontSize: 13, color: _C.primary)),
                    const SizedBox(height: 6),
                    Text(d.destination, style: const TextStyle(fontSize: 13, color: _C.primary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (d.customerNote != null && d.customerNote!.isNotEmpty)
                Expanded(
                  child: Text(
                    d.customerNote!,
                    style: const TextStyle(fontSize: 11, color: _C.muted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              Text(
                d.dataFormatada,
                style: const TextStyle(fontSize: 11, color: _C.muted),
              ),
            ],
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

  const _EntregaModal({
    required this.frete,
    required this.origem,
    required this.destino,
  });

  @override
  State<_EntregaModal> createState() => _EntregaModalState();
}

class _EntregaModalState extends State<_EntregaModal> {
  final _nomeCtrl     = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  final _notaCtrl     = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _telefoneCtrl.dispose();
    _notaCtrl.dispose();
    super.dispose();
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
      final response = await http
          .post(
            Uri.parse(AppConfig.delivery),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'price_calculation_id': widget.frete.id,
              'origin':               widget.origem,
              'destination':          widget.destino,
              'client_id':            SessionService.instance.clientId,
              'customer_name':        _nomeCtrl.text.trim(),
              'customer_phone':       _telefoneCtrl.text.trim(),
              'customer_note':        _notaCtrl.text.trim(),
            }),
          )
          .timeout(AppConfig.timeout);

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pedido confirmado! Buscando rider...'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
      } else {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao criar pedido (${response.statusCode}).'),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível conectar ao servidor.'),
          backgroundColor: Color(0xFFC62828),
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
                      '${widget.frete.distanceKm.toStringAsFixed(2).replaceAll('.', ',')} km',
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
          _buildField(
            ctrl:        _telefoneCtrl,
            label:       'Telefone',
            hint:        'Ex: +351 912 345 678',
            icon:        Icons.phone_outlined,
            inputType:   TextInputType.phone,
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
