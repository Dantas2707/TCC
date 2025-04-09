import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:crud/services/firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TelaGuardiaoUnificada extends StatefulWidget {
  const TelaGuardiaoUnificada({Key? key}) : super(key: key);

  @override
  _TelaGuardiaoUnificadaState createState() => _TelaGuardiaoUnificadaState();
}

class _TelaGuardiaoUnificadaState extends State<TelaGuardiaoUnificada> {
  final FirestoreService firestoreService = FirestoreService();

  // Obter o UID real do guardião logado via FirebaseAuth
  final String _idGuardiaoLogado = FirebaseAuth.instance.currentUser!.uid;

  final TextEditingController _emailController = TextEditingController();

  // Função para enviar convite
  void enviarConvite() async {
    String email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor, insira o e-mail do guardião.")),
      );
      return;
    }
    try {
      await firestoreService.convidarGuardiaoPorEmail(email, _idGuardiaoLogado);
      _emailController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Convite enviado com sucesso!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao enviar convite: $e")),
      );
    }
  }

  // Função para aceitar um convite
  Future<void> aceitarConvite(String conviteDocId, String idUsuario) async {
    try {
      await firestoreService.aceitarConviteGuardiao(
          conviteDocId, idUsuario, _idGuardiaoLogado);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Convite aceito com sucesso!")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao aceitar convite: $e")));
    }
  }

  // Função para recusar um convite
  Future<void> recusarConvite(String conviteDocId) async {
    try {
      await firestoreService.recusarConviteGuardiao(conviteDocId);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Convite recusado.")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao recusar convite: $e")));
    }
  }

  // Stream para buscar os convites recebidos para o guardião logado
  Stream<QuerySnapshot> getConvitesRecebidos() {
    return firestoreService.getConvitesRecebidosGuardiao(_idGuardiaoLogado);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tela do Guardião"),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Enviar Convite",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: "E-mail do Guardião",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: enviarConvite,
                child: const Text("Enviar Convite"),
              ),
              const Divider(height: 30),
              const Text(
                "Convites Recebidos",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              StreamBuilder<QuerySnapshot>(
                stream: getConvitesRecebidos(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text("Nenhum convite pendente."));
                  }
                  final convites = snapshot.data!.docs;
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: convites.length,
                    itemBuilder: (context, index) {
                      final doc = convites[index];
                      final conviteId = doc.id;
                      // Aqui, em vez de mostrar o idUsuario, mostramos o nome do usuário que enviou o convite.
                      // Como salvamos o nome no campo 'nome_usuario' no convite, basta exibi-lo.
                      final nomeUsuario = doc['nome_usuario'];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        child: ListTile(
                          title: Text("Convite de: $nomeUsuario"),
                          subtitle: Text("Status: ${doc['status']}"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.check, color: Colors.green),
                                onPressed: () => aceitarConvite(conviteId, doc['id_usuario']),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.red),
                                onPressed: () => recusarConvite(conviteId),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
