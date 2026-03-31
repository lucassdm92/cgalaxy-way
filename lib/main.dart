import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'config/app_config.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DeliveryApp());
}

// ─── App Root ───────────────────────────────────────────────────────────────

class DeliveryApp extends StatelessWidget {
  const DeliveryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DeliveryApp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'DM Sans',
        scaffoldBackgroundColor: const Color(0xFFF7F6F2),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF5C3A)),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

// ─── Constants ──────────────────────────────────────────────────────────────

class AppColors {
  static const bg         = Color(0xFFF7F6F2);
  static const surface    = Color(0xFFFFFFFF);
  static const primary    = Color(0xFF1A1A2E);
  static const accent     = Color(0xFFFF5C3A);
  static const accentLight = Color(0xFFFFF0ED);
  static const muted      = Color(0xFF8A8A99);
  static const border     = Color(0xFFEAEAE6);
}

// ─── Price Response ───────────────────────────────────────────────────────────

class PriceResponse {
  final int id;
  final double totalPrice;
  final double distanceKm;

  const PriceResponse({
    required this.id,
    required this.totalPrice,
    required this.distanceKm,
  });

  factory PriceResponse.fromJson(Map<String, dynamic> json) => PriceResponse(
        id:         json['id'] as int,
        totalPrice: (json['total_price'] as num).toDouble(),
        distanceKm: (json['distance_km'] as num).toDouble(),
      );

  String get totalFormatado =>
      'R\$ ${totalPrice.toStringAsFixed(2).replaceAll('.', ',')}';
}

// ─── Data Models ─────────────────────────────────────────────────────────────

enum PedidoStatus { aguardandoRider, entregue, problema }

class Pedido {
  final String codigo;
  final String origem;
  final String destino;
  final PedidoStatus status;
  final String data;

  const Pedido({
    required this.codigo,
    required this.origem,
    required this.destino,
    required this.status,
    required this.data,
  });
}

