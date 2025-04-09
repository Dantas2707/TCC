import 'dart:io'; // Necessário para manipular arquivos locais (mobile)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';

class FirestoreService {
  final CollectionReference tipoOcorrencia =
      FirebaseFirestore.instance.collection('tipoOcorrencia');

  final CollectionReference usuario =
      FirebaseFirestore.instance.collection("usuario");

  final CollectionReference gravidade =
      FirebaseFirestore.instance.collection('gravidade');

  final CollectionReference ocorrencias =
      FirebaseFirestore.instance.collection('ocorrencias'); // Coleção para as ocorrências

  final CollectionReference guardioes =
      FirebaseFirestore.instance.collection("guardiões"); // Coleção de guardiões

  // ==============================================================
  // FUNÇÕES PARA CONVITES DE GUARDIÃO (ABORDAGEM 4 - Muitos para Muitos)
  // ==============================================================

  /// Envia convite para um guardião por e-mail.
  /// [email] é o e-mail do possível guardião e [idUsuario] é o ID do usuário que está enviando o convite.
  Future<void> convidarGuardiaoPorEmail(String email, String idUsuario) async {
    try {
      // Verifica se o e-mail corresponde a um usuário registrado na coleção 'usuario'
      QuerySnapshot userSnapshot =
          await usuario.where('email', isEqualTo: email).get();

      if (userSnapshot.docs.isNotEmpty) {
        // O usuário com esse e-mail existe (possível guardião)
        String idGuardiao = userSnapshot.docs.first.id;

        // Verifica se já existe uma relação de guardião entre esse usuário e o guardião
        QuerySnapshot duplicado = await guardioes
            .where('id_usuario', isEqualTo: idUsuario)
            .where('id_guardiao', isEqualTo: idGuardiao)
            .get();

        if (duplicado.docs.isNotEmpty) {
          throw Exception("Esta relação de guardião já existe.");
        }

        // Obtém o nome do usuário que está enviando o convite
        DocumentSnapshot senderDoc = await usuario.doc(idUsuario).get();
        String nomeUsuario = senderDoc.get('nome');

        // Cria um documento de convite na coleção 'guardiões'
        await guardioes.add({
          'id_usuario': idUsuario, // ID do usuário que está enviando o convite
          'nome_usuario': nomeUsuario, // Nome do usuário que enviou o convite
          'id_guardiao': idGuardiao, // ID do possível guardião
          'invitado': true, // Marca o documento como convite
          'timestamp': Timestamp.now(),
          'status': 'pendente', // Status inicial: pendente
        });

        print("Convite enviado para o e-mail: $email");
      } else {
        print("Usuário não encontrado. Enviando convite para baixar o app.");
        // Aqui você pode implementar o envio de um convite para baixar o aplicativo.
      }
    } catch (e) {
      print("Erro ao convidar guardião: $e");
      throw Exception("Erro ao convidar guardião: $e");
    }
  }

  /// Aceita o convite de guardião.
  /// [conviteDocId] é o ID do documento de convite na coleção 'guardiões',
  /// [idUsuario] é o ID do usuário que enviou o convite e [idGuardiao] é o ID do guardião (usuário logado).
  Future<void> aceitarConviteGuardiao(
      String conviteDocId, String idUsuario, String idGuardiao) async {
    try {
      // Atualiza o documento do convite para "aceito"
      await guardioes.doc(conviteDocId).update({
        'status': 'aceito',
        'timestamp': Timestamp.now(),
      });

      // Atualiza o documento do usuário que enviou o convite:
      // Adiciona o ID do guardião à lista de guardiões desse usuário
      await usuario.doc(idUsuario).update({
        'guardioes': FieldValue.arrayUnion([idGuardiao]),
      });

      // Atualiza o documento do guardião para marcá-lo como guardião
      await usuario.doc(idGuardiao).update({
        'guardiao': true,
      });
    } catch (e) {
      print("Erro ao aceitar convite: $e");
      throw Exception("Erro ao aceitar convite: $e");
    }
  }

