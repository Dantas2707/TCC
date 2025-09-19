import 'package:crud/Pages/tela_usuario.dart';
import 'package:flutter/material.dart';
import 'tela_tipo_ocorrencia.dart';
import 'tela_gravidade.dart';
import 'tela_configuracoes.dart';
import 'tela_registrar_ocorrencia.dart';
import 'tela_login.dart';
import 'tela_guardiao.dart';
import 'tela_ocorrencia.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crud/services/enviar_email.dart';
import 'tela_config.dart';
import 'tela_textoEmails.dart';
import 'tela_enviar_email.dart';
import 'localizacao.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  // Função para deslogar o usuário
  Future<void> _logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut(); // Desloga o usuário
      // Navega de volta para a tela de login após deslogar
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } catch (e) {
      // Em caso de erro, você pode mostrar uma mensagem de erro
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao deslogar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Home Page")),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TelaUsuario()),
                );
              },
              child: const Text('Cadastrar usuário'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const TipoOcorrencia()),
                );
              },
              child: const Text('Ir para Tela Tipo Ocorrência'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const Gravidade()),
                );
              },
              child: const Text('Ir para Tela de gravidade'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SettingsMenuScreen()),
                );
              },
              child: const Text('Ir para configurações'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          OcorrenciaPage()), // Navega para a tela de ocorrência
                );
              },
              child: const Text('Registrar Ocorrência'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          LoginScreen()), // Navega para a tela de login
                );
              },
              child: const Text('Tela de login'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          OcorrenciasPage()), // Navega para minhas ocorrenciass
                );
              },
              child: const Text('Minhas ocorrências'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          EnviarEmailPage()), 
                );
              },
              child: const Text('Enviar emails'),
            ),
            const SizedBox(height: 10),
            // Botão de logout
            ElevatedButton(
              onPressed: () => _logout(context), // Chama a função de logout
              child: const Text('Logout'),
              style: ElevatedButton.styleFrom(),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          ConfigScreen()), // Navega para Tela da config
                );
              },
              child: const Text('tela da config'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          TelaTextoEmails()), // Navega para Tela da config
                );
              },
              child: const Text('tela de textos de emails'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          TelaLocalizacao()), // Navega para Tela da config
                );
              },
              child: const Text('tela de localização'),
            ),
          ],
        ),
      ),
    );
  }
}