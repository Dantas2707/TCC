import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';

class FirestoreService {
  final CollectionReference tipoOcorrencia =
      FirebaseFirestore.instance.collection('tipoOcorrencia');

  final CollectionReference usuario =
      FirebaseFirestore.instance.collection("usuario");

  final CollectionReference ocorrencias =
      FirebaseFirestore.instance.collection('ocorrencias');

  final CollectionReference guardioes =
      FirebaseFirestore.instance.collection("guardiões");

  // ==============================================================
  // GUARDIÕES
  // ==============================================================

  Future<void> convidarGuardiaoPorEmail(String email, String idUsuario) async {
    try {
      final userSnapshot = await usuario.where('email', isEqualTo: email).get();

      if (userSnapshot.docs.isNotEmpty) {
        final String idGuardiao = userSnapshot.docs.first.id;

        final duplicado = await guardioes
            .where('id_usuario', isEqualTo: idUsuario)
            .where('id_guardiao', isEqualTo: idGuardiao)
            .get();

        if (duplicado.docs.isNotEmpty) {
          throw Exception("Esta relação de guardião já existe.");
        }

        final senderDoc = await usuario.doc(idUsuario).get();
        final String nomeUsuario = senderDoc.get('nome');

        await guardioes.add({
          'id_usuario': idUsuario,
          'nome_usuario': nomeUsuario,
          'id_guardiao': idGuardiao,
          'invitado': true,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'pendente',
        });
      } else {
        print("Usuário não encontrado. Enviando convite para baixar o app.");
      }
    } catch (e) {
      print("Erro ao convidar guardião: $e");
      throw Exception("Erro ao convidar guardião: $e");
    }
  }

  Future<void> aceitarConviteGuardiao(
      String conviteDocId, String idUsuario, String idGuardiao) async {
    try {
      await guardioes.doc(conviteDocId).update({
        'status': 'aceito',
        'timestamp': FieldValue.serverTimestamp(),
      });

      await usuario.doc(idUsuario).update({
        'guardioes': FieldValue.arrayUnion([idGuardiao]),
      });

      await usuario.doc(idGuardiao).update({
        'guardiao': true,
      });
    } catch (e) {
      print("Erro ao aceitar convite: $e");
      throw Exception("Erro ao aceitar convite: $e");
    }
  }

