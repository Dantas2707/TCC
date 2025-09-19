import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'tela_config.dart';
import 'tela_tipo_ocorrencia.dart';
import 'tela_login.dart'; // Tela de login
import 'tela_usuario.dart';  // Tela de cadastro de usuário

class TelaAdminHome extends StatelessWidget {
  const TelaAdminHome({super.key});

  // Função de logout
  Future<void> _logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut(); // Desloga o usuário
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => TelaLogin()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao deslogar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Painel do Administrador')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Botão para cadastrar usuário
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => TelaUsuario()), // Agora o botão leva à tela de cadastro de usuário
                );
              },
              child: const Text('Cadastrar Usuário'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ConfigScreen()),
                );
              },
              child: const Text('Configurações'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => TipoOcorrencia()),
                );
              },
              child: const Text('Tipos de Ocorrência'),
            ),
            const SizedBox(height: 40),
            // Botão de Logout
            ElevatedButton(
              onPressed: () => _logout(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, // vermelho para destacar
              ),
              child: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}
