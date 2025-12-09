import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../acesso/auth_service.dart';

class CadastroPage extends StatefulWidget {
  const CadastroPage({super.key});

  @override
  State<CadastroPage> createState() => _CadastroPageState();
}

class _CadastroPageState extends State<CadastroPage> {

  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  final _confirmarSenha = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _loading = false;
  bool _verSenha = true;
  bool _verConfirmarSenha = true;

  Future<void> _cadastrar() async {
    if (!_formKey.currentState!.validate()) return;

    if (_senha.text != _confirmarSenha.text) {
      _mostrarErro("As senhas não coincidem");
      return;
    }

    setState(() => _loading = true);

    try {
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _email.text.trim(),
            password: _senha.text.trim(),
          );

      await FirebaseFirestore.instance
          .collection("usuarios")
          .doc(cred.user!.uid)
          .set({
        "nome": _nome.text.trim(),
        "email": _email.text.trim(),
        "criadoEm": DateTime.now(),
      });

      _mostrarSucesso("Cadastro realizado com sucesso!");
      Navigator.pop(context);

    } on FirebaseAuthException catch (e) {
      _mostrarErro(e.message ?? "Erro desconhecido");
    }

    setState(() => _loading = false);
  }

  void _mostrarErro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _mostrarSucesso(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF133A67),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [

                const Text(
                  "Cadastro",
                  style: TextStyle(color: Colors.white, fontSize: 26),
                ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _nome,
                  decoration: _dec("Nome completo"),
                  validator: (v) => v!.isEmpty ? "Informe seu nome" : null,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _dec("Email"),
                  validator: (v) =>
                      v != null && v.contains("@") ? null : "Email inválido",
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _senha,
                  obscureText: _verSenha,
                  decoration: _dec("Senha", icone: IconButton(
                    icon: Icon(_verSenha ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _verSenha = !_verSenha),
                  )),
                  validator: (v) =>
                      v!.length < 6 ? "Mínimo 6 caracteres" : null,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _confirmarSenha,
                  obscureText: _verConfirmarSenha,
                  decoration: _dec("Confirmar senha", icone: IconButton(
                    icon: Icon(_verConfirmarSenha ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _verConfirmarSenha = !_verConfirmarSenha),
                  )),
                  validator: (v) =>
                      v!.isEmpty ? "Confirme sua senha" : null,
                ),
                const SizedBox(height: 20),

                _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : ElevatedButton(
                        onPressed: _cadastrar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: const Text(
                          "Cadastrar",
                          style: TextStyle(fontSize: 18),
                        ),
                      ),

                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Já tem conta? Fazer login",
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _dec(String texto, {Widget? icone}) {
    return InputDecoration(
      labelText: texto,
      filled: true,
      fillColor: Colors.white,
      suffixIcon: icone,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    _senha.dispose();
    _confirmarSenha.dispose();
    super.dispose();
  }
}
