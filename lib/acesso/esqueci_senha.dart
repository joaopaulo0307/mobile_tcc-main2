import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EsqueciSenhaPage extends StatefulWidget {
  const EsqueciSenhaPage({super.key});

  @override
  State<EsqueciSenhaPage> createState() => _EsqueciSenhaPageState();
}

class _EsqueciSenhaPageState extends State<EsqueciSenhaPage> {
  final TextEditingController _emailController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _emailEnviado = false;

  Future<void> _enviarEmailRecuperacao() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // ✅ Usa Firebase Auth diretamente
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _emailEnviado = true;
      });
      
      _mostrarSucesso('Email de recuperação enviado com sucesso! Verifique sua caixa de entrada.');
      
    } on FirebaseAuthException catch (e) {
      String mensagemErro = 'Erro ao enviar email de recuperação';
      
      switch (e.code) {
        case 'user-not-found':
          mensagemErro = 'Não encontramos uma conta com este email';
          break;
        case 'invalid-email':
          mensagemErro = 'Email inválido';
          break;
        case 'too-many-requests':
          mensagemErro = 'Muitas tentativas. Tente novamente mais tarde';
          break;
        default:
          mensagemErro = 'Erro: ${e.message}';
      }
      
      _mostrarErro(mensagemErro);
    } catch (e) {
      if (mounted) {
        _mostrarErro('Erro inesperado: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red,
        content: Text(mensagem),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _mostrarSucesso(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green,
        content: Text(mensagem),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _voltarParaLogin() {
    Navigator.pop(context);
  }

  String? _validarEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor, insira seu email';
    }
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(value)) {
      return 'Por favor, insira um email válido';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background
          _buildBackground(),
          
          // Conteúdo principal
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Card(
                  elevation: 10,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  color: const Color.fromARGB(255, 79, 73, 72),
                  child: Padding(
                    padding: const EdgeInsets.all(30),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.lock_reset,
                            size: 60,
                            color: Colors.white,
                          ),
                          
                          const SizedBox(height: 20),
                          
                          const Text(
                            'RECUPERAR SENHA',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          
                          const SizedBox(height: 20),
                          
                          if (!_emailEnviado) ...[
                            const Text(
                              'Digite seu email cadastrado para receber um link de recuperação:',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            
                            const SizedBox(height: 25),
                            
                            // Campo de email
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                hintText: 'seu@email.com',
                                prefixIcon: const Icon(Icons.email),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                              ),
                              validator: _validarEmail,
                              onFieldSubmitted: (_) => _enviarEmailRecuperacao(),
                            ),
                            
                            const SizedBox(height: 30),
                            
                            // Botão de envio
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _enviarEmailRecuperacao,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF5E83AE),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'ENVIAR INSTRUÇÕES',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                            
                            const SizedBox(height: 15),
                            
                            // Informação adicional
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Column(
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.info_outline, size: 16, color: Colors.white70),
                                      SizedBox(width: 8),
                                      Text(
                                        'O link será enviado por email',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.info_outline, size: 16, color: Colors.white70),
                                      SizedBox(width: 8),
                                      Text(
                                        'Verifique também a pasta de spam',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            // Tela de sucesso
                            const Icon(
                              Icons.mark_email_read,
                              color: Color(0xFF5E83AE),
                              size: 70,
                            ),
                            
                            const SizedBox(height: 20),
                            
                            const Text(
                              'Email enviado!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            
                            const SizedBox(height: 15),
                            
                            Text(
                              'Enviamos as instruções para:',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 16,
                              ),
                            ),
                            
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Color(0xFF5E83AE)),
                              ),
                              child: Center(
                                child: Text(
                                  _emailController.text,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 20),
                            
                            Container(
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.green, size: 16),
                                      SizedBox(width: 8),
                                      Text(
                                        'Verifique sua caixa de entrada',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.warning, color: Colors.orange, size: 16),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Verifique também a pasta de spam',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  const Row(
                                    children: [
                                      Icon(Icons.timer, color: Colors.blue, size: 16),
                                      SizedBox(width: 8),
                                      Text(
                                        'O link expira em 1 hora',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 30),
                            
                            // Botões em linha
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Color(0xFF5E83AE)),
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    onPressed: () {
                                      _emailController.clear();
                                      setState(() => _emailEnviado = false);
                                    },
                                    child: const Text(
                                      'ENVIAR PARA OUTRO EMAIL',
                                      style: TextStyle(color: Color(0xFF5E83AE)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _voltarParaLogin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF5E83AE),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: const Text('VOLTAR AO LOGIN'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          
                          const SizedBox(height: 20),
                          
                          // Link para voltar (apenas quando não enviado)
                          if (!_emailEnviado)
                            TextButton(
                              onPressed: _voltarParaLogin,
                              child: const Text(
                                'Voltar ao login',
                                style: TextStyle(
                                  color: Color(0xFF5E83AE),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Botão de voltar flutuante
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(25),
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                onPressed: _voltarParaLogin,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Método para background
  Widget _buildBackground() {
    return Stack(
      children: [
        // Imagem de fundo
        SizedBox.expand(
          child: Image.asset(
            'lib/assets/images/fundo-tcc-mobile.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(color: const Color(0xFF133A67));
            },
          ),
        ),
        // Overlay escuro
        Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(0.5),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
}