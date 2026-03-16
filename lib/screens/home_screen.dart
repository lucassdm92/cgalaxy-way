import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isOnline = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Informações da Loja")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: ListTile(
                leading: CircleAvatar(backgroundColor: isOnline ? Colors.green : Colors.red),
                title: Text(isOnline ? "LOJA ONLINE" : "LOJA OFFLINE"),
                trailing: Switch(
                  value: isOnline,
                  onChanged: (val) => setState(() => isOnline = val),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text("Endereço: Av. Principal, 1000 - Centro", style: TextStyle(fontSize: 16)),
            const Text("Telefone: (11) 99999-9999", style: TextStyle(fontSize: 16)),
            const Text("Manager: Lucas", style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}