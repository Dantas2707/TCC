import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'tela_config.dart';
import 'tela_tipo_ocorrencia.dart';
import 'tela_login.dart';
import 'tela_usuario.dart';
import 'tela_enviar_email.dart';
import 'tela_textoEmails.dart';
import 'tela_configuracoes.dart';
import 'tela_ocorrencia.dart';
import 'tela_localizacao.dart';
import 'tela_sos.dart';
import 'tela_registrar_ocorrencia.dart';

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
      appBar: AppBar(
        title: const Text('Painel do Administrador'),
        backgroundColor: const Color.fromARGB(255, 255, 0, 0), // Cor do AppBar
      ),
      body: Padding(
        padding:
            const EdgeInsets.all(16.0), // Adicionando padding para o conteúdo
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Botão para cadastrar usuário
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => TelaUsuario()),
                  );
                },
                child: const Text('Cadastrar Usuário'),
              ),
              const SizedBox(height: 15), // Espaçamento entre os botões

              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => OcorrenciaPage()),
                  );
                },
                child: const Text('Registrar ocorrência'),
              ),
              const SizedBox(height: 15), // Espaçamento entre os botões

              // Botão de configurações
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ConfigScreen()),
                  );
                },
                child: const Text('Configurar'),
              ),
              const SizedBox(height: 15), // Espaçamento entre os botões

              // Botão para tipos de ocorrência
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => TipoOcorrencia()),
                  );
                },
                child: const Text('Tipos de Ocorrência'),
              ),
              const SizedBox(height: 15), // Espaçamento entre os botões

              // Botão para Enviar Email
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => EnviarEmailPage()),
                  );
                },
                child: const Text('Enviar Email'),
              ),
              const SizedBox(height: 15), // Espaçamento entre os botões

              // Botão para Enviar Email
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => OcorrenciasPage()),
                  );
                },
                child: const Text('Minhas ocorrência'),
              ),
              const SizedBox(height: 15), // Espaçamento entre os botões

              // Botão para Enviar Email
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => GuardianMapPage()),
                  );
                },
                child: const Text('localização da vítima'),
              ),
              const SizedBox(height: 15), // Espaçamento entre os botões

              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => TelaVitimaSOS()),
                  );
                },
                child: const Text('SOS'),
              ), // Espaçamento entre os botões
              const SizedBox(height: 15),
              // Botão para Texto de Emails
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => TelaTextoEmails()),
                  );
                },
                child: const Text('Texto de Emails'),
              ),
              const SizedBox(
                  height: 15), // Maior espaçamento antes do botão de logout

              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SettingsMenuScreen()),
                  );
                },
                child: const Text('Configurações'),
              ),
              // Botão de Logout
              ElevatedButton(
                onPressed: () => _logout(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors
                      .red, // Cor vermelha para destacar o botão de logout
                  padding: const EdgeInsets.symmetric(
                      vertical: 15.0, horizontal: 40.0),
                ),
                child: const Text(
                  'Logout',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
