// lib/services/enviar_email.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EmailBackendService {
  EmailBackendService({
    this.backendUrl = 'https://enviar-email-3jwi.onrender.com',
  });

  final String backendUrl;

  /// 🔹 Lista de tags suportadas
  static const List<String> supportedTags = <String>[
    '{nome}',          // Nome do remetente (usuário logado)
    '{email}',         // E-mail do remetente
    '{hora}',          // Data/hora atual
    '{guardioes}',     // Lista de nomes dos guardiões do remetente
    '{nomeGuardiao}',  // Nome do destinatário (guardião)
    '{socorro}',       // 👈 Texto de socorro da ocorrência
  ];

  Future<void> enviarEmailViaBackend({
    required String to,
    required String subject,
    required String body,
    String? htmlBody,
    String? nomeGuardiao,
    String? textoSocorro, // 👈 NOVO parâmetro
  }) async {
    if (to.isEmpty || subject.isEmpty || body.isEmpty) {
      throw ArgumentError('Preencha todos os campos obrigatórios.');
    }

    final bodyFinal = await _substituirTagsPorValores(
      body,
      destinatarioEmail: to,
      nomeGuardiao: nomeGuardiao,
      textoSocorro: textoSocorro, // 👈 encadeia socorro
    );

    final htmlBodyFinal = htmlBody != null
        ? await _substituirTagsPorValores(
            htmlBody,
            destinatarioEmail: to,
            nomeGuardiao: nomeGuardiao,
            textoSocorro: textoSocorro,
          )
        : null;

    print('Enviando e-mail para: $to');
    print('Assunto: $subject');
    print('Corpo do e-mail: $bodyFinal');

    try {
      final resp = await http.post(
        Uri.parse(backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'to': to,
          'subject': subject,
          'body': bodyFinal,
          'htmlBody': htmlBodyFinal,
        }),
      );

      if (resp.statusCode != 200) {
        throw Exception('Falha ao enviar: ${resp.body}');
      } else {
        print('E-mail enviado com sucesso!');
      }
    } catch (e) {
      throw Exception('Erro ao enviar e-mail: $e');
    }
  }

  Future<String> _substituirTagsPorValores(
    String texto, {
    String? destinatarioEmail,
    String? nomeGuardiao,
    String? textoSocorro, // 👈 usado aqui
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    String nomeUsuario = 'Usuário sem nome';
    String emailUsuario = 'E-mail não encontrado';
    if (user != null) {
      final userDoc =
          await FirebaseFirestore.instance.collection('usuario').doc(user.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null) {
          nomeUsuario = (data['nome'] ?? nomeUsuario).toString();
          emailUsuario = (data['email'] ?? emailUsuario).toString();
        }
      }
    }

    final horaAtual = DateTime.now().toString();

    // Puxa nomes dos guardiões do remetente
    final guardioesSnapshot = await FirebaseFirestore.instance
        .collection('guardiões')
        .where('id_usuario', isEqualTo: user?.uid)
        .get();

    final nomesGuardioes = <String>[];
    for (var doc in guardioesSnapshot.docs) {
      final idGuardiao = doc.data()['id_guardiao'];
      if (idGuardiao != null) {
        final guardiaoDoc =
            await FirebaseFirestore.instance.collection('usuario').doc(idGuardiao).get();
        if (guardiaoDoc.exists) {
          final gData = guardiaoDoc.data();
          if (gData != null) {
            nomesGuardioes.add((gData['nome'] ?? 'Guardião sem nome').toString());
          }
        }
      }
    }

    final guardioesString =
        nomesGuardioes.isNotEmpty ? nomesGuardioes.join(', ') : 'Nenhum guardião encontrado';

    // Se nome do guardião foi passado, usa-o. Senão tenta buscar por e-mail.
    String nomeDoGuardiao = nomeGuardiao ?? 'Convidado';
    if (nomeGuardiao == null && destinatarioEmail != null && destinatarioEmail.isNotEmpty) {
      final snapshot = await FirebaseFirestore.instance
          .collection('usuario')
          .where('email', isEqualTo: destinatarioEmail)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        nomeDoGuardiao = (data['nome'] ?? 'Convidado').toString();
      }
    }

    // Substituição das tags
    texto = texto.replaceAll('{nome}', nomeUsuario);
    texto = texto.replaceAll('{email}', emailUsuario);
    texto = texto.replaceAll('{hora}', horaAtual);
    texto = texto.replaceAll('{guardioes}', guardioesString);
    texto = texto.replaceAll('{nomeGuardiao}', nomeDoGuardiao);
    texto = texto.replaceAll('{socorro}', textoSocorro ?? ''); // 👈 substitui pelo texto de socorro
    return texto;
  }
}
