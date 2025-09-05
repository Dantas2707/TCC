import 'package:flutter/material.dart';
import '../services/enviar_email.dart' as es; // Usando 'es' como prefixo para EmailBackendService
import '../services/firestore.dart' as fs;  // Usando 'fs' como prefixo para FirestoreService

class EnviarEmailPage extends StatefulWidget {
  const EnviarEmailPage({Key? key}) : super(key: key);

  @override
  State<EnviarEmailPage> createState() => _EnviarEmailPageState();
}

class _EnviarEmailPageState extends State<EnviarEmailPage> {
  final _toCtrl = TextEditingController(); // Controle para o e-mail de destino
  final _subjCtrl = TextEditingController(); // Controle para o assunto
  final _bodyCtrl = TextEditingController(); // Controle para o corpo da mensagem
  bool _sending = false; // Flag para indicar se está enviando
  String? _selectedMessage; // Armazena o texto da mensagem selecionada

  late fs.FirestoreService _firestoreService;  // Usando FirestoreService com o prefixo 'fs'
  List<String> _textosEmails = []; // Lista de textos de e-mails

  @override
  void initState() {
    super.initState();
    _firestoreService = fs.FirestoreService(); // Usando o serviço FirestoreService do firestore.dart com o prefixo 'fs'
    _loadTextosEmails();
  }

  // Carregar os textos de e-mails ativos
  Future<void> _loadTextosEmails() async {
    final textos = await _firestoreService.listarNomesTextosEmails();  // Corrigindo o uso do método
    setState(() {
      _textosEmails = textos;
    });
  }

  // Preencher os campos com o conteúdo da mensagem selecionada
  Future<void> _onMessageSelected(String? messageName) async {
    if (messageName == null) return;

    // Buscar o documento do e-mail selecionado
    final textoEmail = await _firestoreService.buscarTextoEmail(messageName);  // Corrigindo o uso do método

    if (textoEmail != null) {
      // Preencher os campos com os dados do texto selecionado
      _subjCtrl.text = textoEmail['nome'] ?? '';
      _bodyCtrl.text = textoEmail['textoEmail'] ?? '';
    }
  }

  // Função para enviar e-mail dinamicamente
  Future<void> _enviarEmailDinamico() async {
  final to = _toCtrl.text.trim();
  final subject = _subjCtrl.text.trim();
  final body = _bodyCtrl.text.trim();  // Corpo do e-mail em texto simples
  final htmlBody = "<h1>Exemplo de corpo em HTML</h1><p>Este é um exemplo de e-mail com HTML.</p>"; // Corpo em HTML

  // Verifique se todos os campos estão preenchidos
  if (to.isEmpty || subject.isEmpty || body.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preencha todos os campos.')),
    );
    return;
  }

  try {
    setState(() => _sending = true);

    // Chama o serviço de backend para enviar o e-mail
    final emailService = es.EmailBackendService(); // Usando o serviço de enviar e-mail do 'enviar_email.dart' com o prefixo 'es'
    await emailService.enviarEmailViaBackend(
      to: to,
      subject: subject,
      body: body,  // Corpo em texto simples
      htmlBody: htmlBody, // Corpo em HTML (se fornecido)
    );

    // Exibe a mensagem de sucesso
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('E-mail enviado com sucesso!')),
    );
  } catch (e) {
    // Exibe a mensagem de erro
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erro ao enviar: $e')),
    );
  } finally {
    setState(() => _sending = false);
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enviar E-mail')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Dropdown para selecionar o texto do e-mail
            DropdownButton<String>(
              value: _selectedMessage,
              hint: const Text('Selecione um texto de e-mail'),
              isExpanded: true,
              onChanged: (value) {
                setState(() {
                  _selectedMessage = value;
                });
                _onMessageSelected(value); // Preencher os campos
              },
              items: _textosEmails.map((String message) {
                return DropdownMenuItem<String>(
                  value: message,
                  child: Text(message),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // Campo para o e-mail de destino
            TextField(
              controller: _toCtrl,
              decoration: const InputDecoration(
                labelText: 'Para',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),

            // Campo para o assunto
            TextField(
              controller: _subjCtrl,
              decoration: const InputDecoration(
                labelText: 'Assunto',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Campo para o corpo da mensagem
            Expanded(
              child: TextField(
                controller: _bodyCtrl,
                decoration: const InputDecoration(
                  labelText: 'Corpo da mensagem',
                  border: OutlineInputBorder(),
                ),
                maxLines: null,
                expands: true,
              ),
            ),
            const SizedBox(height: 16),

            // Botão para enviar e-mail dinamicamente
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _sending ? null : _enviarEmailDinamico,
                child: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
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
