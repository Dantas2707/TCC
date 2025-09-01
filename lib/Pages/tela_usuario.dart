import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crud/services/firestore.dart'
    as fsFirestore; // FirestoreService de firestore.dart
import 'tela_login.dart';
import 'dart:convert'; // Necessário para codificação UTF-8
import 'package:crypto/crypto.dart'; // Pacote para gerar hash
import 'package:crud/services/Enviar_mensagem.dart';
import 'package:crud/services/enviar_email.dart'
    as fsEnviarEmail; // Função de envio de e-mail
import 'tela_textoEmails.dart';

class TelaUsuario extends StatefulWidget {
  const TelaUsuario({Key? key}) : super(key: key);

  @override
  State<TelaUsuario> createState() => _TelaUsuarioState();
}

class _TelaUsuarioState extends State<TelaUsuario> {
  final fsFirestore.FirestoreService firestoreService =
      fsFirestore.FirestoreService();
  final _formKey = GlobalKey<FormState>();

  final nomeController = TextEditingController();
  final emailController = TextEditingController();
  final telefoneController = TextEditingController();
  final dataNascController = TextEditingController();
  final senhaController = TextEditingController(); // Senha 1
  final senhaConfirmController = TextEditingController(); // Senha 2

  String? _sexoSelecionado;

  // Função para validar o e-mail
  bool validarEmail(String email) {
    RegExp regex = RegExp(r'^.+@[a-zA-Z]+\.[a-zA-Z]{2,}(?:\.[a-zA-Z]{2,})?$');
    return regex.hasMatch(email);
  }

