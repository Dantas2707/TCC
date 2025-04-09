import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({Key? key}) : super(key: key);

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _cpfController = TextEditingController();
  final TextEditingController _telefoneController = TextEditingController();
  final TextEditingController _dataNascController = TextEditingController();
  String? _sexoSelecionado;

  bool _isLoading = true;
  User? user;

  @override
  void initState() {
    super.initState();
    // Obtém o usuário atual do FirebaseAuth
    user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _loadUserData();
    }
  }

  // Carrega dados do Firestore usando o UID do usuário logado
  Future<void> _loadUserData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('usuario')
          .doc(user!.uid)
          .get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        _nomeController.text = data['nome'] ?? '';
        _emailController.text = data['email'] ?? '';
        _cpfController.text = data['cpf'] ?? '';
        _telefoneController.text = data['numerotelefone'] ?? '';
        if (data['dataNasc'] != null) {
          if (data['dataNasc'] is Timestamp) {
            final Timestamp timestamp = data['dataNasc'];
            final DateTime dateTime = timestamp.toDate();
            _dataNascController.text =
                dateTime.toIso8601String().split('T').first;
          } else if (data['dataNasc'] is String) {
            _dataNascController.text = data['dataNasc'];
          }
        }
        _sexoSelecionado = data['sexo'] ?? null;
      }
    } catch (e) {
      debugPrint('Erro ao carregar dados do usuário: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _cpfController.dispose();
    _telefoneController.dispose();
    _dataNascController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Informações Pessoais'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Nome (apenas visualização)
                    TextFormField(
                      controller: _nomeController,
                      decoration: const InputDecoration(labelText: 'Nome'),
                      readOnly: true,
                    ),
                    // E-mail (apenas visualização)
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'E-mail'),
                      readOnly: true,
                    ),
                    // CPF (apenas visualização, sem opacidade)
                    TextFormField(
                      controller: _cpfController,
                      decoration: const InputDecoration(labelText: 'CPF'),
                      readOnly: true,
                    ),
                    // Telefone (apenas visualização)
                    TextFormField(
                      controller: _telefoneController,
                      decoration: const InputDecoration(labelText: 'Telefone'),
                      readOnly: true,
                    ),
                    // Data de Nascimento (apenas visualização)
                    TextFormField(
                      controller: _dataNascController,
                      decoration: const InputDecoration(labelText: 'Data Nascimento'),
                      readOnly: true,
                    ),
                    // Sexo (apenas visualização sem seta)
                    IgnorePointer(
                      ignoring: true,
                      child: DropdownButtonFormField<String>(
                        icon: const SizedBox.shrink(), // Remove a seta
                        value: _sexoSelecionado,
                        decoration: const InputDecoration(labelText: 'Sexo'),
                        items: const [
                          DropdownMenuItem(
                            value: 'Masculino',
                            child: Text('Masculino'),
                          ),
                          DropdownMenuItem(
                            value: 'Feminino',
                            child: Text('Feminino'),
                          ),
                        ],
                        onChanged: (valor) {
                          setState(() {
                            _sexoSelecionado = valor;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
