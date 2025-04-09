// arquivo: ocorrencia_page.dart
import 'dart:io'; // Necessário para manipular arquivos locais
import 'package:crud/services/firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_messenger/flutter_background_messenger.dart';
import 'package:permission_handler/permission_handler.dart';

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

  // Tamanho máximo dos arquivos em bytes (ex: 5 MB)
  static const int maxFileSize = 5 * 1024 * 1024;

  // Instância do FlutterBackgroundMessenger para envio de SMS em background
  final FlutterBackgroundMessenger messenger = FlutterBackgroundMessenger();

  // UID do usuário logado (usando FirebaseAuth)
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;

  // Função para selecionar arquivos (vídeo, foto e áudio)
  Future<void> _pickAnexos() async {
    // Permite selecionar múltiplos arquivos dos tipos especificados.
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'mp4', 'mov', 'avi', 'mp3', 'wav'],
    );

    if (result != null) {
      List<PlatformFile> arquivosValidados = [];
      for (var file in result.files) {
        if (file.size > maxFileSize) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('O arquivo ${file.name} excede o tamanho permitido (5 MB).'),
            ),
          );
        } else {
          arquivosValidados.add(file);
        }
      }
      setState(() {
        _anexos = arquivosValidados;
      });
    }
  }

  // Função para solicitar a permissão para envio de SMS
  Future<bool> _requestSmsPermission() async {
    PermissionStatus status = await Permission.sms.request();
    return status.isGranted;
  }

  // Envia SMS em background para um número específico (guardião)
  Future<void> _sendSmsToGuardian(String message, String phoneNumber) async {
    try {
      final bool success = await messenger.sendSMS(
        phoneNumber: phoneNumber,
        message: message,
      );
      if (success) {
        print("SMS enviado para $phoneNumber");
      } else {
        print("Falha ao enviar SMS para $phoneNumber");
      }
    } catch (e) {
      print("Erro ao enviar SMS para $phoneNumber: $e");
    }
  }

  // Função para registrar a ocorrência e enviar SMS para os guardiões, se solicitado
  void _registrarOcorrencia() async {
    // Validação dos dropdowns
    if (_tipoOcorrenciaSelecionado == null || _gravidadeSelecionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Selecione um tipo de ocorrência e gravidade')),
      );
      return;
    }

    // Recupera e valida os textos
    String relato = _relatoController.text.trim();
    String textoSocorro = _textoSocorroController.text.trim();

    if (relato.isEmpty || textoSocorro.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Preencha todos os campos')),
      );
      return;
    }

    if (relato.length < 6 || relato.length > 255) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('O relato deve conter entre 6 e 255 caracteres')),
      );
      return;
    }

    // Converte o relato para letras minúsculas
    relato = relato.toLowerCase();

    // Validação adicional para anexos (opcional, pois já é feita no pick)
    for (var file in _anexos) {
      if (file.size > maxFileSize) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('O arquivo ${file.name} excede o tamanho permitido')),
        );
        return;
      }
    }

    try {
      // Registra a ocorrência no Firestore, incluindo os anexos
      await firestoreService.addOcorrencia(
        _tipoOcorrenciaSelecionado!,
        _gravidadeSelecionada!,
        relato,
        textoSocorro,
        _enviarParaGuardiao,
        anexos: _anexos,
      );

      // Se a opção de enviar SMS estiver marcada, envia o texto de socorro para os guardiões
      if (_enviarParaGuardiao) {
        // Busca o documento do usuário para obter a lista de guardiões
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('usuario')
            .doc(_currentUserId)
            .get();

        // Acessa de forma segura o campo 'guardioes'
        List<dynamic> guardianIds = [];
        if (userDoc.exists && userDoc.data() != null) {
          final Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
          if (data.containsKey('guardioes')) {
            guardianIds = data['guardioes'];
          }
        }

        if (guardianIds.isNotEmpty) {
          // Solicita permissão para envio de SMS
          if (await _requestSmsPermission()) {
            // Para cada guardião, obtém seu documento e, se houver número, envia o SMS
            for (var guardianId in guardianIds) {
              DocumentSnapshot guardianDoc = await FirebaseFirestore.instance
                  .collection('usuario')
                  .doc(guardianId)
                  .get();

              if (guardianDoc.exists && guardianDoc.data() != null) {
                final Map<String, dynamic> guardianData = guardianDoc.data() as Map<String, dynamic>;
                String phoneNumber = guardianData['numerotelefone'] ?? "";
                if (phoneNumber.isNotEmpty) {
                  await _sendSmsToGuardian(textoSocorro, phoneNumber);
                } else {
                  print("Número de telefone não encontrado para o guardião: $guardianId");
                }
              }
            }
          } else {
            print("Permissão para enviar SMS não concedida.");
          }
        } else {
          print("Nenhum guardião encontrado para o usuário.");
        }
      }

      // Limpa os campos e a lista de anexos
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Registrar ocorrência'),
        backgroundColor: Colors.pink,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView( // Evita overflow caso haja muitos anexos
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
                  suffixIcon: IconButton(
                    icon: Icon(Icons.attach_file),
                    onPressed: _pickAnexos,
                  ),
                ),
              ),
              SizedBox(height: 16),
              // Campo de texto para o texto de socorro
              TextFormField(
                controller: _textoSocorroController,
                maxLines: 3,
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
              // Exibe os anexos selecionados (se houver)
              _anexos.isNotEmpty
                  ? Wrap(
                      spacing: 8.0,
                      children: _anexos
                          .map((file) => Chip(label: Text(file.name)))
                          .toList(),
                    )
                  : Container(),
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
                    onPressed: () {
                      // Ação para S.O.S (pode ser similar ao envio de SMS, se desejado)
                      print('S.O.S Enviado');
                    },
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all(Colors.red),
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