  // Função para gerar o hash da senha (SHA-256)
  String gerarHashSenha(String senha) {
    final bytes = utf8.encode(senha);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  Future<void> selecionarDataNascimento(BuildContext context) async {
    DateTime hoje = DateTime.now();
    DateTime? dataEscolhida = await showDatePicker(
      context: context,
      initialDate: DateTime(hoje.year - 20),
      firstDate: DateTime(hoje.year - 120),
      lastDate: DateTime(hoje.year - 13),
    );
    if (dataEscolhida != null) {
      setState(() {
        dataNascController.text =
            dataEscolhida.toIso8601String().split('T').first;
      });
    }
  }

  // Função para registrar usuário
  Future<void> registrarUsuario() async {
    if (_formKey.currentState!.validate()) {
      if (senhaController.text != senhaConfirmController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('As senhas não coincidem.')),
        );
        return;
      }

      try {
        // Gera o hash da senha
        String hashSenha = gerarHashSenha(senhaController.text.trim());

        // Cria o usuário no Firebase Authentication
        UserCredential authResult =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: emailController.text.trim(),
          password: senhaController.text.trim(),
        );
        String uid = authResult.user!.uid;

        // Envia o e-mail de verificação
        await authResult.user!.sendEmailVerification();

        // Prepara os dados do usuário
        Map<String, dynamic> dadosUsuario = {
          'nome': nomeController.text.trim(),
          'email': emailController.text.trim(),
          'numerotelefone': telefoneController.text.trim(),
          'dataNasc': DateTime.parse(dataNascController.text),
          'sexo': _sexoSelecionado,
          'inativar': false,
          'timestamp': DateTime.now(),
          'senha': hashSenha,
        };

        // Salva os dados no Firestore utilizando o UID do usuário
        await firestoreService.addUsuario(uid, dadosUsuario);

        // ----------------------------
        // ENVIO DE EMAIL DE BOAS-VINDAS
        // ----------------------------
        // Prepara os valores do usuário que vão substituir os placeholders
        Map<String, String> valoresUsuario = {
          'nome': nomeController.text.trim(),
          'email': emailController.text.trim(),
          // você pode adicionar mais campos, ex: 'telefone': telefoneController.text.trim()
        };

        // Chamada da função do FirestoreService que gera o e-mail final
        String mensagemFinal = await firestoreService.gerarEmailPersonalizado(
          templateNome: 'mensagem_email_boas_vindas',
          valoresUsuario: valoresUsuario,
        );

        // Envia o e-mail pelo backend
        await fsEnviarEmail.enviarEmailViaBackend(
          to: emailController.text.trim(),
          subject: 'Boas-vindas ao ImTrouble!',
          body: mensagemFinal,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuário registrado com sucesso!')),
        );

        // Exibe um diálogo solicitando a verificação do e-mail
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text("Verificação de Email"),
            content: const Text(
                "Um link de verificação foi enviado ao seu email. Por favor, confirme seu email para ativar sua conta e realizar o login."),
            actions: [
              TextButton(
                onPressed: () async {
                  await FirebaseAuth.instance.currentUser?.reload();
                  if (FirebaseAuth.instance.currentUser?.emailVerified ??
                      false) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Email verificado. Faça login agora.')),
                    );
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => LoginScreen()),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Email ainda não verificado. Por favor, verifique seu email.')),
                    );
                  }
                },
                child: const Text("Já verifiquei"),
              ),
            ],
          ),
        );

        // Limpar formulários
        _formKey.currentState!.reset();
        setState(() {
          _sexoSelecionado = null;
          dataNascController.clear();
          senhaController.clear();
          senhaConfirmController.clear();
        });
      } on FirebaseAuthException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: ${e.message}')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Registrar Usuário")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Campo Nome
              TextFormField(
                controller: nomeController,
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nome é obrigatório.';
                  }
                  String nome = value.trim();
                  if (!RegExp(r'^[A-Za-zÀ-ÿ\s]+$').hasMatch(nome)) {
                    return 'Nome deve conter apenas letras e espaços.';
                  }
                  if (nome.length < 5 || nome.length > 100) {
                    return 'Nome deve ter entre 5 e 100 caracteres.';
                  }
                  return null;
                },
              ),
              // Campo E-mail
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'E-mail'),
                validator: (value) => value == null || !validarEmail(value)
                    ? 'E-mail inválido.'
                    : null,
              ),
              // Campo Senha
              TextFormField(
                controller: senhaController,
                decoration: const InputDecoration(labelText: 'Senha'),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Senha é obrigatória.';
                  }
                  if (value.trim().length < 6) {
                    return 'Senha deve ter no mínimo 6 caracteres.';
                  }
                  return null;
                },
              ),
              // Confirmar Senha
              TextFormField(
                controller: senhaConfirmController,
                decoration: const InputDecoration(labelText: 'Confirmar Senha'),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor, confirme a senha.';
                  }
                  if (value != senhaController.text) {
                    return 'As senhas não coincidem.';
                  }
                  return null;
                },
              ),
              // Telefone
              TextFormField(
                controller: telefoneController,
                decoration: const InputDecoration(labelText: 'Telefone'),
                keyboardType: TextInputType.phone,
                validator: (value) =>
                    value == null || value.length < 8 || value.length > 20
                        ? 'Telefone deve ter entre 8 e 20 caracteres.'
                        : null,
              ),
              // Data de Nascimento
              TextFormField(
                controller: dataNascController,
                decoration: const InputDecoration(labelText: 'Data Nascimento'),
                readOnly: true,
                onTap: () => selecionarDataNascimento(context),
                validator: (value) => value == null || value.isEmpty
                    ? 'Selecione uma data válida.'
                    : null,
              ),
              // Sexo
              DropdownButtonFormField<String>(
                value: _sexoSelecionado,
                decoration: const InputDecoration(labelText: 'Sexo'),
                items: const [
                  DropdownMenuItem(
                      value: 'Masculino', child: Text('Masculino')),
                  DropdownMenuItem(value: 'Feminino', child: Text('Feminino')),
                ],
                onChanged: (valor) {
                  setState(() {
                    _sexoSelecionado = valor;
                  });
                },
                validator: (value) =>
                    value == null ? 'Selecione o sexo.' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: registrarUsuario,
                child: const Text("Registrar"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
