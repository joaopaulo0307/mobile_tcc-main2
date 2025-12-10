import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ Adicionado
import 'firebase_options.dart'; 
import 'package:mobile_tcc/meu_casas.dart';
import 'package:provider/provider.dart';
import '../acesso/cadastro.dart';  // CORREÇÃO: Importe apenas se existir
import 'acesso/esqueci_senha.dart'; 
import 'package:mobile_tcc/home.dart';
import 'package:mobile_tcc/config.dart';
import '../services/theme_service.dart';
import '../services/formatting_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_database/firebase_database.dart'; 
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:io' as io;
import 'services/finance_service.dart';

// ✅ SERViÇO DE USUÁRIO ADICIONADO
class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> criarOuAtualizarUsuario() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('usuarios').doc(user.uid).set({
      'nome': user.displayName ?? user.email?.split('@')[0] ?? 'Usuário',
      'email': user.email,
      'foto': user.photoURL,
      'ultimoLogin': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)); // ← merge: não sobrescreve se já existir
    
    print('✅ Usuário salvo/atualizado no Firestore: ${user.uid}');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // ✅ INICIALIZAÇÃO DO FIREBASE
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase inicializado com sucesso');
    
    // Log do usuário atual
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      print('👤 Usuário logado: ${user.email}');
      // ✅ Salva usuário no Firestore ao iniciar app
      await UserService().criarOuAtualizarUsuario();
    } else {
      print('🔒 Nenhum usuário logado');
    }
    
  } catch (e) {
    print('❌ Erro na inicialização do app: $e');
  }
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeService()),
        Provider(create: (context) => FormattingService()),
        ChangeNotifierProvider(create: (context) => FinanceService()),
        StreamProvider<User?>( // ✅ PROVIDER PARA USUÁRIO FIREBASE
          create: (context) => FirebaseAuth.instance.authStateChanges(),
          initialData: null,
        ),
      ],
      child: const LoginPage(),
    ),
  );
}

class LoginPage extends StatelessWidget {  
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: themeService.themeData,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('pt', 'BR'),
          ],
          home: const AuthWrapper(),
          routes: {
            '/cadastro': (context) => const CadastroPage(),
            '/minhas_casas': (context) => const MeuCasas(),
            '/home': (context) {
              final args = ModalRoute.of(context)!.settings.arguments as Map<String, String>? ?? {};
              return HomePage(casa: args);
            },
            '/esqueci_senha': (context) => const EsqueciSenhaPage(),
            '/config': (context) => const ConfigPage(),
          },
        );
      },
    );
  }
}

// ✅ WRAPPER PARA GERENCIAR AUTENTICAÇÃO
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User?>(context);
    
    if (user == null) {
      return const LandingPage();
    } else {
      // Verificar se o usuário verificou o email
      if (!user.emailVerified) {
        return EmailVerificationScreen(user: user);
      }
      
      // ✅ SALVA USUÁRIO NO FIRESTORE QUANDO LOGADO
      WidgetsBinding.instance.addPostFrameCallback((_) {
        UserService().criarOuAtualizarUsuario();
      });
      
      return const MeuCasas();
    }
  }
}

// ✅ TELA DE VERIFICAÇÃO DE EMAIL 
class EmailVerificationScreen extends StatefulWidget {
  final User user;
  
  const EmailVerificationScreen({super.key, required this.user});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isSendingEmail = false;
  bool _isChecking = false;
  bool _isCreatingHouse = false;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;
  Timer? _autoCheckTimer;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  Future<void> _logVerificationEvent() async {
    try {
      await _analytics.logEvent(
        name: 'email_verification_completed',
        parameters: {
          'user_id': widget.user.uid,
          'user_email': widget.user.email ?? 'unknown',
          'timestamp': DateTime.now().toIso8601String(),
          'verification_method': 'email_link',
          'platform': Platform.operatingSystem,
        },
      );
      debugPrint('✅ Evento de verificação registrado no Analytics');
    } catch (e) {
      debugPrint('⚠️ Erro no Analytics: $e');
    }
  }

