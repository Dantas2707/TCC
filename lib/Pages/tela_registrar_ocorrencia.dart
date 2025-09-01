import 'dart:io';
import 'package:crud/services/firestore.dart' as fsFirestore; // Prefixo fsFirestore
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_messenger/flutter_background_messenger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:crud/services/enviar_email.dart' as fsEnviarEmail; // Prefixo fsEnviarEmail

/// Modelo para cada guardião
class _Guardiao {
  final String id;
  final String nome;
  final String telefone;
  final String email;  // novo campo
  bool selecionado;
  _Guardiao({
    required this.id,
    required this.nome,
    required this.telefone,
    required this.email,  // novo parâmetro
    this.selecionado = false,
  });
}

class OcorrenciaPage extends StatefulWidget {
  @override
  _OcorrenciaPageState createState() => _OcorrenciaPageState();
}

class _OcorrenciaPageState extends State<OcorrenciaPage> {
  // Usando o prefixo fsFirestore para se referir ao FirestoreService de firestore.dart
  final fsFirestore.FirestoreService _service = fsFirestore.FirestoreService();
  final _relatoCtrl = TextEditingController();
  final _textoSocorroCtrl = TextEditingController();
  final _messenger = FlutterBackgroundMessenger();

  String? _tipoSelecionado;
  String? _gravidadeSelecionada;

  List<PlatformFile> _anexos = [];
  static const int maxFileSize = 5 * 1024 * 1024;

  List<_Guardiao> _guardioes = [];

  @override
  void initState() {
    super.initState();
    _textoSocorroCtrl.text = "Atenção! Estou sob ameaça! Preciso de ajuda!";
    _loadGuardioes();
  }

