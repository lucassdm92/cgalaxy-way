import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

  static Color statusColor(String? status) {
    switch (status?.toUpperCase()) {
      case 'PENDING':    return const Color(0xFFF59E0B);
      case 'PICKED_UP':  return const Color(0xFF3B82F6);
      case 'DELIVERED':  return const Color(0xFF22C55E);
      case 'CANCELLED':  return const Color(0xFFEF4444);
      default:           return muted;
    }
  }

  static String statusLabel(String? status) {
    switch (status?.toUpperCase()) {
      case 'PENDING':    return 'Pendente';
      case 'PICKED_UP':  return 'A caminho';
      case 'DELIVERED':  return 'Entregue';
      case 'CANCELLED':  return 'Cancelado';
      default:           return status ?? '—';
    }
  }
}

// ─── Pulsing Dot ─────────────────────────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
      ),
    );
  }
}

// ─── Pedidos Screen ───────────────────────────────────────────────────────────

class PedidosScreen extends StatefulWidget {
  const PedidosScreen({super.key});

  @override
  State<PedidosScreen> createState() => _PedidosScreenState();
}

class _PedidosScreenState extends State<PedidosScreen> {
  List<Delivery> _entregas       = [];
  bool           _loading        = false;
  String?        _erro;

  @override
  void initState() {
    super.initState();
    _fetchEntregas();
  }

  Future<void> _fetchEntregas() async {
    final userName = SessionService.instance.username;
    debugPrint('[PedidosScreen] _fetchEntregas: userName=$userName');
    if (userName == null) {
      debugPrint('[PedidosScreen] _fetchEntregas: username nulo, abortando.');
      return;
    }

    setState(() { _loading = true; _erro = null; });

    try {
      debugPrint('[PedidosScreen] _fetchEntregas: buscando entregas...');
      final entregas = await DeliveryService.instance.fetchByClient(userName);
      debugPrint('[PedidosScreen] _fetchEntregas: ${entregas.length} entrega(s) recebida(s).');
      if (!mounted) return;
      setState(() { _entregas = entregas; });
    } catch (e) {
      debugPrint('[PedidosScreen] _fetchEntregas: erro -> $e');
      if (!mounted) return;
      setState(() { _erro = e.toString(); });
    } finally {
      if (mounted) setState(() { _loading = false; });
      debugPrint('[PedidosScreen] _fetchEntregas: finalizado.');
    }
  }

  @override
  Widget build(BuildContext context) {
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
              if (_loading)
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
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading && _entregas.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: _C.accent));
    }

    if (_erro != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: _C.muted),
            const SizedBox(height: 12),
            Text(
              _erro!,
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
                (d.externalDeliveryCode != null && d.externalDeliveryCode!.isNotEmpty)
                    ? d.externalDeliveryCode!
                    : 'Aguardando ID do pedido',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: (d.externalDeliveryCode != null && d.externalDeliveryCode!.isNotEmpty)
                      ? _C.primary
                      : _C.muted,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _C.statusColor(d.status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (d.status == 'PENDING' || d.status == 'PICKED_UP') ...[
                      _PulsingDot(color: _C.statusColor(d.status)),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      _C.statusLabel(d.status),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _C.statusColor(d.status),
                      ),
                    ),
                  ],
                ),
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
          const Divider(color: _C.border, height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.person_outline_rounded, size: 14, color: _C.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  d.customerName,
                  style: const TextStyle(fontSize: 11, color: _C.muted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.phone_outlined, size: 14, color: _C.muted),
              const SizedBox(width: 6),
              Text(
                d.customerPhone,
                style: const TextStyle(fontSize: 11, color: _C.muted),
              ),
            ],
          ),
          if (d.customerEmail != null && d.customerEmail!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.email_outlined, size: 14, color: _C.muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    d.customerEmail!,
                    style: const TextStyle(fontSize: 11, color: _C.muted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (d.customerNote != null && d.customerNote!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.notes_rounded, size: 14, color: _C.muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    d.customerNote!,
                    style: const TextStyle(fontSize: 11, color: _C.muted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (d.passwordToCollect != null) ...[
            const SizedBox(height: 10),
            const Divider(color: _C.border, height: 1),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _C.accent.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _C.accent.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Código para fornecer ao rider',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _C.accent),
                  ),
                  Text(
                    '${d.passwordToCollect}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _C.accent),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
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
}
