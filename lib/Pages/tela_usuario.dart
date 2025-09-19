import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crud/services/firestore.dart';
import 'tela_login.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<String?> buscarMensagemPorCampo(String chave) async {
  final qs = await FirebaseFirestore.instance
      .collection('mensagens')
      .where('chave', isEqualTo: chave)
      .limit(1)
      .get();
  if (qs.docs.isEmpty) return null;
  final data = qs.docs.first.data();
  return (data['conteudo'] as String?)?.trim();
}

/// Substitui variáveis estilo {{nome}} no template
String preencherVariaveisMensagem(String template, Map<String, String> vars) {
  var out = template;
  vars.forEach((k, v) => out = out.replaceAll('{{$k}}', v));
  return out;
}

/// Stub para envio de email via backend (implemente sua API depois)
Future<void> enviarEmailViaBackend({
  required String to,
  required String subject,
  required String body,
}) async {
  // TODO: implemente chamada HTTP/Cloud Function aqui.
  // Mantido vazio para não quebrar compilação.
}

class TelaUsuario extends StatefulWidget {
  const TelaUsuario({Key? key}) : super(key: key);

  @override
  State<TelaUsuario> createState() => _TelaUsuarioState();
}

class _TelaUsuarioState extends State<TelaUsuario> {
  final FirestoreService firestoreService = FirestoreService();
  final _formKey = GlobalKey<FormState>();

  final nomeController = TextEditingController();
  final emailController = TextEditingController();
  final telefoneController = TextEditingController();
  final dataNascController = TextEditingController();
  final senhaController = TextEditingController();
  final senhaConfirmController = TextEditingController();

  String? _sexoSelecionado;

  @override
  void initState() {
    super.initState();
    FirebaseAuth.instance.setLanguageCode('pt');
  }

  bool validarEmail(String email) {
    // Regex simples e permissivo
    final regex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
    return regex.hasMatch(email);
  }

  String gerarHashSenha(String senha) {
    final bytes = utf8.encode(senha);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  Future<void> selecionarDataNascimento(BuildContext context) async {
    final hoje = DateTime.now();

    final dataEscolhida = await showDatePicker(
      context: context,
      initialDate: DateTime(hoje.year - 20),
      firstDate: DateTime(hoje.year - 120),
      lastDate: DateTime(hoje.year - 13),
      locale: const Locale('pt', 'BR'),
      helpText: 'Selecione a data de nascimento',
      cancelText: 'Cancelar',
      confirmText: 'OK',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFF2C4CD), // dia selecionado + botões
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFF2C4CD), // cor dos botões
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (dataEscolhida != null) {
      setState(() {
        dataNascController.text =
            DateFormat('dd/MM/yyyy', 'pt_BR').format(dataEscolhida);
      });
    }
  }

  Future<void> registrarUsuario() async {
    if (_formKey.currentState!.validate()) {
      if (senhaController.text != senhaConfirmController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('As senhas não coincidem.')),
        );
        return;
      }

      try {
        final dataNasc = DateFormat('dd/MM/yyyy', 'pt_BR')
            .parseStrict(dataNascController.text.trim());

        final hashSenha = gerarHashSenha(senhaController.text.trim());

        final authResult = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
          email: emailController.text.trim(),
          password: senhaController.text.trim(),
        );
        final uid = authResult.user!.uid;

        await authResult.user!.sendEmailVerification();

        final dadosUsuario = {
          'nome': nomeController.text.trim(),
          'email': emailController.text.trim(),
          'numerotelefone': telefoneController.text.trim(),
          'dataNasc': dataNasc,
          'sexo': _sexoSelecionado,
          'inativar': false,
          'timestamp': DateTime.now(),
          'senha': hashSenha, // remova se não quiser salvar hash no Firestore
        };

        await firestoreService.addUsuario(uid, dadosUsuario);

        // Busca e envia mensagem de boas-vindas (fallback local)
        final mensagemTemplate =
            await buscarMensagemPorCampo('mensagem_email_boas_vindas');

        if (mensagemTemplate != null) {
          final mensagemPersonalizada = preencherVariaveisMensagem(
            mensagemTemplate,
            {'nome': nomeController.text.trim()},
          );

          await enviarEmailViaBackend(
            to: emailController.text.trim(),
            subject: 'Boas-vindas ao ImTrouble!',
            body: mensagemPersonalizada,
          );
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuário registrado com sucesso!')),
        );

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text("Verificação de Email"),
            content: const Text(
              "Um link de verificação foi enviado ao seu email. "
              "Por favor, confirme seu email para ativar sua conta e realizar o login.",
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await FirebaseAuth.instance.currentUser?.reload();
                  if (FirebaseAuth.instance.currentUser?.emailVerified ?? false) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Email verificado. Faça login agora.'),
                      ),
                    );
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const TelaLogin()),
                    );
                  } else {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Email ainda não verificado. Por favor, verifique seu email.',
                        ),
                      ),
                    );
                  }
                },
                child: const Text("Já verifiquei"),
              ),
            ],
          ),
        );

        _formKey.currentState!.reset();
        setState(() {
          _sexoSelecionado = null;
          dataNascController.clear();
          senhaController.clear();
          senhaConfirmController.clear();
        });
      } on FirebaseAuthException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: ${e.message}')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pink = const Color(0xFFF2C4CD);

    return Scaffold(
      appBar: AppBar(title: const Text("Registrar Usuário")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Nome
              TextFormField(
                controller: nomeController,
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nome é obrigatório.';
                  }
                  final nome = value.trim();
                  if (!RegExp(r'^[A-Za-zÀ-ÿ\s]+$').hasMatch(nome)) {
                    return 'Nome deve conter apenas letras e espaços.';
                  }
                  if (nome.length < 5 || nome.length > 100) {
                    return 'Nome deve ter entre 5 e 100 caracteres.';
                  }
                  return null;
                },
              ),
              // E-mail
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'E-mail'),
                validator: (value) =>
                    value == null || !validarEmail(value) ? 'E-mail inválido.' : null,
              ),
              // Senha
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
                validator: (value) {
                  final txt = value?.trim() ?? '';
                  if (txt.isEmpty) return 'Selecione uma data válida.';
                  try {
                    DateFormat('dd/MM/yyyy', 'pt_BR').parseStrict(txt);
                    return null;
                  } catch (_) {
                    return 'Use o formato dd/MM/yyyy.';
                  }
                },
              ),
              // Sexo
              DropdownButtonFormField<String>(
                value: _sexoSelecionado,
                decoration: const InputDecoration(labelText: 'Sexo'),
                items: const [
                  DropdownMenuItem(value: 'Masculino', child: Text('Masculino')),
                  DropdownMenuItem(value: 'Feminino', child: Text('Feminino')),
                ],
                onChanged: (valor) => setState(() => _sexoSelecionado = valor),
                validator: (value) => value == null ? 'Selecione o sexo.' : null,
              ),
              const SizedBox(height: 20),

              // Botão Registrar estilizado
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: registrarUsuario,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: pink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text("Registrar"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
