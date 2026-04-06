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