  /// Recusa o convite de guardião.
  /// [conviteDocId] é o ID do documento do convite a ser atualizado.
  Future<void> recusarConviteGuardiao(String conviteDocId) async {
    try {
      await guardioes.doc(conviteDocId).update({
        'status': 'recusado',
        'timestamp': Timestamp.now(),
      });
    } catch (e) {
      print("Erro ao recusar convite: $e");
      throw Exception("Erro ao recusar convite: $e");
    }
  }

  /// Retorna um stream dos convites pendentes para o guardião com [idGuardiao].
  Stream<QuerySnapshot> getConvitesRecebidosGuardiao(String idGuardiao) {
    return guardioes
        .where('id_guardiao', isEqualTo: idGuardiao)
        .where('status', isEqualTo: 'pendente')
        .snapshots();
  }

  // ==============================================================
  // OUTRAS FUNÇÕES (CRUD de TipoOcorrencia, Gravidade, Usuário, Ocorrências)
  // ==============================================================

  Future<void> addTipoOcorrencia(String tipoOcorrenciaText) async {
    String tipoOcorrenciaFormatado = tipoOcorrenciaText.trim().toLowerCase();
    if (tipoOcorrenciaFormatado.length < 3 ||
        tipoOcorrenciaFormatado.length > 100) {
      throw Exception(
          "O tipo de ocorrência deve ter entre 3 e 100 caracteres.");
    }
    QuerySnapshot duplicado = await tipoOcorrencia
        .where('tipoOcorrencia', isEqualTo: tipoOcorrenciaFormatado)
        .get();
    if (duplicado.docs.isNotEmpty) {
      throw Exception("Este tipo de ocorrência já existe.");
    }
    await tipoOcorrencia.add({
      'tipoOcorrencia': tipoOcorrenciaFormatado,
      'timestamp': Timestamp.now(),
      'inativar': false,
    });
  }

