import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crud/services/firestore.dart';
import 'package:crud/services/enviar_email.dart'; // Importando o serviço de e-mail
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TelaGuardiaoUnificada extends StatefulWidget {
  const TelaGuardiaoUnificada({Key? key}) : super(key: key);

  @override
  _TelaGuardiaoUnificadaState createState() => _TelaGuardiaoUnificadaState();
}

class _TelaGuardiaoUnificadaState extends State<TelaGuardiaoUnificada> {
  final FirestoreService _service = FirestoreService();
  final EmailBackendService _emailSvc =
      EmailBackendService(); // Instanciando o serviço de e-mail
  final String _meuId = FirebaseAuth.instance.currentUser!.uid;
  final TextEditingController _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  // Função para carregar o template do e-mail de convite
  Future<Map<String, String>> _carregarTemplateConviteGuardiao() async {
    final snap = await FirebaseFirestore.instance
        .collection('textoEmails')
        .doc('convite_guardião')
        .get();

    if (!snap.exists) {
      return {
        'assunto': 'Convite para ser Guardião',
        'body': 'Olá {nomeGuardiao}, {nome} convidou você para ser guardião.',
        'htmlBody':
            '<p>Olá {nomeGuardiao}, <b>{nome}</b> convidou você para ser guardião.</p>',
      };
    }

    final data = (snap.data() ?? {}) as Map<String, dynamic>;
    return {
      'assunto': (data['assunto'] ?? 'Convite para ser Guardião').toString(),
      'body': (data['body'] ?? data['texto'] ?? '').toString(),
      'htmlBody': (data['html'] ?? '').toString(),
    };
  }

