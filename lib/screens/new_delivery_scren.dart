import 'package:flutter/material.dart';

class NewDeliveryScreen extends StatefulWidget {
  const NewDeliveryScreen({super.key});

  @override
  State<NewDeliveryScreen> createState() => _NewDeliveryScreenState();
}

class _NewDeliveryScreenState extends State<NewDeliveryScreen> {
  final _origin = TextEditingController();
  final _dest = TextEditingController();
  double? _valor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Solicitar Delivery")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(controller: _origin, decoration: const InputDecoration(labelText: "Origem")),
            TextField(controller: _dest, decoration: const InputDecoration(labelText: "Destino")),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => setState(() => _valor = 25.50), // Simulação Java
              child: const Text("CALCULAR FRETE"),
            ),
            if (_valor != null) ...[
              Text("Valor: R\$ $_valor", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ElevatedButton(onPressed: () {}, child: const Text("SOLICITAR AGORA")),
            ]
          ],
        ),
      ),
    );
  }
}