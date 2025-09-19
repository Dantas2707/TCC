import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crud/services/firestore.dart';
import 'package:crud/services/enviar_email.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
// 🔹 Usa diretamente o plugin que você informou
import 'package:flutter_background_messenger/flutter_background_messenger.dart';

class TelaGuardiaoUnificada extends StatefulWidget {
  const TelaGuardiaoUnificada({Key? key}) : super(key: key);

  @override
  _TelaGuardiaoUnificadaState createState() => _TelaGuardiaoUnificadaState();
}

class _TelaGuardiaoUnificadaState extends State<TelaGuardiaoUnificada> {
  // ==========================
  // Serviços e controladores
  // ==========================
  final FirestoreService _service = FirestoreService();
  final String _meuId = FirebaseAuth.instance.currentUser!.uid;
  final TextEditingController _emailController = TextEditingController();

  // Notificações
  final EmailBackendService _emailSvc = EmailBackendService();
  final FlutterBackgroundMessenger _messenger = FlutterBackgroundMessenger();

  // Nome do template que será buscado em `textosEmails` (ou fallback)
  static const String _TEMPLATE_CONVITE = 'convite_guardiao';

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  // ============================================================
  // 1) Enviar convite
  // ============================================================
  Future<void> _enviarConvite() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Por favor, insira o e-mail do guardião.")),
      );
      return;
    }
    try {
      // Salva convite no Firestore pela sua service
      await _service.convidarGuardiaoPorEmail(email, _meuId);

      //  Envia e-mail (HTML + texto) e SMS (texto puro) com template e tags
      await _enviarNotificacoesConvite(email);

      _emailController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Convite enviado com sucesso!")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao enviar convite: $e")),
      );
    }
  }

  // ============================================================
  // 2) Aceitar / recusar convites
  // ============================================================
  Future<void> _aceitarConvite(String conviteId, String idUsuario) async {
    try {
      await _service.aceitarConviteGuardiao(conviteId, idUsuario, _meuId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Convite aceito com sucesso!")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao aceitar convite: $e")),
      );
    }
  }

  Future<void> _recusarConvite(String conviteId) async {
    try {
      await _service.recusarConviteGuardiao(conviteId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Convite recusado.")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao recusar convite: $e")),
      );
    }
  }

  Stream<QuerySnapshot> get _convitesPendentesStream =>
      _service.getConvitesRecebidosGuardiao(_meuId);

  // ============================================================
  // 3) Lista de guardiões ativos + inativos
  // ============================================================
  Widget _buildMeusGuardioes() {
    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('usuario').doc(_meuId).get(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final userDoc = snap.data;
        if (userDoc == null || !userDoc.exists) {
          return const Text('Nenhum guardião cadastrado.');
        }
        final data = userDoc.data()! as Map<String, dynamic>;
        final List<String> ativos = List<String>.from(data['guardioes'] ?? []);

        // 3.1) Guardiões ativos
        final activeSection = ativos.isEmpty
            ? const Text('Nenhum guardião ativo.')
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
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
                        return const ListTile(title: Text('Carregando...'));
                      }
                      if (s2.data == null || !s2.data!.exists) {
                        return const ListTile(
                            title: Text('Guardião não encontrado'));
                      }
                      final g = s2.data!.data()! as Map<String, dynamic>;
                      return ListTile(
                        leading: const Icon(Icons.shield),
                        title: Text(g['nome'] ?? 'Sem nome'),
                        subtitle: Text(g['email'] ?? ''),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Inativar guardião',
                          onPressed: () async {
                            await FirebaseFirestore.instance
                                .collection('usuario')
                                .doc(_meuId)
                                .update({
                              'guardioes': FieldValue.arrayRemove([gid])
                            });
                            if (mounted) setState(() {});
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Guardião inativado')),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              );

        // 3.2) Guardiões inativados: aceitos mas fora do array 'guardioes'
        final inviteStream = FirebaseFirestore.instance
            .collection('guardiões')
            .where('id_usuario', isEqualTo: _meuId)
            .where('status', isEqualTo: 'aceito')
            .snapshots();

        final inactiveSection = StreamBuilder<QuerySnapshot>(
          stream: inviteStream,
          builder: (ctx3, snap3) {
            if (snap3.connectionState == ConnectionState.waiting) {
              return const SizedBox.shrink();
            }
            final docs = snap3.data?.docs ?? [];
            final inativos = docs
                .map((d) => d['id_guardiao'] as String)
                .where((gid) => !ativos.contains(gid))
                .toList();
            if (inativos.isEmpty) {
              return const SizedBox.shrink();
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                const Text(
                  'Guardião(ões) inativado(s):',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
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
                          return const ListTile(title: Text('Carregando...'));
                        }
                        if (s4.data == null || !s4.data!.exists) {
                          return const ListTile(
                              title: Text('Guardião não encontrado'));
                        }
                        final g = s4.data!.data()! as Map<String, dynamic>;
                        return ListTile(
                          leading: const Icon(Icons.shield_outlined),
                          title: Text(g['nome'] ?? 'Sem nome'),
                          subtitle: Text(g['email'] ?? ''),
                          trailing: IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            tooltip: 'Ativar guardião',
                            onPressed: () async {
                              await FirebaseFirestore.instance
                                  .collection('usuario')
                                  .doc(_meuId)
                                  .update({
                                'guardioes': FieldValue.arrayUnion([gid])
                              });
                              if (mounted) setState(() {});
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Guardião ativado')),
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

  // ============================================================
  // 4) Usuários que eu guardo
  // ============================================================
  Widget _buildUsuariosQueGuardo() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('guardiões')
          .where('id_guardiao', isEqualTo: _meuId)
          .where('status', isEqualTo: 'aceito')
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Text('Você não guarda nenhum usuário.');
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
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
                  return const ListTile(title: Text('Carregando...'));
                }
                if (s3.data == null || !s3.data!.exists) {
                  return const ListTile(title: Text('Usuário não encontrado'));
                }
                final uData = s3.data!.data()! as Map<String, dynamic>;
                return ListTile(
                  leading: const Icon(Icons.person),
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

  // ============================================================
  // 5) AUXILIARES: template, tags, conversões
  // ============================================================
  /// Busca template em `textosEmails` (principal) ou `textoEmail` (fallback).
  /// Espera campos: nome, assunto (opcional), textoEmail (texto), htmlEmail (html), inativar (bool).
  Future<Map<String, String>> _carregarTemplateConvite() async {
    // coleção principal
    final q1 = await FirebaseFirestore.instance
        .collection('textosEmails')
        .where('nome', isEqualTo: _TEMPLATE_CONVITE)
        .where('inativar', isEqualTo: false)
        .limit(1)
        .get();

    QueryDocumentSnapshot<Map<String, dynamic>>? doc =
        q1.docs.isNotEmpty ? q1.docs.first : null;

    // fallback
    if (doc == null) {
      final q2 = await FirebaseFirestore.instance
          .collection('textoEmail')
          .where('nome', isEqualTo: _TEMPLATE_CONVITE)
          .where('inativar', isEqualTo: false)
          .limit(1)
          .get();
      if (q2.docs.isNotEmpty) doc = q2.docs.first;
    }

    if (doc == null) {
      // Template padrão
      return {
        'assunto': 'Convite para ser meu Guardião',
        'html': '''
          <html><body>
          <p>Olá {nomeGuardiao},</p>
          <p>{nome} está convidando você para ser seu(ua) guardião(ã) no app.</p>
          <p>Data/Hora: {hora}</p>
          <p>Time dos guardiões: {guardioes}</p>
          </body></html>
        ''',
        'texto':
            'Olá {nomeGuardiao}, {nome} está convidando você para ser seu(ua) guardião(ã). {hora} Guardiões: {guardioes}',
      };
    }

    final data = doc.data();
    final assunto =
        (data['assunto'] ?? 'Convite para ser meu Guardião').toString();
    final html = (data['htmlEmail'] ?? data['textoEmail'] ?? '').toString();
    final texto = (data['textoEmail'] ?? '').toString();

    return {
      'assunto': assunto,
      'html': html,
      'texto': texto,
    };
  }

  /// Converte HTML simples em texto puro (para SMS).
  String _htmlParaTextoPuro(String html) {
    final semTags = html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
    return semTags.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }

  /// Gera um texto com as mesmas tags do EmailBackendService, sem depender dele (uso no SMS).
  Future<String> _gerarTextoTagsBasico({
    required String textoBase,
    required String destinatarioEmail,
    String? nomeGuardiao,
    String? textoSocorro,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    String nomeUsuario = 'Usuário sem nome';
    String emailUsuario = 'E-mail não encontrado';
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('usuario')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        final d = userDoc.data();
        if (d != null) {
          nomeUsuario = (d['nome'] ?? nomeUsuario).toString();
          emailUsuario = (d['email'] ?? emailUsuario).toString();
        }
      }
    }

    // Nome do guardião
    String nomeDoGuardiao = nomeGuardiao ?? 'Convidado';
    if (nomeGuardiao == null && destinatarioEmail.isNotEmpty) {
      final snap = await FirebaseFirestore.instance
          .collection('usuario')
          .where('email', isEqualTo: destinatarioEmail)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        final d = snap.docs.first.data();
        nomeDoGuardiao = (d['nome'] ?? 'Convidado').toString();
      }
    }

    // Lista de nomes dos guardiões do remetente
    final guardioesSnapshot = await FirebaseFirestore.instance
        .collection('guardiões')
        .where('id_usuario', isEqualTo: user?.uid)
        .get();

    final nomesGuardioes = <String>[];
    for (var doc in guardioesSnapshot.docs) {
      final idGuardiao = doc.data()['id_guardiao'];
      if (idGuardiao != null) {
        final gDoc = await FirebaseFirestore.instance
            .collection('usuario')
            .doc(idGuardiao)
            .get();
        if (gDoc.exists) {
          final gData = gDoc.data();
          if (gData != null) {
            nomesGuardioes
                .add((gData['nome'] ?? 'Guardião sem nome').toString());
          }
        }
      }
    }
    final guardioesString = nomesGuardioes.isNotEmpty
        ? nomesGuardioes.join(', ')
        : 'Nenhum guardião encontrado';

    final horaAtual = DateTime.now().toString();

    var out = textoBase;
    out = out.replaceAll('{nome}', nomeUsuario);
    out = out.replaceAll('{email}', emailUsuario);
    out = out.replaceAll('{hora}', horaAtual);
    out = out.replaceAll('{guardioes}', guardioesString);
    out = out.replaceAll('{nomeGuardiao}', nomeDoGuardiao);
    out = out.replaceAll('{socorro}', textoSocorro ?? '');

    return out.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  }

  // ============================================================
  // 6) Notificações: e-mail + SMS
  // ============================================================
  Future<void> _enviarNotificacoesConvite(String emailGuardiao) async {
    // 1) Carrega template
    final tpl = await _carregarTemplateConvite();
    final assunto = tpl['assunto'] ?? 'Convite para ser meu Guardião';
    final htmlTpl = tpl['html'] ?? '';
    final textoTpl = tpl['texto'] ?? '';

    // 2) Buscar dados do guardião (nome/telefone) pelo e-mail
    String? nomeGuardiao;
    String? telefoneGuardiao;
    final userSnap = await FirebaseFirestore.instance
        .collection('usuario')
        .where('email', isEqualTo: emailGuardiao)
        .limit(1)
        .get();

    if (userSnap.docs.isNotEmpty) {
      final d = userSnap.docs.first.data();
      nomeGuardiao = (d['nome'] ?? '').toString();
      telefoneGuardiao = (d['telefone'] ?? d['celular'] ?? '').toString();
    }

    // 3) Envia E-MAIL
    final bodyPlain =
        textoTpl.isNotEmpty ? textoTpl : _htmlParaTextoPuro(htmlTpl);
    await _emailSvc.enviarEmailViaBackend(
      to: emailGuardiao,
      subject: assunto,
      body: bodyPlain,
      htmlBody: htmlTpl.isNotEmpty ? htmlTpl : null,
      nomeGuardiao: nomeGuardiao,
      // textoSocorro: null, // use se quiser
    );

    // 4) Envia SMS (se tiver telefone)
    if (telefoneGuardiao != null && telefoneGuardiao.trim().isNotEmpty) {
      final baseSms =
          textoTpl.isNotEmpty ? textoTpl : _htmlParaTextoPuro(htmlTpl);
      final smsMsg = await _gerarTextoTagsBasico(
        textoBase: baseSms,
        destinatarioEmail: emailGuardiao,
        nomeGuardiao: nomeGuardiao,
      );

      if (!await Permission.sms.request().isGranted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissão de SMS negada')),
        );
      } else {
        try {
          await _messenger.sendSMS(
            phoneNumber: telefoneGuardiao.trim(),
            message: smsMsg,
          );
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('SMS enviado para o guardião')),
          );
        } catch (e) {
          debugPrint('Erro ao enviar SMS: $e');
        }
      }
    }
  }

  // ============================================================
  // 7) UI
  // ============================================================
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
            const Text(
              'Enviar Convite',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'E-mail do Guardião',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _enviarConvite,
              child: const Text('Enviar Convite'),
            ),

            const Divider(height: 32),

            // Convites pendentes
            const Text(
              'Convites Recebidos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
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

            // Meus guardiões
            const Text(
              'Meus Guardiões',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildMeusGuardioes(),

            const Divider(height: 32),

            // Usuários que eu guardo
            const Text(
              'Usuários que eu guardo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildUsuariosQueGuardo(),
          ],
        ),
      ),
    );
  }
}