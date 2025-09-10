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

  /// 🔹 Lista de tags suportadas (UI lê daqui; mantém sincronizado com a substituição)
  static const List<String> supportedTags = <String>[
    '{nome}',          // Nome do remetente (usuário logado)
    '{email}',         // E-mail do remetente
    '{hora}',          // Data/hora atual
    '{guardioes}',     // Lista de nomes dos guardiões do remetente
    '{nomeGuardiao}',  // Nome do destinatário se existir na coleção 'usuario', senão "Convidado"
    //endereço
    //data
    //GPS/
  ];

  /// Envia e-mail via backend HTTP, substituindo automaticamente as tags
  /// {nome}, {email}, {hora}, {guardioes} e {nomeGuardiao}.
  Future<void> enviarEmailViaBackend({
    required String to,
    required String subject,
    required String body,
    String? htmlBody,
  }) async {
    if (to.isEmpty || subject.isEmpty || body.isEmpty) {
      throw ArgumentError('Preencha todos os campos obrigatórios.');
    }

    // Substituir as tags dinamicamente
    final bodyFinal =
        await _substituirTagsPorValores(body, destinatarioEmail: to);
    final htmlBodyFinal = htmlBody != null
        ? await _substituirTagsPorValores(htmlBody, destinatarioEmail: to)
        : null;

    // Logs simples de depuração
    // ignore: avoid_print
    print('Enviando e-mail para: $to');
    // ignore: avoid_print
    print('Assunto: $subject');
    // ignore: avoid_print
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
        // ignore: avoid_print
        print('E-mail enviado com sucesso!');
      }
    } catch (e) {
      throw Exception('Erro ao enviar e-mail: $e');
    }
  }

  /// Substitui dinamicamente as tags do texto.
  /// `destinatarioEmail` é usado para preencher {nomeGuardiao}.
  Future<String> _substituirTagsPorValores(
    String texto, {
    String? destinatarioEmail,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    // ------------------- DADOS DO REMETENTE -------------------
    String nomeUsuario = 'Usuário sem nome';
    String emailUsuario = 'E-mail não encontrado';
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('usuario')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null) {
          nomeUsuario = (data['nome'] ?? nomeUsuario).toString();
          emailUsuario = (data['email'] ?? emailUsuario).toString();
        }
      }
    }

    final horaAtual = DateTime.now().toString();

    // ------------------- DADOS DOS GUARDIÕES DO REMETENTE -------------------
    // (coleção 'guardiões' com campos: id_usuario, id_guardiao)
    final guardioesSnapshot = await FirebaseFirestore.instance
        .collection('guardiões')
        .where('id_usuario', isEqualTo: user?.uid)
        .get();

    final nomesGuardioes = <String>[];
    for (var doc in guardioesSnapshot.docs) {
      final idGuardiao = doc.data()['id_guardiao'];
      if (idGuardiao != null) {
        final guardiaoDoc = await FirebaseFirestore.instance
            .collection('usuario')
            .doc(idGuardiao)
            .get();
        if (guardiaoDoc.exists) {
          final gData = guardiaoDoc.data();
          if (gData != null) {
            nomesGuardioes.add((gData['nome'] ?? 'Guardião sem nome').toString());
          }
        }
      }
    }

    final guardioesString = nomesGuardioes.isNotEmpty
        ? nomesGuardioes.join(', ')
        : 'Nenhum guardião encontrado';

    // ------------------- DADOS DO DESTINATÁRIO -------------------
    String nomeGuardiao = 'Convidado';
    if (destinatarioEmail != null && destinatarioEmail.isNotEmpty) {
      final snapshot = await FirebaseFirestore.instance
          .collection('usuario')
          .where('email', isEqualTo: destinatarioEmail)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        nomeGuardiao = (data['nome'] ?? 'Convidado').toString();
      }
    }

    // ------------------- SUBSTITUIÇÃO DAS TAGS -------------------
    texto = texto.replaceAll('{nome}', nomeUsuario);
    texto = texto.replaceAll('{email}', emailUsuario);
    texto = texto.replaceAll('{hora}', horaAtual);
    texto = texto.replaceAll('{guardioes}', guardioesString);
    texto = texto.replaceAll('{nomeGuardiao}', nomeGuardiao);
    return texto;
  }
}