  Future<void> _loadGuardioes() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance.collection('usuario').doc(uid).get();
    if (!doc.exists) return;
    final data = doc.data()!;
    final ids = List<String>.from(data['guardioes'] ?? []);
    final list = <_Guardiao>[];
    for (var gid in ids) {
      final gd = await FirebaseFirestore.instance.collection('usuario').doc(gid).get();
      if (!gd.exists) continue;
      final d = gd.data()!;
      list.add(_Guardiao(
        id: gid,
        nome: d['nome'] ?? 'Sem nome',
        telefone: d['numerotelefone'] ?? '',
        email: d['email'] ?? '',
      ));
    }
    setState(() => _guardioes = list);
  }

  Future<void> _pickAnexos() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['jpg','jpeg','png','mp4','mov','avi','mp3','wav'],
    );
    if (result != null) {
      setState(() => _anexos.addAll(result.files));
    }
  }

  // Função para enviar e-mail para os guardiões
  Future<void> enviarEmailGuardioes() async {
    final selecionados = _guardioes.where((g) => g.selecionado).toList();
    if (selecionados.isEmpty) return;

    const assunto = 'Pedido de Socorro';
    final corpo = _textoSocorroCtrl.text.trim();

    for (var g in selecionados) {
      // 1) Log de depuração
      debugPrint('🔔 Tentando enviar e-mail para: ${g.email}');
      if (g.email.isEmpty) {
        debugPrint('⚠️ E-mail vazio para o guardião ${g.nome}');
        continue;
      }

      try {
        await fsEnviarEmail.enviarEmailViaBackend( // Usando o prefixo fsEnviarEmail
          to: g.email,
          subject: assunto,
          body: corpo,
        );
        debugPrint('✅ E-mail enviado com sucesso para ${g.email}');
      } catch (e, s) {
        // 2) Agora imprimimos o stacktrace
        debugPrint('❌ Erro ao enviar e-mail para ${g.email}: $e');
        debugPrint('$s');
        // opcional: exibir um SnackBar só para esse destinatário
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha no e-mail de ${g.nome}: $e')),
        );
      }
    }

    // 3) Feedback final
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Tentativa de e-mail para ${selecionados.length} guardião(ões)')),
    );
  }

  Future<void> _registrarOcorrencia() async {
    // 1) valida dropdowns
    if (_tipoSelecionado == null || _gravidadeSelecionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Selecione tipo e gravidade')),
      );
      return;
    }

    // 2) valida texto
    final relato = _relatoCtrl.text.trim();
    final textoSocorro = _textoSocorroCtrl.text.trim();
    if (relato.isEmpty || textoSocorro.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Preencha todos os campos')),
      );
      return;
    }
    if (relato.length < 6 || relato.length > 255) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Relato deve ter entre 6 e 255 caracteres')),
      );
      return;
    }

    // 3) grava no Firestore
    try {
      await _service.addOcorrencia(
        _tipoSelecionado!,
        _gravidadeSelecionada!,
        relato.toLowerCase(),
        textoSocorro,
        _guardioes.any((g) => g.selecionado),
        anexos: _anexos,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao registrar ocorrência: $e')),
      );
      return;
    }

    // 4) envia SMS para guardiões selecionados
    final selecionados = _guardioes.where((g) => g.selecionado).toList();
    if (selecionados.isNotEmpty) {
      if (!await Permission.sms.request().isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Permissão de SMS negada')),
        );
      } else {
        for (var g in selecionados) {
          try {
            await _messenger.sendSMS(
              phoneNumber: g.telefone,
              message: textoSocorro,
            );
          } catch (_) {}
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('SMS enviado para ${selecionados.length} guardião(ões)')),
        );
      }
    }

    // 4.1) envia e-mails para guardiões selecionados
    await enviarEmailGuardioes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Registrar ocorrência'),
        backgroundColor: Colors.pink,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // -- tipo de ocorrência --
              StreamBuilder<QuerySnapshot>(
                stream: _service.gettipoOcorrenciaStream(),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting)
                    return CircularProgressIndicator();
                  final docs = snap.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Text(
                      'Nenhum tipo de ocorrência encontrado. Entre em contato com o administrador.',
                      style: TextStyle(color: Colors.red),
                    );
                  }
                  final tipos = docs.map((d) => d['tipoOcorrencia'] as String).toList();
                  return DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Tipo de ocorrência',
                      border: OutlineInputBorder(),
                    ),
                    value: _tipoSelecionado,
                    items: tipos
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) => setState(() => _tipoSelecionado = v),
                  );
                },
              ),
              SizedBox(height: 16),

              // -- gravidade --
              StreamBuilder<QuerySnapshot>(
                stream: _service.getgravidadeStream(),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting)
                    return CircularProgressIndicator();
                  final docs = snap.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Text(
                      'Nenhuma gravidade cadastrada. Entre em contato com o administrador.',
                      style: TextStyle(color: Colors.red),
                    );
                  }
                  final gravs = docs
                      .map((d) => d['gravidade'] as String)
                      .where((g) => g.toLowerCase() != 'gravissíma')
                      .toList();
                  return DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Gravidade',
                      border: OutlineInputBorder(),
                    ),
                    value: _gravidadeSelecionada,
                    items: gravs
                        .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                        .toList(),
                    onChanged: (v) => setState(() => _gravidadeSelecionada = v),
                  );
                },
              ),
              SizedBox(height: 16),

              // -- relato --
              TextFormField(
                controller: _relatoCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Relato',
                  hintText: 'Digite o seu relato aqui (6 a 255 caracteres)',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.red[50],
                ),
              ),
              SizedBox(height: 16),

              // -- texto socorro --
              TextFormField(
                controller: _textoSocorroCtrl,
                maxLines: 3,
                maxLength: 255,
                decoration: InputDecoration(
                  labelText: 'Texto Socorro',
                  hintText: 'Digite a mensagem de socorro aqui',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.red[50],
                ),
              ),
              SizedBox(height: 16),

              // -- anexar mídia --
              ElevatedButton.icon(
                onPressed: _pickAnexos,
                icon: Icon(Icons.attach_file),
                label: Text('Anexar Mídia'),
              ),
              if (_anexos.isNotEmpty) ...[
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _anexos.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final file = entry.value;
                    return Chip(
                      label: Text(file.name, overflow: TextOverflow.ellipsis),
                      deleteIcon: Icon(Icons.close),
                      onDeleted: () => setState(() => _anexos.removeAt(idx)),
                    );
                  }).toList(),
                ),
                SizedBox(height: 16),
              ],

              // -- lista de guardiões --
              if (_guardioes.isEmpty)
                Text('Você não possui guardiões cadastrados.')
              else ...[
                Text('Selecione para quais enviar SMS:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                ..._guardioes.map((g) => CheckboxListTile(
                      title: Text(g.nome),
                      subtitle: Text(g.telefone),
                      value: g.selecionado,
                      onChanged: (v) => setState(() => g.selecionado = v!),
                    )),
                SizedBox(height: 16),
              ],

              // -- botões --
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: _registrarOcorrencia,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: Text('Registrar'),
                  ),
                  // manter o botão S.O.S manual
                  ElevatedButton(
                    onPressed: () => _registrarOcorrencia(),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    child: Text('S.O.S'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
