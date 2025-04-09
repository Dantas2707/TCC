import 'package:crud/Pages/home_page.dart';
import 'package:crud/Pages/tela_usuario.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  // Função para login
  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null; // Reseta a mensagem de erro
    });

    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim());

      // Navegar para a tela de menu após o login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message;  // Exibe a mensagem de erro
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Login"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Campo de E-mail
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'E-mail'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Informe o e-mail';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Campo de Senha
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Senha'),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Informe a senha';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Exibir mensagem de erro, se houver
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

              // Botão de Login
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          _login();
                        }
                      },
                      child: const Text('Login'),
                    ),

              // Link para tela de cadastro de usuário
              TextButton(
                onPressed: () {
                  // Navegar para a tela de registro de usuário
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const TelaUsuario()),
                  );
                },
                child: const Text("Não tem uma conta? Registre-se"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
