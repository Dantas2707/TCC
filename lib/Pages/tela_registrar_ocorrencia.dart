import 'dart:io'; // Necessário para manipular arquivos locais
import 'package:crud/services/firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_messenger/flutter_background_messenger.dart';
import 'package:permission_handler/permission_handler.dart';

// Definição correta da classe OcorrenciaPage
class OcorrenciaPage extends StatefulWidget {
  @override
  _OcorrenciaPageState createState() => _OcorrenciaPageState();
}

class _OcorrenciaPageState extends State<OcorrenciaPage> {
  final FirestoreService firestoreService = FirestoreService();
  final TextEditingController _relatoController = TextEditingController();
  final TextEditingController _textoSocorroController = TextEditingController();
  bool _enviarParaGuardiao = false;
  String? _tipoOcorrenciaSelecionado;
  String? _gravidadeSelecionada;

  // Lista para armazenar os anexos selecionados
  List<PlatformFile> _anexos = [];

  static const int maxFileSize = 5 * 1024 * 1024;
  String? _ocorrenciaId;  // ID da ocorrência

  @override
  void initState() {
    super.initState();
    _textoSocorroController.text = "Atenção! Estou sob ameaça! Preciso de ajuda!";
  }

  // Função para registrar a ocorrência
  void _registrarOcorrencia() async {
    if (_tipoOcorrenciaSelecionado == null || _gravidadeSelecionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Selecione um tipo de ocorrência e gravidade')),
      );
      return;
    }

    String relato = _relatoController.text.trim();
    String textoSocorro = _textoSocorroController.text.trim();

    if (relato.isEmpty || textoSocorro.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Preencha todos os campos')),
      );
      return;
    }

    try {
      await firestoreService.addOcorrencia(
        _tipoOcorrenciaSelecionado!,
        _gravidadeSelecionada!,
        relato,
        textoSocorro,
        _enviarParaGuardiao,
        anexos: _anexos,
      );

      // Limpar os campos e anexos após registrar
      _relatoController.clear();
      _textoSocorroController.clear();
      setState(() {
        _tipoOcorrenciaSelecionado = null;
        _gravidadeSelecionada = null;
        _enviarParaGuardiao = false;
        _anexos = [];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ocorrência registrada com sucesso')),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao registrar ocorrência: $e')),
      );
    }
  }

  // Função para finalizar a ocorrência
  Future<void> _finalizarOcorrencia() async {
    if (_ocorrenciaId != null) {
      try {
        // Atualiza o status da ocorrência para 'finalizado'
        await FirebaseFirestore.instance.collection('ocorrencias').doc(_ocorrenciaId).update({
          'status': 'finalizado',
          'timestamp': Timestamp.now(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ocorrência finalizada com sucesso')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao finalizar a ocorrência: $e')),
        );
      }
    }
  }

  // Função para enviar o SOS (mensagem para os guardiões)
  void _sendSOS() {
    print('S.O.S Enviado');
    // Aqui você pode implementar a lógica para enviar a mensagem de socorro (SMS ou outra ação)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Registrar ocorrência'),
        backgroundColor: Colors.pink,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dropdown para selecionar o tipo de ocorrência
              StreamBuilder<QuerySnapshot>(
                stream: firestoreService.gettipoOcorrenciaStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return CircularProgressIndicator();
                  }
                  if (snapshot.hasError) {
                    return Text('Erro: ${snapshot.error}');
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Text(
                      'Nenhum tipo de ocorrência encontrado. Entre em contato com o administrador.',
                      style: TextStyle(color: Colors.red),
                    );
                  }
                  List<String> tiposOcorrencia = snapshot.data!.docs.map((doc) {
                    return doc['tipoOcorrencia'] as String;
                  }).toList();
                  return DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Selecione o tipo de ocorrência',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _tipoOcorrenciaSelecionado = value;
                      });
                    },
                    value: _tipoOcorrenciaSelecionado,
                    items: tiposOcorrencia.map((tipo) {
                      return DropdownMenuItem<String>(
                        value: tipo,
                        child: Text(tipo),
                      );
                    }).toList(),
                  );
                },
              ),
              SizedBox(height: 16),
              // Dropdown para selecionar a gravidade
              StreamBuilder<QuerySnapshot>(
                stream: firestoreService.getgravidadeStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return CircularProgressIndicator();
                  }
                  if (snapshot.hasError) {
                    return Text('Erro: ${snapshot.error}');
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Text('Nenhuma gravidade encontrada.');
                  }
                  List<String> gravidades = snapshot.data!.docs.map((doc) {
                    return doc['gravidade'] as String;
                  }).toList();
                  gravidades.removeWhere((grav) => grav.toLowerCase() == 'gravissíma');
                  return DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Selecione a gravidade',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _gravidadeSelecionada = value;
                      });
                    },
                    value: _gravidadeSelecionada,
                    items: gravidades.map((grav) {
                      return DropdownMenuItem<String>(
                        value: grav,
                        child: Text(grav),
                      );
                    }).toList(),
                  );
                },
              ),
              SizedBox(height: 16),
              // Campo de texto para o relato
              TextFormField(
                controller: _relatoController,
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
              // Campo de texto para o texto de socorro
              TextFormField(
                controller: _textoSocorroController,
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
              // Checkbox para enviar SMS ao guardião
              Row(
                children: [
                  Checkbox(
                    value: _enviarParaGuardiao,
                    onChanged: (bool? value) {
                      setState(() {
                        _enviarParaGuardiao = value!;
                      });
                    },
                  ),
                  Text('Mandar texto socorro para guardião'),
                ],
              ),
              SizedBox(height: 16),
              // Botões de ação
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: _registrarOcorrencia,
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all(Colors.red),
                    ),
                    child: Text('Registrar'),
                  ),
                  ElevatedButton(
                    onPressed: _sendSOS,
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all(Colors.orange),
                    ),
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