// lib/services/email_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class EmailBackendService {
  EmailBackendService(
      {this.backendUrl = 'https://enviar-email-3jwi.onrender.com'});

  final String backendUrl;

  /// Envia e-mail via backend HTTP.
  Future<void> enviarEmailViaBackend({
    required String to,
    required String subject,
    required String body,
  }) async {
    final resp = await http.post(
      Uri.parse(backendUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'to': to, 'subject': subject, 'body': body}),
    );

    if (resp.statusCode != 200) {
      throw Exception('Falha ao enviar: ${resp.body}');
    }
  }
}

class FirestoreService {
  final CollectionReference textosEmails =
      FirebaseFirestore.instance.collection('textosEmails');

  /// Stream com os textos de e-mail ativos (para usar com StreamBuilder)
  Stream<QuerySnapshot<Map<String, dynamic>>> listarTextosEmailsAtivos() {
    return textosEmails
        .where('inativar', isEqualTo: false)
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snap, _) => snap.data() as Map<String, dynamic>,
          toFirestore: (data, _) => data,
        )
        .snapshots();
  }

  /// Busca um documento de texto de e-mail por nome (se ativo)
  Future<Map<String, dynamic>?> buscarTextoEmail(String nome) async {
    final snapshot = await textosEmails
        .where('nome', isEqualTo: nome)
        .where('inativar', isEqualTo: false)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return snapshot.docs.first.data() as Map<String, dynamic>;
  }

  /// 🔹 Novo: Lista apenas os nomes dos textos ativos (útil para Dropdown)
  Future<List<String>> listarNomesTextosEmails() async {
    final query = await textosEmails.where('inativar', isEqualTo: false).get();

    return query.docs
        .map((doc) => (doc['nome'] ?? '').toString())
        .where((nome) => nome.isNotEmpty)
        .toList();
  }
}