  // 1) Enviar convite
  Future<void> _enviarConvite() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Por favor, insira o e‑mail do guardião.")),
      );
      return;
    }
    try {
      // Cria o convite (já existente)
      await _service.convidarGuardiaoPorEmail(email, _meuId);
      _emailController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Convite enviado com sucesso!")),
      );

      // Carregar o template de e-mail
      final tpl = await _carregarTemplateConviteGuardiao();

      // Enviar o e-mail usando o backend
      await _emailSvc.enviarEmailViaBackend(
        to: email,
        subject: tpl['assunto'] ?? 'Convite para ser Guardião',
        body: tpl['body']?.isNotEmpty == true
            ? tpl['body']!
            : 'Olá {nomeGuardiao}, {nome} convidou você para ser guardião.',
        htmlBody:
            (tpl['htmlBody']?.isNotEmpty == true) ? tpl['htmlBody'] : null,
        nomeGuardiao: null, // pode ser null, o serviço tenta buscar pelo e-mail
        textoSocorro:
            null, // não há texto de socorro aqui, mas é um parâmetro opcional
      );

      // Feedback de envio do e-mail
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("E-mail enviado!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao enviar convite: $e")),
      );
    }
  }

  // 2) Aceitar / recusar convites
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

  Stream<QuerySnapshot> get _convitesPendentesStream =>
      _service.getConvitesRecebidosGuardiao(_meuId);

  // 3) Lista de guardiões ativos + inativos
  Widget _buildMeusGuardioes() {
    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('usuario').doc(_meuId).get(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        final userDoc = snap.data;
        if (userDoc == null || !userDoc.exists) {
          return Text('Nenhum guardião cadastrado.');
        }
        final data = userDoc.data()! as Map<String, dynamic>;
        final List<String> ativos = List<String>.from(data['guardioes'] ?? []);

        // 3.1) Guardiões ativos
        final activeSection = ativos.isEmpty
            ? Text('Nenhum guardião ativo.')
            : ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: ativos.length,
                itemBuilder: (ctx2, i) {
                  final gid = ativos[i];
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('usuario')
                        .doc(gid)
                        .get(),
                    builder: (c2, s2) {
                      if (s2.connectionState == ConnectionState.waiting) {
                        return ListTile(title: Text('Carregando...'));
                      }
                      if (s2.data == null || !s2.data!.exists) {
                        return ListTile(title: Text('Guardião não encontrado'));
                      }
                      final g = s2.data!.data()! as Map<String, dynamic>;
                      return ListTile(
                        leading: Icon(Icons.shield),
                        title: Text(g['nome'] ?? 'Sem nome'),
                        subtitle: Text(g['email'] ?? ''),
                        trailing: IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Inativar guardião',
                          onPressed: () async {
                            // remove do array
                            await FirebaseFirestore.instance
                                .collection('usuario')
                                .doc(_meuId)
                                .update({
                              'guardioes': FieldValue.arrayRemove([gid])
                            });
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Guardião inativado')),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              );

        // 3.2) Guardiões inativados
        final inviteStream = FirebaseFirestore.instance
            .collection('guardiões')
            .where('id_usuario', isEqualTo: _meuId)
            .where('status', isEqualTo: 'aceito')
            .snapshots();

        final inactiveSection = StreamBuilder<QuerySnapshot>(
          stream: inviteStream,
          builder: (ctx3, snap3) {
            if (snap3.connectionState == ConnectionState.waiting) {
              return SizedBox.shrink();
            }
            final docs = snap3.data?.docs ?? [];
            final inativos = docs
                .map((d) => d['id_guardiao'] as String)
                .where((gid) => !ativos.contains(gid))
                .toList();
            if (inativos.isEmpty) {
              return SizedBox.shrink();
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 16),
                Text('Guardião(ões) inativado(s):',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: inativos.length,
                  itemBuilder: (ctx4, j) {
                    final gid = inativos[j];
                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('usuario')
                          .doc(gid)
                          .get(),
                      builder: (c4, s4) {
                        if (s4.connectionState == ConnectionState.waiting) {
                          return ListTile(title: Text('Carregando...'));
                        }
                        if (s4.data == null || !s4.data!.exists) {
                          return ListTile(
                              title: Text('Guardião não encontrado'));
                        }
                        final g = s4.data!.data()! as Map<String, dynamic>;
                        return ListTile(
                          leading: Icon(Icons.shield_outlined),
                          title: Text(g['nome'] ?? 'Sem nome'),
                          subtitle: Text(g['email'] ?? ''),
                          trailing: IconButton(
                            icon: Icon(Icons.check, color: Colors.green),
                            tooltip: 'Ativar guardião',
                            onPressed: () async {
                              await FirebaseFirestore.instance
                                  .collection('usuario')
                                  .doc(_meuId)
                                  .update({
                                'guardioes': FieldValue.arrayUnion([gid])
                              });
                              setState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Guardião ativado')),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            );
          },
        );

        return Column(
          children: [
            activeSection,
            inactiveSection,
          ],
        );
      },
    );
  }

  // 4) Usuários que eu guardo
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
              future: FirebaseFirestore.instance
                  .collection('usuario')
                  .doc(idUsuario)
                  .get(),
              builder: (c3, s3) {
                if (s3.connectionState == ConnectionState.waiting) {
                  return ListTile(title: Text('Carregando...'));
                }
                if (s3.data == null || !s3.data!.exists) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Guardiões'),
        backgroundColor: Colors.pink,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enviar convite
            const Text('Enviar Convite',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'E‑mail do Guardião',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _enviarConvite,
              child: const Text('Enviar Convite'),
            ),

            const Divider(height: 32),

            // Convites pendentes
            const Text('Convites Recebidos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream: _convitesPendentesStream,
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final convites = snap.data?.docs ?? [];
                if (convites.isEmpty) {
                  return const Text('Nenhum convite pendente.');
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: convites.length,
                  itemBuilder: (ctx2, i) {
                    final doc = convites[i];
                    final conviteId = doc.id;
                    final nomeUsuario = doc['nome_usuario'] as String? ?? '';
                    final idUsuario = doc['id_usuario'] as String;
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        title: Text('Convite de: $nomeUsuario'),
                        subtitle: Text('Status: ${doc['status']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon:
                                  const Icon(Icons.check, color: Colors.green),
                              onPressed: () =>
                                  _aceitarConvite(conviteId, idUsuario),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
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

            const Divider(height: 32),

            // Meus guardiões com inativação / ativação
            const Text('Meus Guardiões',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildMeusGuardioes(),

            const Divider(height: 32),

            // Usuários que eu guardo
            const Text('Usuários que eu guardo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildUsuariosQueGuardo(),
          ],
        ),
      ),
    );
  }
}
