import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crud/services/firestore.dart' as fsFirestore;
import 'package:crud/services/enviar_email.dart' as es; // Para as tags

class TelaTextoEmails extends StatefulWidget {
  const TelaTextoEmails({Key? key}) : super(key: key);

  @override
  State<TelaTextoEmails> createState() => _TelaTextoEmailsState();
}

class _TelaTextoEmailsState extends State<TelaTextoEmails> {
  final fsFirestore.FirestoreService firestoreService =
      fsFirestore.FirestoreService();
  final _formKey = GlobalKey<FormState>();

  final _nomeController = TextEditingController();
  final _textoController = TextEditingController();
  bool _ativo = true;

  // Alterado para QueryDocumentSnapshot, pois estamos trabalhando com Firestore diretamente
  QueryDocumentSnapshot<Object?>? _selectedDoc;

  // Para armazenar as tags e a tag selecionada
  String? _selectedTag;
  final List<String> _tags = es.EmailBackendService.supportedTags;

  // Variável para alternar entre modos
  bool isEditing = false;

  // ==========================
  // Função de buscar o texto de e-mail
  // ==========================
  Future<void> _buscarTextoEmail() async {
    final nome = _nomeController.text.trim();
    if (nome.isEmpty) return;

    final docSnapshot = await firestoreService.buscarTextoEmail(nome);
    if (docSnapshot != null) {
      setState(() {
        _nomeController.text = docSnapshot['nome'] ?? '';
        _textoController.text = docSnapshot['textoEmail'] ?? docSnapshot['corpo'] ?? '';
        _selectedDoc = docSnapshot;  // Agora, armazenando o QueryDocumentSnapshot
        isEditing = true;  // Muda para o modo de edição
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Modelo não encontrado ou inativo.')),
      );
    }
  }

  // ==========================
  // Salvar ou atualizar texto de e-mail
  // ==========================
  Future<void> _salvarTextoEmail() async {
    // Verifique se o formulário é válido
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos obrigatórios!')),
      );
      return;
    }

    try {
      if (_selectedDoc == null) {
        // Novo cadastro
        await firestoreService.cadastrartextoEmail(
          _nomeController.text.trim(),
          _textoController.text.trim(),
          !_ativo, // inativar = !ativo
        );
      } else {
        // Atualização
        await firestoreService.alterarTextoEmail(
          _selectedDoc!.id,  // Agora usando o 'id' do QueryDocumentSnapshot
          _nomeController.text.trim(),
          _textoController.text.trim(),
          !_ativo,
        );
        _selectedDoc = null;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Texto de e-mail salvo com sucesso!')),
      );
      _limparFormulario();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e')),
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
      isEditing = false; // Retorna para o modo de criação
    });
  }

  // ==========================
  // Inserir Tag no Texto
  // ==========================
  void _insertTagInFocusedField() {
    final tag = _selectedTag;
    if (tag == null) return;

    // Definindo qual campo será modificado (corpo do texto)
    final targetCtrl = _textoController;

    final textoAtual = targetCtrl.text;
    targetCtrl.text = '$textoAtual $tag';
    targetCtrl.selection =
        TextSelection.fromPosition(TextPosition(offset: targetCtrl.text.length));
  }

  // ==========================
  // Ativar/Inativar texto de e-mail
  // ==========================
  Future<void> _toggleAtivo(QueryDocumentSnapshot<Object?> doc) async {
    try {
      final bool atual = doc['inativar'] ?? false;
      await firestoreService.toggleAtivoGenerico('textosEmails', doc.id, !atual);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(!atual ? 'Texto de e-mail inativado' : 'Texto de e-mail ativado'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar status: $e')),
      );
    }
  }

  // ==========================
  // Build da tela
  // ==========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Texto de E-mail' : 'Cadastrar Texto de E-mail'),
        backgroundColor: Colors.pink,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Formulário de cadastro/edição
            Form(
              key: _formKey,
              child: Column(
                children: [
                  // Nome do texto de e-mail
                  TextFormField(
                    controller: _nomeController,
                    decoration: const InputDecoration(
                      labelText: 'Nome do Texto de E-mail',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Campo obrigatório'
                        : null,
                  ),
                  const SizedBox(height: 12),

                  // Texto do e-mail
                  TextFormField(
                    controller: _textoController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Texto do E-mail',
                      border: OutlineInputBorder(),
                      hintText: 'Ex: Conteúdo do e-mail',
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

                  // Botão de salvar
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _salvarTextoEmail,
                      child: Text(isEditing ? 'Atualizar' : 'Cadastrar'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ==========================
            // Dropdown de TAGS (da lista)
            // ==========================
            Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedTag,
                    hint: const Text('Tags disponíveis'),
                    isExpanded: true,
                    onChanged: (v) => setState(() => _selectedTag = v),
                    items: _tags
                        .map((t) => DropdownMenuItem<String>(
                              value: t,
                              child: Text(t),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _insertTagInFocusedField,
                  icon: const Icon(Icons.input),
                  label: const Text('Inserir'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ==========================
            // Lista dinâmica de todos os textos de e-mail (ativos e inativos)
            // ==========================
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: firestoreService.listarTodosTextosEmail(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final docs = snapshot.data!.docs;

                  if (docs.isEmpty) return const Center(child: Text('Nenhum texto de e-mail cadastrado.'));

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final nome = doc['nome'] ?? '';
                      final textoEmail = doc['textoEmail'] ?? '';
                      final inativo = doc['inativar'] ?? false;

                      return Card(
                        color: inativo ? Colors.grey[200] : Colors.white,
                        child: ListTile(
                          title: Text(nome),
                          subtitle: Text(textoEmail),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Editar
                              IconButton(
                                icon: Icon(
                                  _selectedDoc?.id == doc.id
                                      ? Icons.edit
                                      : Icons.edit_outlined,
                                  color: _selectedDoc?.id == doc.id
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                onPressed: () {
                                  setState(() {
                                    // Alterna entre editar e sair do modo de edição
                                    if (_selectedDoc?.id == doc.id) {
                                      _selectedDoc = null; // Desmarcar e sair do modo de edição
                                      isEditing = false; // Sair do modo de edição
                                    } else {
                                      _selectedDoc = doc;
                                      _nomeController.text = nome;
                                      _textoController.text = textoEmail;
                                      _ativo = !inativo;
                                      isEditing = true; // Entrar no modo de edição
                                    }
                                  });
                                },
                              ),
                              // Ativar/Inativar
                              IconButton(
                                icon: Icon(
                                  inativo ? Icons.visibility_off : Icons.visibility,
                                  color: inativo ? Colors.red : Colors.green,
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
