import 'package:flutter/material.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Meus Deliverys")),
      body: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('ID')),
            DataColumn(label: Text('Origem')),
            DataColumn(label: Text('Destino')),
            DataColumn(label: Text('Valor')),
            DataColumn(label: Text('Status')),
          ],
          rows: const [
            DataRow(cells: [
              DataCell(Text('001')),
              DataCell(Text('Rua A')),
              DataCell(Text('Rua B')),
              DataCell(Text('R\$ 15,00')),
              DataCell(Chip(label: Text('Em trânsito'), backgroundColor: Colors.amber)),
            ]),
          ],
        ),
      ),
    );
  }
}