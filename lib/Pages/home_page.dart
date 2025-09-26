import 'package:crud/Pages/tela_config.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'tela_usuario.dart';  // Tela de cadastro de usuário
import 'tela_tipo_ocorrencia.dart';
import 'tela_configuracoes.dart';
import 'tela_registrar_ocorrencia.dart';
import 'tela_ocorrencia.dart';
import 'tela_login.dart';
import 'tela_localizacao.dart';
import 'tela_sos.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  final String adminEmail = 'aplicativo2025tcc@gmail.com';

  Future<void> _logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
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
    final user = FirebaseAuth.instance.currentUser;
    final bool isAdmin = user?.email == adminEmail;

    return Scaffold(
      appBar: AppBar(
        title: const Text("InTrouble"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Botões só para ADMIN
              if (isAdmin) ...[
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => TelaUsuario()), // O botão agora vai para a tela de cadastro de usuário
                    );
                  },
                  child: const Text('Cadastrar Usuário'),  // Botão para cadastrar usuário
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TipoOcorrencia()),
                    );
                  },
                  child: const Text('Ir para Tela Tipo Ocorrência'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ConfigScreen()),
                    );
                  },
                  child: const Text('Configurações (Admin - E-mail)'),
                ),
                const SizedBox(height: 20),
              ],

              // Botão de CONFIG do USUÁRIO (pessoais + guardião) — só para usuário comum
              if (!isAdmin) ...[
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      // Se você já tem a SettingsMenuScreen, deixe como está:
                      MaterialPageRoute(builder: (_) => const SettingsMenuScreen()),
                      // Se NÃO tiver essa tela criada, troque a linha acima por:
                      // MaterialPageRoute(builder: (_) => const _UserSettingsScreen()),
                    );
                  },
                  child: const Text('Configurações'),
                ),
                const SizedBox(height: 20),
              ],

              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => OcorrenciaPage()),
                  );
                },
                child: const Text('Registrar Ocorrência'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => OcorrenciasPage()),
                  );
                },
                child: const Text('Minhas ocorrências'),
              ),
                const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => GuardianMapPage()),
                  );
                },
                child: const Text('localização da vítima'),                
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => TelaVitimaSOS()),
                  );
                },
                child: const Text('SOS'),                
              ),

              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _logout(context),
                child: const Text('Logout'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