  Future<void> _createUserHouse() async {
    if (_isCreatingHouse) return;
    
    setState(() => _isCreatingHouse = true);
    
    try {
      final userId = widget.user.uid;
      final userEmail = widget.user.email ?? 'sem-email';
      final userName = widget.user.displayName ?? userEmail.split('@')[0];
      
      // ✅ PRIMEIRO: Salvar usuário no Firestore
      await UserService().criarOuAtualizarUsuario();
      
      // ✅ SEGUNDO: Criar casa no Realtime Database (mantendo seu código atual)
      final houseData = {
        'owner_id': userId,
        'owner_email': userEmail,
        'owner_name': userName,
        'house_name': 'Casa de $userName',
        'created_at': ServerValue.timestamp,
        'members': {
          userId: {
            'email': userEmail,
            'name': userName,
            'role': 'owner',
            'joined_at': ServerValue.timestamp,
          }
        },
        'settings': {
          'theme': 'light',
          'notifications': true,
          'language': 'pt-BR',
        },
        'rooms': {
          'sala': {
            'name': 'Sala',
            'type': 'living_room',
            'created_at': ServerValue.timestamp,
          }
        }
      };
      
      final houseRef = _database.child('houses').push();
      final houseId = houseRef.key!;
      
      await houseRef.set(houseData);
      
      await _database.child('users').child(userId).set({
        'email': userEmail,
        'name': userName,
        'house_id': houseId,
        'verified': true,
        'created_at': ServerValue.timestamp,
        'last_login': ServerValue.timestamp,
      });
      
      debugPrint('🏠 Casa criada com ID: $houseId');
      
      await _analytics.logEvent(
        name: 'house_created',
        parameters: {
          'user_id': userId,
          'house_id': houseId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      
    } catch (e) {
      debugPrint('❌ Erro ao criar casa: $e');
      _showErrorSnackBar('Erro ao configurar sua casa: ${_getErrorMessage(e)}');
    } finally {
      setState(() => _isCreatingHouse = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeVerification();
    _checkIfAlreadyVerified();
  }

  Future<void> _checkIfAlreadyVerified() async {
    await widget.user.reload();
    if (widget.user.emailVerified && mounted) {
      await _createUserHouse();
      _navigateToHome();
    }
  }

  Future<void> _initializeVerification() async {
    await widget.user.reload();
    _startAutoVerificationChecker();
    if (mounted) setState(() {});
  }

  void _startAutoVerificationChecker() {
    _autoCheckTimer?.cancel();
    
    _autoCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      await widget.user.reload();
      if (widget.user.emailVerified) {
        timer.cancel();
        await _onEmailVerified();
      }
    });
  }

  Future<void> _onEmailVerified() async {
    await _logVerificationEvent();
    await _createUserHouse();
    _navigateToHome();
  }

  Future<void> _checkEmailVerification() async {
    setState(() => _isChecking = true);
    
    try {
      await widget.user.reload();
      
      if (widget.user.emailVerified) {
        await _onEmailVerified();
        return;
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Email ainda não verificado'),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      _showErrorSnackBar('Erro ao verificar: ${_getErrorMessage(e)}');
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _sendVerificationEmail() async {
    if (_resendCooldown > 0) return;
    
    setState(() => _isSendingEmail = true);
    
    try {
      await widget.user.sendEmailVerification();
      
      await _analytics.logEvent(
        name: 'email_verification_resent',
        parameters: {
          'user_id': widget.user.uid,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      
      _showSuccessDialog();
      
      setState(() => _resendCooldown = 45);
      _startCooldownTimer();
      
    } catch (e) {
      _showErrorSnackBar('Erro ao enviar: ${_getErrorMessage(e)}');
    } finally {
      if (mounted) setState(() => _isSendingEmail = false);
    }
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        if (_resendCooldown > 0) {
          _resendCooldown--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 10),
            Text('Email Enviado!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Verifique sua caixa de entrada.'),
            const SizedBox(height: 8),
            Text(
              'Dica: Clique no link e volte para este app',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• O app detectará automaticamente', style: TextStyle(fontSize: 13)),
                  Text('• Sua casa será criada automaticamente', style: TextStyle(fontSize: 13)),
                  Text('• Não precisa clicar em "Já verifiquei"', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ENTENDI'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Fechar',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  String _getErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('too-many-requests')) {
      return 'Muitas tentativas. Aguarde alguns minutos.';
    } else if (errorString.contains('user-not-found')) {
      return 'Usuário não encontrado.';
    } else if (errorString.contains('network')) {
      return 'Erro de conexão. Verifique sua internet.';
    } else if (errorString.contains('requires-recent-login')) {
      return 'Sessão expirada. Faça login novamente.';
    } else if (errorString.contains('database')) {
      return 'Erro no banco de dados. Tente novamente.';
    }
    
    return 'Tente novamente mais tarde.';
  }

  Future<void> _openEmailApp() async {
    final email = widget.user.email;
    if (email == null) {
      _showErrorSnackBar('Email não disponível');
      return;
    }
    
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: email,
    );
    
    try {
      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri);
        
        await _analytics.logEvent(
          name: 'email_app_opened',
          parameters: {'user_id': widget.user.uid},
        );
      } else {
        _showErrorSnackBar('Não foi possível abrir o app de email');
      }
    } catch (e) {
      _showErrorSnackBar('Erro: ${_getErrorMessage(e)}');
    }
  }

  Future<void> _logout() async {
    try {
      await _auth.signOut();
      await _analytics.logEvent(name: 'user_logged_out');
    } catch (e) {
      debugPrint('Erro ao fazer logout: $e');
    }
  }

  void _navigateToHome() {
    if (_isCreatingHouse) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Criando sua casa...'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Configurando tudo para você',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
      
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context).pop();
          Navigator.of(context).pushReplacementNamed('/home');
        }
      });
    } else {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _autoCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final email = widget.user.email ?? 'Email não disponível';
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verifique seu email'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Sair',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isCreatingHouse 
                    ? Colors.orange.withOpacity(0.1) 
                    : theme.primaryColor.withOpacity(0.1),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.email_outlined,
                      size: 80,
                      color: _isCreatingHouse ? Colors.orange : theme.primaryColor,
                    ),
                    if (_isCreatingHouse)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.home,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              Text(
                _isCreatingHouse ? 'Criando sua casa...' : 'Verificação de Email',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _isCreatingHouse ? Colors.orange : theme.primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Text(
                      _isCreatingHouse 
                        ? 'Email verificado! Criando sua casa...' 
                        : 'Email de verificação enviado para:',
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      email,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _isCreatingHouse ? Colors.green : theme.primaryColor,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                    if (_isCreatingHouse) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                    ],
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              Text(
                _isCreatingHouse
                  ? 'Sua casa está sendo configurada com todas as funcionalidades.'
                  : 'Por favor, verifique sua caixa de entrada e clique no link de verificação.',
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 24),
              
              if (!_isCreatingHouse)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Como funciona:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '1. Clique no link do email\n'
                            '2. Volte para este app automaticamente\n'
                            '3. Sua casa será criada automaticamente\n'
                            '4. Pronto para usar!',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isChecking || _isCreatingHouse ? null : _checkEmailVerification,
                  icon: _isChecking
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onPrimary,
                          ),
                        )
                      : _isCreatingHouse
                        ? const Icon(Icons.home)
                        : const Icon(Icons.check_circle_outline),
                  label: Text(
                    _isCreatingHouse
                      ? 'Criando sua casa...'
                      : _isChecking
                        ? 'Verificando...'
                        : 'Já verifiquei meu email',
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: _isCreatingHouse ? Colors.orange : null,
                  ),
                ),
              ),
              
              if (!_isCreatingHouse) ...[
                const SizedBox(height: 16),
                
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: (_isSendingEmail || _resendCooldown > 0) ? null : _sendVerificationEmail,
                    icon: _isSendingEmail
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.primaryColor,
                            ),
                          )
                        : const Icon(Icons.send),
                    label: _resendCooldown > 0
                        ? Text('Reenviar em $_resendCooldown')
                        : Text(_isSendingEmail ? 'Enviando...' : 'Reenviar email'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                TextButton.icon(
                  onPressed: _openEmailApp,
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('Abrir app de email'),
                ),
                
                const SizedBox(height: 24),
                
                TextButton(
                  onPressed: _isCreatingHouse ? null : () => _auth.signOut(),
                  child: Text(
                    _isCreatingHouse ? 'Aguarde...' : 'Usar outra conta',
                    style: TextStyle(
                      color: _isCreatingHouse ? Colors.grey : null,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== LANDING PAGE (TELA DE LOGIN) ====================

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  bool _obscureSenha = true;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  Future<void> _fazerLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final senha = _senhaController.text.trim();
      
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: senha,
      );
      
      if (!mounted) return;
      
      // ✅ SALVA USUÁRIO NO FIRESTORE APÓS LOGIN BEM-SUCEDIDO
      if (userCredential.user != null) {
        await UserService().criarOuAtualizarUsuario();
      }
      
      if (userCredential.user?.emailVerified == false) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Por favor, verifique seu email antes de entrar.'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login realizado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String mensagemErro = 'Erro ao fazer login';
      
      switch (e.code) {
        case 'user-not-found':
          mensagemErro = 'Usuário não encontrado';
          break;
        case 'wrong-password':
          mensagemErro = 'Senha incorreta';
          break;
        case 'invalid-email':
          mensagemErro = 'Email inválido';
          break;
        case 'user-disabled':
          mensagemErro = 'Esta conta foi desativada';
          break;
        case 'too-many-requests':
          mensagemErro = 'Muitas tentativas. Tente novamente mais tarde';
          break;
        default:
          mensagemErro = 'Erro: ${e.message}';
      }
      
      _mostrarErro(mensagemErro);
    } catch (e) {
      _mostrarErro('Erro inesperado: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red, 
        content: Text(mensagem),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              SizedBox.expand(
                child: Image.asset(
                  'lib/assets/images/fundo-tcc-mobile.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(color: themeService.primaryColor);
                  },
                ),
              ),
              Positioned.fill(
                child: Container(color: Colors.black.withOpacity(0.3)),
              ),
              SafeArea(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircleAvatar(
                            radius: 20,
                            backgroundColor: Color(0xFF133A67),
                            child: Text("TD", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: Icon(
                              themeService.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              themeService.toggleTheme();
                            },
                          ),
                        ],
                      ),
                    ),
                    
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: themeService.isDarkMode 
                                    ? Colors.grey[800]!.withOpacity(0.9)
                                    : const Color.fromARGB(255, 79, 73, 72),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                width: MediaQuery.of(context).size.width * 0.85,
                                constraints: const BoxConstraints(maxWidth: 400),
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      const Text(
                                        'LOGIN',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 30),
                                      
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Email',
                                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 8),
                                          TextFormField(
                                            controller: _emailController,
                                            keyboardType: TextInputType.emailAddress,
                                            textInputAction: TextInputAction.next,
                                            style: TextStyle(
                                              color: themeService.isDarkMode ? Colors.white : Colors.black,
                                            ),
                                            decoration: InputDecoration(
                                              filled: true,
                                              fillColor: themeService.isDarkMode 
                                                ? Colors.grey[700] 
                                                : Colors.white.withOpacity(0.9),
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8), 
                                                borderSide: BorderSide.none
                                              ),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                              hintText: 'seu@email.com',
                                              hintStyle: TextStyle(
                                                color: themeService.isDarkMode ? Colors.white70 : Colors.black54,
                                              ),
                                            ),
                                            validator: (value) {
                                              if (value == null || value.isEmpty) return 'Por favor, insira seu email';
                                              final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
                                              if (!emailRegex.hasMatch(value)) return 'Por favor, insira um email válido';
                                              return null;
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 20),
                                      
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Senha',
                                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 8),
                                          TextFormField(
                                            controller: _senhaController,
                                            obscureText: _obscureSenha,
                                            textInputAction: TextInputAction.done,
                                            style: TextStyle(
                                              color: themeService.isDarkMode ? Colors.white : Colors.black,
                                            ),
                                            decoration: InputDecoration(
                                              filled: true,
                                              fillColor: themeService.isDarkMode 
                                                ? Colors.grey[700] 
                                                : Colors.white.withOpacity(0.9),
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8), 
                                                borderSide: BorderSide.none
                                              ),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                              hintText: '••••••',
                                              hintStyle: TextStyle(
                                                color: themeService.isDarkMode ? Colors.white70 : Colors.black54,
                                              ),
                                              suffixIcon: IconButton(
                                                icon: Icon(
                                                  _obscureSenha ? Icons.visibility : Icons.visibility_off, 
                                                  color: themeService.isDarkMode ? Colors.white70 : Colors.grey
                                                ),
                                                onPressed: () => setState(() => _obscureSenha = !_obscureSenha),
                                              ),
                                            ),
                                            validator: (value) {
                                              if (value == null || value.isEmpty) return 'Por favor, insira sua senha';
                                              if (value.length < 6) return 'A senha deve ter pelo menos 6 caracteres';
                                              return null;
                                            },
                                            onFieldSubmitted: (_) => _fazerLogin(),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      
                                      GestureDetector(
                                        onTap: () => Navigator.pushNamed(context, '/esqueci_senha'),
                                        child: const Text(
                                          'Esqueceu a senha?',
                                          style: TextStyle(
                                            color: Colors.white, 
                                            fontSize: 14, 
                                            decoration: TextDecoration.underline
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      const SizedBox(height: 30),
                                      
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: () => Navigator.pushNamed(context, '/cadastro'),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.white,
                                                side: const BorderSide(color: Colors.white),
                                                padding: const EdgeInsets.symmetric(vertical: 16),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              child: const Text(
                                                'CADASTRAR', 
                                                style: TextStyle(fontWeight: FontWeight.bold)
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: _isLoading ? null : _fazerLogin,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: themeService.primaryColor,
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(vertical: 16),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                disabledBackgroundColor: themeService.primaryColor.withOpacity(0.5),
                                              ),
                                              child: _isLoading
                                                  ? const SizedBox(
                                                      height: 20, 
                                                      width: 20, 
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2, 
                                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white)
                                                      )
                                                    )
                                                  : const Text(
                                                      'ENTRAR', 
                                                      style: TextStyle(fontWeight: FontWeight.bold)
                                                    ),
                                            ),
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
                      ),
                    ),
                    
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFF133A67),
                            Color(0xFF1E4A7A),
                          ],
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.transparent,
                              backgroundImage: AssetImage('assets/images/logo-mobile.png'),
                            ),
                          ),
                          
                          const Column(
                            children: [
                              Text(
                                'Organize suas tarefas de forma simples',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Todos os direitos reservados - 2025',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }
}