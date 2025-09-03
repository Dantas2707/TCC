// lib/pages/enviar_email_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ⚠️ Ajuste este import conforme o nome real do arquivo onde está a classe EmailBackendService:
import '../services/enviar_email.dart'; // se o seu arquivo se chama enviar_email.dart, troque aqui

class EnviarEmailPage extends StatefulWidget {
  const EnviarEmailPage({Key? key}) : super(key: key);

  @override
  State<EnviarEmailPage> createState() => _EnviarEmailPageState();
}

class _EnviarEmailPageState extends State<EnviarEmailPage> {
  final _toCtrl = TextEditingController();
  final _subjCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

  final _emailBackend = EmailBackendService();

  bool _sending = false;

  // selecionamos por ID de documento (evita diferenças de nome/acentos/maiusc)
  String? _selectedDocId;

  @override
  void dispose() {
    _toCtrl.dispose();
    _subjCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  bool _isEmailValido(String email) {
    final regex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return regex.hasMatch(email);
  }

  Future<void> _onEnviar() async {
    final to = _toCtrl.text.trim();
    final subject = _subjCtrl.text.trim();
    final body = _bodyCtrl.text.trim();

    if (to.isEmpty || subject.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos.')),
      );
      return;
    }

    if (!_isEmailValido(to)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um e-mail válido.')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      await _emailBackend.enviarEmailViaBackend(
        to: to,
        subject: subject,
        body: body,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-mail enviado com sucesso!')),
      );

      _toCtrl.clear();
      _subjCtrl.clear();
      _bodyCtrl.clear();
      setState(() => _selectedDocId = null);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao enviar: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🔹 Consulta DIRETA ao Firestore (coleção: textosEmails)
    final stream = FirebaseFirestore.instance
        .collection('textosEmails')
        .where('inativar', isEqualTo: false) // apenas ativos
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Enviar E-mail')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: stream,
              builder: (context, snapshot) {
                // 1) Loading visual do tamanho do dropdown
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 56,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  );
                }

                // 2) Erro
                if (snapshot.hasError) {
                  return DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: null,
                    items: const [],
                    decoration: const InputDecoration(
                      labelText: 'Selecione o texto de e-mail',
                      border: OutlineInputBorder(),
                      errorText: 'Erro ao carregar textos',
                    ),
                    onChanged: null,
                  );
                }

                // 3) Monta lista de itens a partir dos docs
                final docs = snapshot.data?.docs ??
                    <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                // (se houver docs com inativar == true por engano, filtramos novamente)
                final ativos = docs
                    .where((d) => (d.data()['inativar'] ?? false) == false)
                    .toList();

                // DEBUG opcional
                // debugPrint('Docs ativos: ${ativos.length}');
                // for (final d in ativos) {
                //   debugPrint(' - ${d.id} | ${(d.data()['nome'] ?? '').toString()}');
                // }

                if (ativos.isEmpty) {
                  return DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: null,
                    items: const [],
                    decoration: const InputDecoration(
                      labelText: 'Selecione o texto de e-mail',
                      border: OutlineInputBorder(),
                      helperText: 'Nenhum texto de e-mail ativo encontrado.',
                    ),
                    onChanged: null,
                  );
                }

                // garante que o value atual é válido
                final ids = ativos.map((d) => d.id).toList();
                final safeValue =
                    ids.contains(_selectedDocId) ? _selectedDocId : null;

                return DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: safeValue,
                  items: ativos
                      .map(
                        (d) => DropdownMenuItem<String>(
                          value: d.id,
                          child: Text((d.data()['nome'] ?? '').toString()),
                        ),
                      )
                      .toList(),
                  decoration: const InputDecoration(
                    labelText: 'Selecione o texto de e-mail',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() => _selectedDocId = value);
                    if (value == null) return;

                    // Preenche DIRETO do doc selecionado (sem nova query)
                    final chosen = ativos.firstWhere((d) => d.id == value);
                    final data = chosen.data();
                    _subjCtrl.text = (data['nome'] ?? '').toString();
                    _bodyCtrl.text = (data['textoEmail'] ?? '').toString();

                    // debugPrint('Selecionado: ${chosen.id} | ${_subjCtrl.text} | len=${_bodyCtrl.text.length}');
                  },
                );
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _toCtrl,
              decoration: const InputDecoration(
                labelText: 'Para',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _subjCtrl,
              decoration: const InputDecoration(
                labelText: 'Assunto',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
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
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _sending ? null : _onEnviar,
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