  Future<void> recusarConviteGuardiao(String conviteDocId) async {
    try {
      await guardioes.doc(conviteDocId).update({
        'status': 'recusado',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Erro ao recusar convite: $e");
      throw Exception("Erro ao recusar convite: $e");
    }
  }

  Stream<QuerySnapshot> getConvitesRecebidosGuardiao(String idGuardiao) {
    return guardioes
        .where('id_guardiao', isEqualTo: idGuardiao)
        .where('status', isEqualTo: 'pendente')
        .snapshots();
  }

  // ==============================================================
  // TIPO OCORRÊNCIA / USUÁRIO
  // ==============================================================

  Future<void> addTipoOcorrencia(String tipoOcorrenciaText) async {
    final tipoOcorrenciaFormatado = tipoOcorrenciaText.trim().toLowerCase();
    if (tipoOcorrenciaFormatado.length < 3 ||
        tipoOcorrenciaFormatado.length > 100) {
      throw Exception("O tipo de ocorrência deve ter entre 3 e 100 caracteres.");
    }

    final duplicado = await tipoOcorrencia
        .where('tipoOcorrencia', isEqualTo: tipoOcorrenciaFormatado)
        .get();

    if (duplicado.docs.isNotEmpty) {
      throw Exception("Este tipo de ocorrência já existe.");
    }

    await tipoOcorrencia.add({
      'tipoOcorrencia': tipoOcorrenciaFormatado,
      'timestamp': FieldValue.serverTimestamp(),
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
    final tipoFormatado = novoTipo.trim().toLowerCase();
    if (tipoFormatado.isEmpty || tipoFormatado.length < 3) {
      throw Exception("O tipo de ocorrência deve ter no mínimo 3 caracteres.");
    }
    await tipoOcorrencia.doc(docID).update({
      'tipoOcorrencia': tipoFormatado,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> inativarTipoOcorrencia(String docID) async {
    await tipoOcorrencia.doc(docID).update({
      'timestamp': FieldValue.serverTimestamp(),
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
      'timestamp': FieldValue.serverTimestamp(),
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
    dadosUsuario['timestamp'] = FieldValue.serverTimestamp();
    await usuario.doc(uid).update(dadosUsuario);
  }

  Future<void> inativarUsuario(String uid) async {
    await usuario.doc(uid).update({
      'timestamp': FieldValue.serverTimestamp(),
      'inativar': true,
    });
  }

  // ==================================================================
  // OCORRÊNCIAS
  // ==================================================================

  Future<void> addOcorrencia(
    String tipo,
    String gravidade,
    String relato,
    String textoSocorro,
    bool enviarParaGuardiao, {
    List<PlatformFile>? anexos,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Usuário não autenticado');

    final List<String> anexosUrls = [];

    if (anexos != null && anexos.isNotEmpty) {
      for (final file in anexos) {
        try {
          final url = await uploadFile(file);
          anexosUrls.add(url);
        } catch (e) {
          print('Erro ao fazer upload do anexo ${file.name}: $e');
        }
      }
    }

    await ocorrencias.add({
      'ownerUid': user.uid,
      'tipoOcorrencia': tipo,
      'gravidade': gravidade,
      'relato': relato,
      'textoSocorro': textoSocorro,
      'enviarParaGuardiao': enviarParaGuardiao,
      'status': 'aberto',
      'anexos': anexosUrls,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getOcorrenciasDoUsuarioStream(String uid, {String status = 'aberto'}) {
    return ocorrencias
        .where('ownerUid', isEqualTo: uid)
        .where('status', isEqualTo: status)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> finalizarOcorrencia(String ocorrenciaId) async {
    await ocorrencias.doc(ocorrenciaId).update({
      'status': 'finalizado',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// EDITAR mantendo histórico (relato/anexos; histórico com Timestamp.now())
  Future<void> editarOcorrencia(
    String ocorrenciaId, {
    String? novoRelato,
    List<PlatformFile>? anexosNovos,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Usuário não autenticado');

    final ref = ocorrencias.doc(ocorrenciaId);
    final snap = await ref.get();
    if (!snap.exists) throw Exception('Ocorrência não encontrada');

    final data = snap.data() as Map<String, dynamic>;
    final relatoAntigo = (data['relato'] as String?) ?? '';
    final anexosAntigos = (data['anexos'] as List?)?.cast<String>() ?? const <String>[];

    // 1) Upload dos novos anexos
    final List<String> urlsNovas = [];
    if (anexosNovos != null && anexosNovos.isNotEmpty) {
      for (final file in anexosNovos) {
        try {
          final url = await uploadFile(file);
          urlsNovas.add(url);
        } catch (e) {
          print('Falha ao enviar anexo ${file.name}: $e');
        }
      }
    }

    // 2) Novo estado
    final relatoFinal = (novoRelato ?? relatoAntigo).trim();
    final anexosFinais = <String>[...anexosAntigos, ...urlsNovas];

    // 3) Entrada de histórico (usar Timestamp.now() dentro do array)
    final historicoEntry = {
      'tipo': 'edicao',
      'editorUid': user.uid,
      'timestamp': Timestamp.now(),
      'relatoAnterior': relatoAntigo,
      'anexosAnteriores': anexosAntigos,
      'novoRelato': relatoFinal,
      'novosAnexos': urlsNovas,
    };

    // 4) Atualização
    await ref.update({
      'relato': relatoFinal,
      'anexos': anexosFinais,
      'ultimaAtualizacao': FieldValue.serverTimestamp(),
      'historico': FieldValue.arrayUnion([historicoEntry]),
    });
  }

  /// Remover um anexo específico (atualiza histórico)
  Future<void> removerAnexo(String ocorrenciaId, String url) async {
    await ocorrencias.doc(ocorrenciaId).update({
      'anexos': FieldValue.arrayRemove([url]),
      'ultimaAtualizacao': FieldValue.serverTimestamp(),
      'historico': FieldValue.arrayUnion([{
        'tipo': 'remocao_anexo',
        'editorUid': FirebaseAuth.instance.currentUser?.uid ?? '—',
        'timestamp': Timestamp.now(), // dentro do array, use Timestamp.now()
        'removido': url,
      }]),
    });
  }

  // ==================================================================
  // Upload (Storage)
  // ==================================================================

  Future<String> uploadFile(PlatformFile file) async {
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('ocorrencias/${DateTime.now().millisecondsSinceEpoch}_${file.name}');

    UploadTask uploadTask;

    if (file.path != null) {
      final localFile = File(file.path!);
      uploadTask = storageRef.putFile(localFile);
    } else if (file.bytes != null) {
      uploadTask = storageRef.putData(file.bytes!);
    } else {
      throw Exception("Arquivo sem dados para upload.");
    }

    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }
}
