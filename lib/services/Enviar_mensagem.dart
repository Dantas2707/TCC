import 'package:cloud_firestore/cloud_firestore.dart';

Future<String?> buscarMensagemPorCampo(String campo) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('configs')
      .where('campo', isEqualTo: campo)
      .where('ativo', isEqualTo: true)
      .limit(1)
      .get();

  if (snapshot.docs.isNotEmpty) {
    return snapshot.docs.first.get('valor') as String;
  }
  return null;
}

String preencherVariaveisMensagem(String template, Map<String, String> variaveis) {
  String mensagem = template;
  variaveis.forEach((key, value) {
    mensagem = mensagem.replaceAll('{$key}', value);
  });
  return mensagem;
}
