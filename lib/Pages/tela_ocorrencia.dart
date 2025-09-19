import 'package:crud/services/firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart'; // para anexos no editor

class OcorrenciasPage extends StatefulWidget {
  const OcorrenciasPage({super.key});

  @override
  State<OcorrenciasPage> createState() => _OcorrenciasPageState();
}

class _OcorrenciasPageState extends State<OcorrenciasPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController; // Controlador das abas
  final FirestoreService _service = FirestoreService();
  late final String _uid;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Usuário não autenticado');
    }
    _uid = user.uid;

    _tabController = TabController(length: 2, vsync: this); // Duas abas: Abertas e Finalizadas
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Ocorrências'),
        backgroundColor: Colors.pink,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Abertas'),
            Tab(text: 'Finalizadas'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOcorrenciasList('aberto'),
          _buildOcorrenciasList('finalizado'),
        ],
      ),
    );
  }

  // Constrói a lista de ocorrências filtradas por status
  Widget _buildOcorrenciasList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: _service.getOcorrenciasDoUsuarioStream(_uid, status: status),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snap.hasError) {
          return Center(
            child: Text(
              'Erro ao carregar ocorrências:\n${snap.error}',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          );
        }

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('Nenhuma ocorrência encontrada.'));
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final doc = docs[i];
            final data = doc.data() as Map<String, dynamic>;

            final tipo = (data['tipoOcorrencia'] as String?) ?? '';
            final gravidade = (data['gravidade'] as String?) ?? '';
            final relato = (data['relato'] as String?) ?? '';
            final docStatus = (data['status'] as String?) ?? 'aberto';

            final ts = (data['timestamp'] as Timestamp?);
            final dataLocal = ts?.toDate();
            final anexos = (data['anexos'] as List?)?.cast<String>() ?? const <String>[];
            final historico = (data['historico'] as List?) ?? const <dynamic>[];

            return Card(
              key: ValueKey(doc.id), // (4) chave estável para reconciliação
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cabeçalho
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$tipo • $gravidade',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        _StatusChip(status: docStatus),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Relato
                    if (relato.isNotEmpty) Text(relato),

                    // Anexos (chips com "x" para remover quando aberto)
                    if (anexos.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: -8,
                        children: [
                          for (int idx = 0; idx < anexos.length; idx++)
                            InputChip(
                              label: Text('Anexo ${idx + 1}'),
                              onPressed: () {
                                // TODO: abrir visualização do anexo (img/pdf)
                              },
                              onDeleted: (docStatus == 'aberto')
                                  ? () async {
                                      try {
                                        await _service.removerAnexo(doc.id, anexos[idx]);
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Anexo removido')),
                                          );
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Falha ao remover: $e')),
                                          );
                                        }
                                      }
                                    }
                                  : null,
                            ),
                        ],
                      ),
                    ],

                    // Data
                    const SizedBox(height: 6),
                    Text(
                      dataLocal != null
                          ? 'Registrada em: ${_formatDateTime(dataLocal)}'
                          : 'Registrada em: —',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),

                    // ---------- HISTÓRICO (expansível) ----------
                    if (historico.isNotEmpty) ...[
                      const Divider(height: 20),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: EdgeInsets.zero,
                        title: Text(
                          'Histórico (${historico.length})',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        children: [
                          const SizedBox(height: 8),
                          ...(historico
                              .cast<Map>()
                              .reversed // mais recente primeiro
                              .map((h) {
                            final ts = h['timestamp'];
                            String quando;
                            if (ts is Timestamp) {
                              quando = _formatDateTime(ts.toDate());
                            } else {
                              quando = '—';
                            }
                            final tipoHist = (h['tipo'] as String?) ?? 'edicao';
                            final relatoAnterior = (h['relatoAnterior'] as String?) ?? '';
                            final novos = (h['novosAnexos'] as List?)?.length ?? 0;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // só data/hora + tipo
                                  Text(
                                    '$quando • $tipoHist',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (relatoAnterior.isNotEmpty)
                                    Text('Relato anterior: $relatoAnterior'),
                                  if (novos > 0) Text('Anexos adicionados: $novos'),
                                ],
                              ),
                            );
                          })).toList(),
                        ],
                      ),
                    ],

                    const SizedBox(height: 10),

                    // Ações
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (docStatus == 'aberto') ...[
                          // EDITAR
                          ElevatedButton(
                            onPressed: () async {
                              await _abrirEditorOcorrencia(
                                context,
                                docId: doc.id,
                                relatoAtual: relato,
                              );
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                            child: const Text('Editar'),
                          ),
                          const SizedBox(width: 8),

                          // FINALIZAR (com confirmação)
                          ElevatedButton(
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text('Finalizar ocorrência?'),
                                      content: const Text('Após finalizar, não será possível editar.'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: const Text('Cancelar'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          child: const Text('Finalizar'),
                                        ),
                                      ],
                                    ),
                                  ) ??
                                  false;

                              if (!ok) return;

                              await _service.finalizarOcorrencia(doc.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Ocorrência finalizada')),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            child: const Text('Finalizar'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ------- Modal de Edição: altera relato e adiciona anexos mantendo histórico -------
  // Mostra "Nenhuma alteração detectada" logo abaixo do campo Relato quando nada mudou.
  Future<void> _abrirEditorOcorrencia(
    BuildContext context, {
    required String docId,
    required String relatoAtual,
  }) async {
    final controller = TextEditingController(text: relatoAtual);
    List<PlatformFile> selecionados = [];

    // regras de validação
    const maxBytes = 10 * 1024 * 1024; // 10 MB por arquivo
    const allowedExts = <String>{
      'jpg', 'jpeg', 'png', 'gif', 'heic', 'pdf', 'doc', 'docx', 'mp4', 'mov'
    };

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            top: 16,
            left: 16,
            right: 16,
          ),
          child: StatefulBuilder(
            builder: (ctx, setModalState) {
              // calcula diferenças em tempo real
              final String textoAtual = controller.text.trim();
              final bool relatoMudou = textoAtual != relatoAtual.trim();
              final bool anexosAdicionados = selecionados.isNotEmpty;
              final bool houveAlteracao = relatoMudou || anexosAdicionados;

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Editar Ocorrência',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: controller,
                    maxLines: null,
                    decoration: const InputDecoration(
                      labelText: 'Relato',
                      border: OutlineInputBorder(),
                    ),
                    // Rebuilda para reavaliar "houveAlteracao"
                    onChanged: (_) => setModalState(() {}),
                  ),

                  // Mensagem inline abaixo do campo Relato quando nada mudou
                  const SizedBox(height: 6),
                  if (!houveAlteracao)
                    Row(
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Nenhuma alteração detectada',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 12),

                  // Seleção de anexos (valida tipo/tamanho e atualiza msg)
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          final res = await FilePicker.platform.pickFiles(
                            allowMultiple: true,
                            type: FileType.any,
                            withData: true, // importante para web
                          );
                          if (res != null && res.files.isNotEmpty) {
                            // validação de tamanho e extensão
                            for (final f in res.files) {
                              // (1) tamanho compatível com diferentes versões do file_picker
                              final int size = (f.bytes != null) ? f.bytes!.length : f.size;

                              // (2) normalizar extensão; vazio é inválido
                              final String ext = ((f.extension ?? '').toLowerCase()).trim();

                              if (size > maxBytes) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Arquivo muito grande: ${f.name} (máx 10MB)')),
                                  );
                                }
                                return;
                              }
                              if (ext.isEmpty || !allowedExts.contains(ext)) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Tipo não permitido: ${f.name}')),
                                  );
                                }
                                return;
                              }
                            }

                            setModalState(() {
                              selecionados.addAll(res.files);
                            });
                          }
                        },
                        child: const Text('Adicionar anexos'),
                      ),
                      const SizedBox(width: 12),
                      Text('Selecionados: ${selecionados.length}'),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Ações do modal
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          final texto = controller.text.trim();

                          // valida relato vazio
                          if (texto.isEmpty) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('O relato não pode ficar vazio')),
                              );
                            }
                            return;
                          }

                          // precisa ter mudado algo (relato ou anexos)
                          if (!houveAlteracao) {
                            // (3) reforça feedback explícito
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Nenhuma alteração detectada')),
                              );
                            }
                            return;
                          }

                          Navigator.pop(ctx); // fecha o modal
                          try {
                            await _service.editarOcorrencia(
                              docId,
                              novoRelato: texto,
                              anexosNovos: selecionados,
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Ocorrência atualizada')),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Falha ao atualizar: $e')),
                              );
                            }
                          }
                        },
                        child: const Text('Salvar'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _formatDateTime(DateTime dt) {
    final d = _two(dt.day);
    final m = _two(dt.month);
    final y = dt.year.toString();
    final hh = _two(dt.hour);
    final mm = _two(dt.minute);
    return '$d/$m/$y $hh:$mm';
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final st = status.toLowerCase();
    Color bg;
    String label;
    if (st == 'aberto') {
      bg = Colors.red.shade100;
      label = 'ABERTO';
    } else if (st == 'finalizado') {
      bg = Colors.green.shade100;
      label = 'FINALIZADO';
    } else {
      bg = Colors.grey.shade300;
      label = st.toUpperCase();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}