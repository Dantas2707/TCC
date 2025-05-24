import 'package:crud/services/firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Gravidade extends StatefulWidget {
  const Gravidade({super.key});

  @override
  State<Gravidade> createState() => _GravidadeState();
}

class _GravidadeState extends State<Gravidade> {
  final FirestoreService firestoreService = FirestoreService();
  final TextEditingController gravidadeController = TextEditingController();
  final TextEditingController numeroController = TextEditingController();

  void openAdicionarGravidadeBox() {
  gravidadeController.clear();
  numeroController.clear();

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Adicionar Gravidade"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: gravidadeController,
            decoration: const InputDecoration(hintText: "Digite a gravidade"),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: numeroController,
                  decoration: const InputDecoration(hintText: "Digite o número de urgência"),
                  keyboardType: TextInputType.number,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.info_outline),
                tooltip: "Informe um número entre 1 e 5:\n1 - Leve\n5 - Urgência máxima",
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Classificação de urgência:\n1 - Leve\n5 - Urgência máxima",
                      ),
                      duration: Duration(seconds: 3),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () async {
            try {
              int urgencia = int.parse(numeroController.text);
              if (urgencia < 1 || urgencia > 5) {
                throw Exception("A urgência deve estar entre 1 e 5.");
              }
              await firestoreService.addgravidade(
                gravidadeController.text,
                urgencia,
              );
              gravidadeController.clear();
              numeroController.clear();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Gravidade adicionada.")),
              );
            } catch (e) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(e.toString())),
              );
            }
          },
          child: const Text("Adicionar"),
        ),
      ],
    ),
  );
}

  void openAtualizarGravidadeBox(String docID, String gravidadeAtual, int numeroAtual) {
    gravidadeController.text = gravidadeAtual;
    numeroController.text = numeroAtual.toString();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Atualizar Gravidade"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: gravidadeController,
              decoration: const InputDecoration(hintText: "Atualize a gravidade"),
            ),
            TextField(
              controller: numeroController,
              decoration: const InputDecoration(hintText: "Atualize o número de urgência"),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              try {
                await firestoreService.atualizargravidade(
                  docID,
                  gravidadeController.text,
                  int.parse(numeroController.text),
                );
                gravidadeController.clear();
                numeroController.clear();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Gravidade atualizada.")),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString())),
                );
              }
            },
            child: const Text("Atualizar"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Gravidade")),
      floatingActionButton: FloatingActionButton(
        onPressed: openAdicionarGravidadeBox,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestoreService.getgravidadeStream(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            List gravidadeList = snapshot.data!.docs;
            return ListView.builder(
              itemCount: gravidadeList.length,
              itemBuilder: (context, index) {
                DocumentSnapshot document = gravidadeList[index];
                String docID = document.id;

                Map<String, dynamic> data = document.data() as Map<String, dynamic>;
                String gravidadeText = data['gravidade'];
                int numeroUrgencia = data['numeroUrgencia'] ?? 0;

                return ListTile(
                  title: Text("$gravidadeText - Urgência: $numeroUrgencia"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => openAtualizarGravidadeBox(docID, gravidadeText, numeroUrgencia),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          firestoreService.inativargravidade(docID);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Gravidade inativada.")),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          } else {
            return const Center(child: Text("Não tem gravidade"));
          }
        },
      ),
    );
  }
}