// ─── Home Screen ─────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _originController = TextEditingController(text: '61 Francis Street');
  final _destController   = TextEditingController(text: '33 St Columba s Rd Upper');
  int _selectedTab = 0;

  final List<Pedido> _pedidos = const [
    Pedido(
      codigo: '#GW-1042',
      origem: 'Av. Paulista, 1000',
      destino: 'Rua Augusta, 500',
      status: PedidoStatus.entregue,
      data: 'Ontem, 14:32',
    ),
    Pedido(
      codigo: '#GW-1041',
      origem: 'Moema, 340',
      destino: 'Vila Olímpia, 87',
      status: PedidoStatus.aguardandoRider,
      data: 'Hoje, 09:15',
    ),
    Pedido(
      codigo: '#GW-1039',
      origem: 'Jardins, 22',
      destino: 'Itaim Bibi, 150',
      status: PedidoStatus.problema,
      data: 'Seg, 13 Jan',
    ),
    Pedido(
      codigo: '#GW-1035',
      origem: 'Pinheiros, 77',
      destino: 'Lapa, 210',
      status: PedidoStatus.entregue,
      data: 'Sex, 10 Jan',
    ),
    Pedido(
      codigo: '#GW-1031',
      origem: 'Consolação, 450',
      destino: 'Bela Vista, 90',
      status: PedidoStatus.aguardandoRider,
      data: 'Qui, 9 Jan',
    ),
    Pedido(
      codigo: '#GW-1028',
      origem: 'Perdizes, 180',
      destino: 'Santa Cecília, 55',
      status: PedidoStatus.entregue,
      data: 'Qua, 8 Jan',
    ),
    Pedido(
      codigo: '#GW-1025',
      origem: 'Brooklin, 320',
      destino: 'Santo André, 600',
      status: PedidoStatus.problema,
      data: 'Ter, 7 Jan',
    ),
    Pedido(
      codigo: '#GW-1020',
      origem: 'Tatuapé, 210',
      destino: 'Penha, 440',
      status: PedidoStatus.entregue,
      data: 'Seg, 6 Jan',
    ),
    Pedido(
      codigo: '#GW-1015',
      origem: 'Santana, 88',
      destino: 'Tucuruvi, 130',
      status: PedidoStatus.entregue,
      data: 'Dom, 5 Jan',
    ),
    Pedido(
      codigo: '#GW-1010',
      origem: 'Ipiranga, 77',
      destino: 'Sacomã, 200',
      status: PedidoStatus.aguardandoRider,
      data: 'Sáb, 4 Jan',
    ),
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _originController.dispose();
    _destController.dispose();
    super.dispose();
  }

  void _swapAddresses() {
    final temp = _originController.text;
    _originController.text = _destController.text;
    _destController.text   = temp;
  }

  Future<void> _solicitarDelivery() async {
    if (_originController.text.trim().isEmpty ||
        _destController.text.trim().isEmpty) {
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
      final now = DateTime.now();
      final date =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}'
          'T${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

      final body = jsonEncode({
        'origin': _originController.text.trim(),
        'destination': _destController.text.trim(),
        'date': date,
        'user_ip': '192.168.1.1',
      });

      final response = await http
          .post(
            Uri.parse(AppConfig.precos),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(AppConfig.timeout);

      if (!mounted) return;
      Navigator.of(context).pop();
      dialogAberto = false;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final price = PriceResponse.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (_) => _ConfirmacaoSheet(
            frete: price,
            origem: _originController.text.trim(),
            destino: _destController.text.trim(),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro do servidor (${response.statusCode}). Tente novamente.'),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (dialogAberto) Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro: $e'),
          backgroundColor: const Color(0xFFC62828),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _selectedTab == 1
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
                          _buildSectionTitle('Novo pedido'),
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

  // ── Pedidos Tab ───────────────────────────────────────────────────────────

  Widget _buildPedidosTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Text(
            'Meus Pedidos',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            itemCount: _pedidos.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _buildPedidoCard(_pedidos[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildPedidoCard(Pedido pedido) {
    final (Color bgColor, Color textColor, String label, IconData icon) =
        switch (pedido.status) {
      PedidoStatus.entregue => (
          const Color(0xFFE8F5E9),
          const Color(0xFF2E7D32),
          'Entregue',
          Icons.check_circle_rounded,
        ),
      PedidoStatus.aguardandoRider => (
          const Color(0xFFFFF8E1),
          const Color(0xFFF9A825),
          'Aguardando Rider',
          Icons.access_time_rounded,
        ),
      PedidoStatus.problema => (
          const Color(0xFFFFEBEE),
          const Color(0xFFC62828),
          'Pedido com problema',
          Icons.error_outline_rounded,
        ),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                pedido.codigo,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 12, color: textColor),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildRouteRow(pedido.origem, pedido.destino),
          const SizedBox(height: 10),
          Text(
            pedido.data,
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteRow(String origem, String destino) {
    return Row(
      children: [
        Column(
          children: [
            Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
              ),
            ),
            Container(width: 1.5, height: 18, color: AppColors.border),
            Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                origem,
                style: const TextStyle(fontSize: 13, color: AppColors.primary),
              ),
              const SizedBox(height: 6),
              Text(
                destino,
                style: const TextStyle(fontSize: 13, color: AppColors.primary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ENTREGANDO EM',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.2,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'São Paulo, SP',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down,
                      color: AppColors.accent, size: 20),
                ],
              ),
            ],
          ),
          GestureDetector(
            onTap: () {/* Navegar para perfil */},
            child: CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.accent,
              child: const Text(
                'JS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
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
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          children: [
            // Círculos decorativos
            Positioned(
              top: -30, right: -30,
              child: Container(
                width: 140, height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withOpacity(0.15),
                ),
              ),
            ),
            Positioned(
              bottom: -50, right: 20,
              child: Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withOpacity(0.08),
                ),
              ),
            ),
            // Conteúdo
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '⚡ Rápido e seguro',
                    style: TextStyle(
                      color: Color(0xFFFF8C69),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Envie qualquer coisa,\nonde quiser',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Rastreamento em tempo real e\nentrega garantida na sua cidade.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ],
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
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Campo origem
            _buildAddressField(
              controller: _originController,
              hint: 'Endereço de origem...',
              dotColor: AppColors.primary,
            ),

            // Separador com botão de swap
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Row(
                children: [
                  const SizedBox(width: 4),
                  Column(
                    children: [
                      Container(
                          width: 1.5, height: 12,
                          color: AppColors.border),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Text('até',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.muted)),
                  const Spacer(),
                  GestureDetector(
                    onTap: _swapAddresses,
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border),
                        color: AppColors.surface,
                      ),
                      child: const Center(
                        child: Text('⇅',
                            style: TextStyle(fontSize: 14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Campo destino
            _buildAddressField(
              controller: _destController,
              hint: 'Endereço de destino...',
              dotColor: AppColors.accent,
            ),

            const SizedBox(height: 12),

            // Botão CTA
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _solicitarDelivery,
                icon: const Icon(Icons.location_on, size: 18),
                label: const Text(
                  'Ver rotas disponíveis',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
    required TextEditingController controller,
    required String hint,
    required Color dotColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 10, height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dotColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.primary,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 14,
                ),
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
    final items = [
      {'icon': Icons.home_rounded,      'label': 'Home'},
      {'icon': Icons.inventory_2_rounded,'label': 'Pedidos'},
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (i) {
          final active = i == _selectedTab;
          return GestureDetector(
            onTap: () => setState(() => _selectedTab = i),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  items[i]['icon'] as IconData,
                  color: active ? AppColors.accent : AppColors.muted,
                  size: 24,
                ),
                const SizedBox(height: 4),
                Text(
                  items[i]['label'] as String,
                  style: TextStyle(
                    fontSize: 10,
                    color: active ? AppColors.accent : AppColors.muted,
                    fontWeight:
                    active ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                if (active) ...[
                  const SizedBox(height: 3),
                  Container(
                    width: 5, height: 5,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accent,
                    ),
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

// ─── Confirmação Sheet ────────────────────────────────────────────────────────

class _ConfirmacaoSheet extends StatefulWidget {
  final PriceResponse frete;
  final String origem;
  final String destino;

  const _ConfirmacaoSheet({
    required this.frete,
    required this.origem,
    required this.destino,
  });

  @override
  State<_ConfirmacaoSheet> createState() => _ConfirmacaoSheetState();
}

class _ConfirmacaoSheetState extends State<_ConfirmacaoSheet> {
  final _nomeController     = TextEditingController();
  final _telefoneController = TextEditingController();
  final _notasController    = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nomeController.dispose();
    _telefoneController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  Future<void> _confirmarPedido() async {
    if (_nomeController.text.trim().isEmpty ||
        _telefoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha o nome e o telefone do cliente.')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final body = jsonEncode({
        'price_calculation_id': widget.frete.id,
        'origin':               widget.origem,
        'destination':          widget.destino,
        'customer_name':        _nomeController.text.trim(),
        'customer_phone':       _telefoneController.text.trim(),
        'customer_note':        _notasController.text.trim(),
      });

      final response = await http
          .post(
            Uri.parse(AppConfig.delivery),
            headers: {'Content-Type': 'application/json'},
            body: body,
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
            content: Text('Erro ao criar pedido (${response.statusCode}). Tente novamente.'),
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
          decoration: const BoxDecoration(
            color: AppColors.surface,
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
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Resumo do pedido',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),

              // Rota
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary,
                          ),
                        ),
                        Container(width: 1.5, height: 20, color: AppColors.border),
                        Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.origem,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.destino,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Preço
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildValorRow(
                      'Distância',
                      '${widget.frete.distanceKm.toStringAsFixed(2).replaceAll('.', ',')} km',
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(color: AppColors.border, height: 1),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          widget.frete.totalFormatado,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Dados do cliente
              _buildSheetField(
                controller: _nomeController,
                label: 'Nome do cliente',
                hint: 'Ex: João Silva',
                icon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: 10),
              _buildSheetField(
                controller: _telefoneController,
                label: 'Telefone',
                hint: 'Ex: +351 912 345 678',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 10),
              _buildSheetField(
                controller: _notasController,
                label: 'Notas',
                hint: 'Instruções para o rider, referências...',
                icon: Icons.notes_rounded,
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              // Botões
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Recusar',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _loading ? null : _confirmarPedido,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.primary.withOpacity(0.6),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Aceitar',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                            ),
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

  Widget _buildValorRow(String label, String valor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
        Text(valor, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
      ],
    );
  }

  Widget _buildSheetField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Icon(icon, size: 18, color: AppColors.muted),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  maxLines: maxLines,
                  style: const TextStyle(fontSize: 14, color: AppColors.primary),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
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
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.accent),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Buscando rotas...',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Aguarde até 20 segundos',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}