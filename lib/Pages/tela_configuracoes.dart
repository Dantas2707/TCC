import 'package:flutter/material.dart';
import 'tela_informacoes_pessoais.dart';
import 'tela_guardiao.dart'; // Importa a tela de cadastro de guardião

class SettingsMenuScreen extends StatelessWidget {
  const SettingsMenuScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Informações Pessoais'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PersonalInfoScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.shield),
            title: const Text('Cadastro de Guardião'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TelaGuardiaoUnificada()),
              );
            },
          ),
        ],
      ),
    );
  }
}