  Stream<QuerySnapshot> gettipoOcorrenciaStream() {
    return tipoOcorrencia
        .where('inativar', isEqualTo: false)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> atualizarTipoOcorrencia(String docID, String novoTipo) async {
    String tipoFormatado = novoTipo.trim().toLowerCase();
    if (tipoFormatado.isEmpty || tipoFormatado.length < 3) {
      throw Exception("O tipo de ocorrência deve ter no mínimo 3 caracteres.");
    }
    await tipoOcorrencia.doc(docID).update({
      'tipoOcorrencia': tipoFormatado,
      'timestamp': Timestamp.now(),
    });
  }

  Future<void> inativarTipoOcorrencia(String docID) {
    return tipoOcorrencia.doc(docID).update({
      'timestamp': Timestamp.now(),
      'inativar': true,
    });
  }

  Future<void> addgravidade(String gravidadeText) async {
    String gravidadeFormatado = gravidadeText.trim().toLowerCase();
    if (gravidadeFormatado.length < 3 || gravidadeFormatado.length > 100) {
      throw Exception("A gravidade deve ter entre 3 e 100 caracteres.");
    }
    QuerySnapshot duplicado = await gravidade
        .where('gravidade', isEqualTo: gravidadeFormatado)
        .get();
    if (duplicado.docs.isNotEmpty) {
      throw Exception("Esta gravidade já existe.");
    }
    await gravidade.add({
      'gravidade': gravidadeFormatado,
      'timestamp': Timestamp.now(),
      'inativar': false,
    });
  }

  Stream<QuerySnapshot> getgravidadeStream() {
    return gravidade
        .where('inativar', isEqualTo: false)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> atualizargravidade(String docID, String novagravidade) async {
    String gravidadeFormatado = novagravidade.trim().toLowerCase();
    if (gravidadeFormatado.length < 3 || gravidadeFormatado.length > 100) {
      throw Exception(
          "A gravidade deve ter no mínimo 3 e no máximo 100 caracteres.");
    }
    await gravidade.doc(docID).update({
      'gravidade': gravidadeFormatado,
      'timestamp': Timestamp.now(),
    });
  }

  Future<void> inativargravidade(String docID) {
    return gravidade.doc(docID).update({
      'timestamp': Timestamp.now(),
      'inativar': true,
    });
  }

  Future<void> addUsuario(String uid, Map<String, dynamic> dadosUsuario) async {
    await usuario.doc(uid).set({
      'nome': dadosUsuario['nome'],
      'email': dadosUsuario['email'],
      'cpf': dadosUsuario['cpf'],
      'numerotelefone': dadosUsuario['numerotelefone'],
      'dataNasc': dadosUsuario['dataNasc'],
      'sexo': dadosUsuario['sexo'],
      'inativar': false,
      'timestamp': Timestamp.now(),
    });
  }

  Stream<QuerySnapshot> getUsuarioStream() {
    return usuario
        .where('inativar', isEqualTo: false)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> atualizarUsuario(
      String uid, Map<String, dynamic> dadosUsuario) async {
    dadosUsuario['timestamp'] = Timestamp.now();
    return await usuario.doc(uid).update(dadosUsuario);
  }

  Future<void> inativarUsuario(String uid) {
    return usuario.doc(uid).update({
      'timestamp': Timestamp.now(),
      'inativar': true,
    });
  }

  // ==================================================================
  // MÉTODO DE ADIÇÃO DE OCORRÊNCIA COM UPLOAD DE ANEXOS
  // ==================================================================
  Future<void> addOcorrencia(
    String tipoOcorrencia,
    String gravidade,
    String relato,
    String textoSocorro,
    bool enviarParaGuardiao, {
    List<PlatformFile>? anexos,
  }) async {
    List<String> anexosUrls = [];

    // Se houver anexos, faz o upload de cada arquivo para o Firebase Storage.
    if (anexos != null && anexos.isNotEmpty) {
      for (var file in anexos) {
        try {
          String url = await uploadFile(file);
          anexosUrls.add(url);
        } catch (e) {
          print('Erro ao fazer upload do anexo ${file.name}: $e');
          // Aqui você pode optar por interromper o processo ou continuar sem esse arquivo.
        }
      }
    }

    // Salva a ocorrência no Firestore, incluindo os URLs dos anexos.
    await ocorrencias.add({
      'tipoOcorrencia': tipoOcorrencia,
      'gravidade': gravidade,
      'relato': relato,
      'textoSocorro': textoSocorro,
      'enviarParaGuardiao': enviarParaGuardiao,
      'anexos': anexosUrls,
      'timestamp': Timestamp.now(),
    });
  }

  Stream<QuerySnapshot> getOcorrenciasStream() {
    return ocorrencias.orderBy('timestamp', descending: true).snapshots();
  }

  // ==================================================================
  // Função auxiliar para fazer o upload de um único arquivo para o Firebase Storage.
  // ==================================================================
  Future<String> uploadFile(PlatformFile file) async {
    // Cria uma referência única para o arquivo usando timestamp e nome
    final storageRef = FirebaseStorage.instance.ref().child(
      'ocorrencias/${DateTime.now().millisecondsSinceEpoch}_${file.name}',
    );
    UploadTask uploadTask;

    // Se o arquivo possuir path (mobile), faz o upload com putFile
    if (file.path != null) {
      File localFile = File(file.path!);
      uploadTask = storageRef.putFile(localFile);
    } else if (file.bytes != null) {
      // Caso contrário, se houver bytes (ex. Flutter Web), usa putData
      uploadTask = storageRef.putData(file.bytes!);
    } else {
      throw Exception("Arquivo sem dados para upload.");
    }

    TaskSnapshot snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }
}
