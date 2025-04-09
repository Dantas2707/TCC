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
  final TextEditingController textController = TextEditingController();

  // Método para abrir o diálogo e adicionar gravidade
  void openAdicionarGravidadeBox() {
    textController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Adicionar Gravidade"),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(
            hintText: "Digite a gravidade",
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              try {
                await firestoreService.addgravidade(textController.text);
                textController.clear();
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

  // Método para abrir o diálogo e atualizar gravidade
  void openAtualizarGravidadeBox(String docID, String gravidadeAtual) {
    textController.text = gravidadeAtual;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Atualizar Gravidade"),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(
            hintText: "Atualize a gravidade",
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              try {
                await firestoreService.atualizargravidade(docID, textController.text);
                textController.clear();
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

                return ListTile(
                  title: Text(gravidadeText),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Atualizar (Editar)
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => openAtualizarGravidadeBox(docID, gravidadeText),
                      ),
                      // Inativar (Excluir)
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
