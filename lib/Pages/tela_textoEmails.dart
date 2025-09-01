import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crud/services/firestore.dart' as fsFirestore;

class TelaCadastrarTextoEmail extends StatefulWidget {
  const TelaCadastrarTextoEmail({Key? key}) : super(key: key);

  @override
  State<TelaCadastrarTextoEmail> createState() =>
      _TelaCadastrarTextoEmailState();
}

class _TelaCadastrarTextoEmailState extends State<TelaCadastrarTextoEmail> {
  final fsFirestore.FirestoreService firestoreService =
      fsFirestore.FirestoreService();
  final _formKey = GlobalKey<FormState>();

  final _nomeController = TextEditingController();
  final _textoController = TextEditingController();
  bool _ativo = true;

  DocumentSnapshot? _selectedDoc; // Documento selecionado para edição

  // ==========================
  // Salvar ou atualizar
  // ==========================
  Future<void> _salvarTextoEmail() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      if (_selectedDoc == null) {
        // Novo cadastro
        await firestoreService.cadastrartextoEmail(
          _nomeController.text.trim(),
          _textoController.text.trim(),
          _ativo,
        );
      } else {
        // Atualização
        await firestoreService.alterartextoemail(
          _selectedDoc!.id,
          _nomeController.text.trim(),
          _textoController.text.trim(),
          _ativo,
        );
        _selectedDoc = null;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mensagem salva com sucesso!')),
      );
      _limparFormulario();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e')),
      );
    }
  }

  // ==========================
  // Buscar por nome
  // ==========================
  Future<void> _buscarTextoEmail(String nome) async {
    final doc = await firestoreService.buscartextoemail(nome);
    if (doc != null) {
      setState(() {
        _selectedDoc = doc;
        _nomeController.text = doc['nome'];
        _textoController.text = doc['textoEmail'];
        _ativo = !(doc['inativar'] ?? false);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Nenhum texto encontrado para '$nome'")),
      );
    }
  }

  // ==========================
  // Inativar / Ativar mensagem
  // ==========================
  Future<void> _toggleAtivo(DocumentSnapshot doc) async {
    try {
      bool atual = doc['inativar'] ?? false;
      await firestoreService.alterartextoemail(
        doc.id,
        doc['nome'],
        doc['textoEmail'],
        !atual,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(!atual ? "Mensagem inativada" : "Mensagem ativada")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao atualizar status: $e")),
      );
    }
  }

  // ==========================
  // Limpar formulário
  // ==========================
  void _limparFormulario() {
    _formKey.currentState!.reset();
    _nomeController.clear();
    _textoController.clear();
    setState(() {
      _ativo = true;
      _selectedDoc = null;
    });
  }

  // ==========================
  // Build da tela
  // ==========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Textos de E-mail'),
        backgroundColor: Colors.pink,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Campo de busca
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Buscar mensagem pelo nome',
                border: OutlineInputBorder(),
              ),
              onFieldSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  _buscarTextoEmail(value.trim());
                }
              },
            ),
            const SizedBox(height: 16),

            // Formulário de cadastro / edição
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nomeController,
                    decoration: const InputDecoration(
                      labelText: 'Nome da Mensagem',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Campo obrigatório'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _textoController,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Texto da Mensagem',
                      border: OutlineInputBorder(),
                      hintText: 'Digite o conteúdo (pode conter HTML)',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Campo obrigatório'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: _ativo,
                        onChanged: (v) => setState(() => _ativo = v ?? true),
                      ),
                      const Text('Ativo'),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: _limparFormulario,
                        child: const Text('Limpar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _salvarTextoEmail,
                      child: Text(
                          _selectedDoc == null ? 'Cadastrar' : 'Atualizar'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Lista dinâmica das mensagens
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: firestoreService.listartextoemailAtivo(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return const CircularProgressIndicator();
                  final docs = snapshot.data!.docs;

                  if (docs.isEmpty)
                    return const Center(
                        child: Text('Nenhuma mensagem cadastrada.'));

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final nome = doc['nome'] ?? '';
                      final inativo = doc['inativar'] ?? false;

                      return Card(
                        color: inativo ? Colors.grey[200] : Colors.white,
                        child: ListTile(
                          title: Text(nome),
                          subtitle: Text(doc['textoEmail'] ?? ''),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _selectedDoc = doc;
                                    _nomeController.text = doc['nome'];
                                    _textoController.text = doc['textoEmail'];
                                    _ativo = !inativo;
                                  });
                                },
                              ),
                              IconButton(
                                icon: Icon(
                                  inativo ? Icons.delete : Icons.visibility_off,
                                ),
                                onPressed: () => _toggleAtivo(doc),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
