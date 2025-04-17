import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crud/services/firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TelaGuardiaoUnificada extends StatefulWidget {
  const TelaGuardiaoUnificada({Key? key}) : super(key: key);

  @override
  _TelaGuardiaoUnificadaState createState() => _TelaGuardiaoUnificadaState();
}

class _TelaGuardiaoUnificadaState extends State<TelaGuardiaoUnificada> {
  final FirestoreService _service = FirestoreService();
  final String _meuId = FirebaseAuth.instance.currentUser!.uid;
  final TextEditingController _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  // --------------------------------------------------------
  // 1) Enviar convite por e-mail
  // --------------------------------------------------------
  Future<void> _enviarConvite() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor, insira o e‑mail do guardião.")),
      );
      return;
    }
    try {
      await _service.convidarGuardiaoPorEmail(email, _meuId);
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

  // --------------------------------------------------------
  // 2) Aceitar / recusar convites recebidos
  // --------------------------------------------------------
  Future<void> _aceitarConvite(String conviteId, String idUsuario) async {
    try {
      await _service.aceitarConviteGuardiao(conviteId, idUsuario, _meuId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Convite aceito com sucesso!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao aceitar convite: $e")),
      );
    }
  }

  Future<void> _recusarConvite(String conviteId) async {
    try {
      await _service.recusarConviteGuardiao(conviteId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Convite recusado.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao recusar convite: $e")),
      );
    }
  }

  Stream<QuerySnapshot> get _convitesPendentesStream {
    return _service.getConvitesRecebidosGuardiao(_meuId);
  }

  // --------------------------------------------------------
  // 3) Listar "Meus Guardiões" (quem me protege)
  // --------------------------------------------------------
  Widget _buildMeusGuardioes() {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('usuario').doc(_meuId).get(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (!snap.hasData || !snap.data!.exists) {
          return Text('Nenhum guardião cadastrado.');
        }
        final data = snap.data!.data()! as Map<String, dynamic>;
        final List<dynamic> guardianIds = data['guardioes'] ?? [];
        if (guardianIds.isEmpty) {
          return Text('Nenhum guardião cadastrado.');
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: guardianIds.length,
          itemBuilder: (ctx2, i) {
            final guardId = guardianIds[i] as String;
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('usuario').doc(guardId).get(),
              builder: (c2, s2) {
                if (s2.connectionState == ConnectionState.waiting) {
                  return ListTile(title: Text('Carregando...'));
                }
                if (!s2.hasData || !s2.data!.exists) {
                  return ListTile(title: Text('Guardião não encontrado'));
                }
                final gData = s2.data!.data()! as Map<String, dynamic>;
                return ListTile(
                  leading: Icon(Icons.shield),
                  title: Text(gData['nome'] ?? 'Sem nome'),
                  subtitle: Text(gData['email'] ?? ''),
                );
              },
            );
          },
        );
      },
    );
  }

  // --------------------------------------------------------
  // 4) Listar "Usuários que eu guardo" (para quem sou guardião)
  // --------------------------------------------------------
  Widget _buildUsuariosQueGuardo() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('guardiões')
          .where('id_guardiao', isEqualTo: _meuId)
          .where('status', isEqualTo: 'aceito')
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Text('Você não guarda nenhum usuário.');
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (ctx2, i) {
            final doc = docs[i];
            final idUsuario = doc['id_usuario'] as String;
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('usuario').doc(idUsuario).get(),
              builder: (c3, s3) {
                if (s3.connectionState == ConnectionState.waiting) {
                  return ListTile(title: Text('Carregando...'));
                }
                if (!s3.hasData || !s3.data!.exists) {
                  return ListTile(title: Text('Usuário não encontrado'));
                }
                final uData = s3.data!.data()! as Map<String, dynamic>;
                return ListTile(
                  leading: Icon(Icons.person),
                  title: Text(uData['nome'] ?? 'Sem nome'),
                  subtitle: Text(uData['email'] ?? ''),
                );
              },
            );
          },
        );
      },
    );
  }

  // --------------------------------------------------------
  // Montagem da UI
  // --------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Guardiões'),
        backgroundColor: Colors.pink,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enviar convite
            Text('Enviar convite',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'E‑mail do Guardião',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: _enviarConvite,
              child: Text('Enviar Convite'),
            ),

            Divider(height: 32),

            // Convites pendentes
            Text('Convites Recebidos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream: _convitesPendentesStream,
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                final convites = snap.data?.docs ?? [];
                if (convites.isEmpty) {
                  return Text('Nenhum convite pendente.');
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: convites.length,
                  itemBuilder: (ctx2, i) {
                    final doc = convites[i];
                    final conviteId = doc.id;
                    final nomeUsuario = doc['nome_usuario'] as String? ?? '';
                    final idUsuario = doc['id_usuario'] as String;
                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        title: Text('Convite de: $nomeUsuario'),
                        subtitle: Text('Status: ${doc['status']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.check, color: Colors.green),
                              onPressed: () =>
                                  _aceitarConvite(conviteId, idUsuario),
                            ),
                            IconButton(
                              icon: Icon(Icons.close, color: Colors.red),
                              onPressed: () => _recusarConvite(conviteId),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),

            Divider(height: 32),

            // Meus guardiões
            Text('Meus guardiões',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            _buildMeusGuardioes(),

            Divider(height: 32),

            // Usuários que eu guardo
            Text('Usuários que eu guardo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            _buildUsuariosQueGuardo(),
          ],
        ),
      ),
    );
  }
}
