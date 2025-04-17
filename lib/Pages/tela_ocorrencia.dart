import 'package:crud/services/firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class OcorrenciasPage extends StatefulWidget {
  @override
  _OcorrenciasPageState createState() => _OcorrenciasPageState();
}

class _OcorrenciasPageState extends State<OcorrenciasPage> {
  final FirestoreService _service = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Minhas Ocorrências'),
        backgroundColor: Colors.pink,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _service.getOcorrenciasStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return Center(child: Text('Nenhuma ocorrência encontrada.'));
          }
          final docs = snap.data!.docs;
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;
              final status = data['status'] as String? ?? 'aberto';
              final ts = (data['timestamp'] as Timestamp).toDate();
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${data['tipoOcorrencia'] ?? ''} • ${data['gravidade'] ?? ''}',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 6),
                      Text(data['relato'] ?? ''),
                      SizedBox(height: 6),
                      Text('Status: ${status.toUpperCase()}'),
                      Text('Registrada em: ${ts.toLocal()}'),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Botão SOS continua disponível
                          ElevatedButton(
                            onPressed: () {
                              // Aqui você pode navegar para detalhe ou reenviar SOS
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                            ),
                            child: Text('S.O.S'),
                          ),
                          SizedBox(width: 8),
                          // Só exibe finalizar se estiver aberto
                          if (status == 'aberto')
                            ElevatedButton(
                              onPressed: () async {
                                await _service.finalizarOcorrencia(doc.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Ocorrência finalizada'),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                              child: Text('Finalizar'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
