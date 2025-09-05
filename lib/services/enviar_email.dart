import 'dart:convert';
import 'package:http/http.dart' as http;

class EmailBackendService {
  EmailBackendService(
      {this.backendUrl = 'https://enviar-email-3jwi.onrender.com'});

  final String backendUrl;

  /// Envia e-mail via backend HTTP.
  Future<void> enviarEmailViaBackend({
    required String to,
    required String subject,
    required String body,
    String? htmlBody, // Adicionando o parâmetro opcional htmlBody
  }) async {
    // Verificar se os campos estão sendo passados corretamente
    print('Enviando e-mail para: $to');
    print('Assunto: $subject');
    print('Corpo do e-mail: $body');

    // Certifique-se de que o corpo da mensagem não está vazio
    if (body.isEmpty && (htmlBody == null || htmlBody.isEmpty)) {
      throw ArgumentError('Nenhum conteúdo para enviar: texto ou html deve ser informado.');
    }

    try {
      // Enviar a requisição para o backend via HTTP POST
      final resp = await http.post(
        Uri.parse(backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'to': to,
          'subject': subject,
          'body': body,
          'htmlBody': htmlBody,  // Passando o corpo HTML também
        }),
      );

      // Verificar a resposta do backend
      if (resp.statusCode != 200) {
        throw Exception('Falha ao enviar: ${resp.body}');
      } else {
        print('E-mail enviado com sucesso!');
      }
    } catch (e) {
      throw Exception('Erro ao enviar e-mail: $e');
    }
  }
}
