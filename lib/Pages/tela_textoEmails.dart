import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crud/services/firestore.dart' as fsFirestore;

class TelaTextoEmails extends StatefulWidget {
  const TelaTextoEmails({Key? key}) : super(key: key);

  @override
  State<TelaTextoEmails> createState() => _TelaTextoEmailState();
}

class _TelaTextoEmailState extends State<TelaTextoEmails> {
  final fsFirestore.FirestoreService firestoreService =
      fsFirestore.FirestoreService();
  final _formKey = GlobalKey<FormState>();

  final _nomeController = TextEditingController();
  final _textoController = TextEditingController();
  bool _ativo = true;
  String? _selectedTag; // Para armazenar a tag selecionada
  List<String> _tags = []; // Lista de tags ativas

  DocumentSnapshot? _selectedDoc; // Documento selecionado para edição

  // Função para preencher o campo de texto com a tag selecionada
  void _adicionarTagNoTexto(String tag) {
    String textoAtual = _textoController.text;
    _textoController.text = textoAtual + " {$tag}"; // Adiciona a tag ao texto
    _textoController.selection = TextSelection.fromPosition(
        TextPosition(offset: _textoController.text.length));
  }

  // Função para substituir tags no texto por valores dinâmicos
  String _substituirTagsPorValores(String texto) {
    // Aqui você pode adicionar as substituições para cada tag
    texto = texto.replaceAll('{nome}', 'João'); // Substituir {nome} por "João"
    texto = texto.replaceAll('{hora}',
        DateTime.now().toString()); // Substituir {hora} pela hora atual
    // Adicione mais substituições conforme necessário
    return texto;
  }

  // ==========================
  // Salvar ou atualizar texto de e-mail
  // ==========================
  Future<void> _salvarTextoEmail() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      String textoFinal = _substituirTagsPorValores(
          _textoController.text.trim()); // Substitui tags por valores dinâmicos

      if (_selectedDoc == null) {
        // Novo cadastro
        await firestoreService.cadastrartextoEmail(
          _nomeController.text.trim(),
          textoFinal,
          !_ativo, // inativar = !ativo
        );
      } else {
        // Atualização
        await firestoreService.alterartextoEmail(
          _selectedDoc!.id,
          _nomeController.text.trim(),
          textoFinal,
          !_ativo, // inativar = !ativo
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
  // Ativar/Inativar texto de e-mail
  // ==========================
  Future<void> _toggleAtivo(DocumentSnapshot doc) async {
    try {
      bool atual = (doc['inativar'] is bool) ? doc['inativar'] : false;
      print('ID do documento: ${doc.id}'); // Verifica o ID do documento

      // Usando a função genérica para alternar o estado
      await firestoreService.toggleAtivoGenerico(
          'textosEmails', doc.id, !atual);

      // Mensagem de sucesso
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              !atual ? "Texto de e-mail inativado" : "Texto de e-mail ativado"),
        ),
      );
    } catch (e) {
      // Exibir erro
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
      _selectedTag = null;
    });
  }

  // ==========================
  // Carregar tags ativas
  // ==========================
  Future<void> _carregarTagsAtivas() async {
    try {
      QuerySnapshot snapshot = await firestoreService.listarTodasTags().get();
      setState(() {
        _tags = snapshot.docs.map((doc) => doc['nome'] as String).toList();
      });
    } catch (e) {
      print('Erro ao carregar tags: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _carregarTagsAtivas(); // Carregar as tags ativas ao inicializar a tela
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Texto de E-mail'),
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

                  // Dropdown para escolher a tag
                  DropdownButton<String>(
                    value: _selectedTag,
                    hint: const Text('Escolha uma tag'),
                    onChanged: (value) {
                      setState(() {
                        _selectedTag = value;
                      });
                      if (value != null) {
                        _adicionarTagNoTexto(value);
                      }
                    },
                    items: _tags.map((tag) {
                      return DropdownMenuItem<String>(
                        value: tag,
                        child: Text(tag),
                      );
                    }).toList(),
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

            // Lista dinâmica de todos os textos de e-mail (ativos e inativos)
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: firestoreService
                    .listarTodosTextosEmail(), // Use uma stream que lista todos
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  final docs = snapshot.data!.docs;

                  if (docs.isEmpty)
                    return const Center(
                        child: Text('Nenhum texto de e-mail cadastrado.'));

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final nome = doc['nome'] ?? '';
                      final texto = doc['textoEmail'] ?? '';
                      final inativo = doc['inativar'] ?? false;

                      return Card(
                        color: inativo ? Colors.grey[200] : Colors.white,
                        child: ListTile(
                          title: Text(nome),
                          subtitle: Text(texto),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Editar
                              IconButton(
                                icon:
                                    const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () {
                                  setState(() {
                                    _selectedDoc = doc;
                                    _nomeController.text = nome;
                                    _textoController.text = texto;
                                    _ativo = !inativo;
                                  });
                                },
                              ),
                              // Ativar/Inativar
                              IconButton(
                                icon: Icon(
                                  inativo
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: inativo ? Colors.red : Colors.green,
                                ),
                                onPressed: () => _toggleAtivo(
                                    doc), // Usando diretamente toggleAtivoGenerico
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
