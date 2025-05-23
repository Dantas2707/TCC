import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Aponte para o seu servidor Dart que usa Gmail SMTP
const String backendUrl = 'https://backendapp-vz3r.onrender.com';

Future<void> enviarEmailViaBackend({
  required String to,
  required String subject,
  required String body,
}) async {
  final resp = await http.post(
    Uri.parse(backendUrl),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'to': to, 'subject': subject, 'body': body}),
  );
  if (resp.statusCode != 200) {
    throw Exception('Falha ao enviar: ${resp.body}');
  }
}

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Envio de E-mail',
        home: const EnviarEmailPage(),
      );
}

class EnviarEmailPage extends StatefulWidget {
  const EnviarEmailPage({Key? key}) : super(key: key);
  @override
  _EnviarEmailPageState createState() => _EnviarEmailPageState();
}

class _EnviarEmailPageState extends State<EnviarEmailPage> {
  final _toCtrl    = TextEditingController();
  final _subjCtrl  = TextEditingController();
  final _bodyCtrl  = TextEditingController();
  bool  _sending   = false;

  @override
  void dispose() {
    _toCtrl.dispose();
    _subjCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _onEnviar() async {
    final to      = _toCtrl.text.trim();
    final subject = _subjCtrl.text.trim();
    final body    = _bodyCtrl.text.trim();
    if (to.isEmpty || subject.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      await enviarEmailViaBackend(to: to, subject: subject, body: body);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-mail enviado com sucesso!')),
      );
      _toCtrl.clear();
      _subjCtrl.clear();
      _bodyCtrl.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao enviar: $e')),
      );
    } finally {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enviar E-mail')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _toCtrl,
              decoration: const InputDecoration(
                labelText: 'Para', border: OutlineInputBorder()),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _subjCtrl,
              decoration: const InputDecoration(
                labelText: 'Assunto', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _bodyCtrl,
                decoration: const InputDecoration(
                  labelText: 'Corpo da mensagem', border: OutlineInputBorder()),
                maxLines: null,
                expands: true,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _sending ? null : _onEnviar,
                child: _sending
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Enviar E-mail'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
