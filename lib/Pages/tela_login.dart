import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'tela_admin_home.dart';
import 'home_page.dart';
import 'tela_usuario.dart';

class TelaLogin extends StatefulWidget {
  const TelaLogin({Key? key}) : super(key: key);

  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController senhaController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Focus
  final FocusNode emailFocus = FocusNode();
  final FocusNode senhaFocus = FocusNode();

  final String adminEmail = 'aplicativo2025tcc@gmail.com';

  bool _loading = false;
  bool _obscure = true;
  String? _errorMessage; // mensagem fixa abaixo do botão

  @override
  void initState() {
    super.initState();
    // Força PT-BR para links/mensagens do Firebase quando aplicável
    _auth.setLanguageCode('pt');
  }

  // ====== Ações ======
  Future<void> _login() async {
    setState(() => _errorMessage = null); // limpa erro anterior

    // valida apenas no clique
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    final email = emailController.text.trim();
    final senha = senhaController.text;

    setState(() => _loading = true);
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: senha,
      );

      final user = cred.user;
      if (user != null) {
        if (user.email == adminEmail) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const TelaAdminHome()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomePage()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      // Normaliza mensagens para o usuário final
      const credInvalidCodes = {
        'invalid-credential',
        'wrong-password',
        'user-mismatch',
        'invalid-password',
        'invalid-email',
      };

      if (e.code == 'user-not-found') {
        setState(() => _errorMessage = 'E-mail ou senha incorretos.');
      } else if (credInvalidCodes.contains(e.code)) {
        setState(() => _errorMessage = 'E-mail ou senha incorretos.');
      } else if (e.code == 'too-many-requests') {
        setState(() => _errorMessage = 'Muitas tentativas. Tente novamente em instantes.');
      } else if (e.code == 'user-disabled') {
        setState(() => _errorMessage = 'Conta desativada. Contate o suporte.');
      } else {
        // fallback amigável, sem expor texto técnico
        setState(() => _errorMessage = 'Não foi possível entrar. Tente novamente.');
      }
    } catch (_) {
      setState(() => _errorMessage = 'Não foi possível entrar. Tente novamente.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetSenha() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Informe seu e-mail para redefinir a senha.');
      return;
    }
    try {
      await _auth.sendPasswordResetEmail(email: email);
      // Mensagem neutra para evitar exposição de existência de conta
      setState(() => _errorMessage = 'Se o e-mail existir, enviaremos instruções para redefinir a senha.');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-email') {
        setState(() => _errorMessage = 'Se o e-mail existir, enviaremos instruções para redefinir a senha.');
      } else if (e.code == 'too-many-requests') {
        setState(() => _errorMessage = 'Muitas tentativas. Tente novamente em instantes.');
      } else {
        setState(() => _errorMessage = 'Não foi possível enviar o e-mail de redefinição.');
      }
    } catch (_) {
      setState(() => _errorMessage = 'Não foi possível enviar o e-mail de redefinição.');
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    senhaController.dispose();
    emailFocus.dispose();
    senhaFocus.dispose();
    super.dispose();
  }

  // ====== UI ======
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColor = const Color(0xFFF2C4CD); // cor personalizada

    InputDecoration _fieldDeco(String hint) => InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.redAccent),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.redAccent),
          ),
        );

    String? _emailValidator(String? value) {
      final v = (value ?? '').trim();
      if (v.isEmpty) return 'Por favor, preencha o e-mail.';
      final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
      if (!regex.hasMatch(v)) return 'Informe um e-mail válido.';
      return null;
    }

    String? _senhaValidator(String? value) {
      if ((value ?? '').isEmpty) return 'Por favor, preencha a senha.';
      return null;
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.disabled, // valida só no clique
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título
                    Text(
                      'Bem-vindo ao InTrouble!',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Campo e-mail
                    TextFormField(
                      controller: emailController,
                      focusNode: emailFocus,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: _fieldDeco('E-mail'),
                      validator: _emailValidator,
                      onFieldSubmitted: (_) =>
                          FocusScope.of(context).requestFocus(senhaFocus),
                    ),
                    const SizedBox(height: 12),

                    // Campo senha com olho
                    TextFormField(
                      controller: senhaController,
                      focusNode: senhaFocus,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      decoration: _fieldDeco('Senha').copyWith(
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                        ),
                      ),
                      validator: _senhaValidator,
                    ),

                    const SizedBox(height: 10),

                    // Esqueceu a senha?
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: customColor,
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: _resetSenha,
                        child: const Text('Esqueceu a senha?'),
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Botão Entrar
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: _loading
                          ? const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFFF2C4CD), // mesma cor do botão
                                ),
                              ),
                            )
                          : ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: customColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onPressed: _login,
                              child: const Text('Entrar'),
                            ),
                    ),

                    // Mensagem fixa abaixo do botão
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Registrar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Você não é cadastrado? ',
                          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(foregroundColor: customColor),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const TelaUsuario()),
                            );
                          },
                          child: const Text('Registrar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
