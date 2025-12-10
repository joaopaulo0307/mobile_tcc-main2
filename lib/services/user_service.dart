import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  // Dados locais
  static String _userEmail = "usuario@exemplo.com";
  static List<String> _tarefasRealizadas = [];
  static String _userName = "Usuário";
  static bool _isInitialized = false;
  
  // Firebase
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // ==================== INICIALIZAÇÃO ====================
  
  /// Inicializa o UserService carregando dados do SharedPreferences e Firebase
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 1. Carregar dados locais do SharedPreferences
      _userEmail = prefs.getString('user_email') ?? "usuario@exemplo.com";
      _userName = prefs.getString('user_name') ?? "Usuário";
      
      // Carregar tarefas realizadas
      final tarefasSalvas = prefs.getStringList('tarefas_realizadas');
      _tarefasRealizadas = tarefasSalvas ?? [];
      
      // Se não houver tarefas, inicializar com dados de exemplo
      if (_tarefasRealizadas.isEmpty) {
        initializeWithSampleData();
        await _salvarTarefasNoStorage();
      }
      
      // 2. Sincronizar com Firebase (se usuário estiver logado)
      final user = _auth.currentUser;
      if (user != null) {
        await _sincronizarComFirebase(user.uid);
      }
      
      _isInitialized = true;
      print('✅ UserService inicializado com sucesso');
      print('📋 Nome: $_userName, Email: $_userEmail');
    } catch (e) {
      print('❌ Erro ao inicializar UserService: $e');
      // Fallback para dados de exemplo em caso de erro
      initializeWithSampleData();
      _isInitialized = true;
    }
  }

  // ==================== SINCRONIZAÇÃO FIREBASE ====================
  
  /// Sincroniza dados locais com Firebase
  static Future<void> _sincronizarComFirebase(String userId) async {
    try {
      final userDoc = await _firestore.collection('usuarios').doc(userId).get();
      
      if (userDoc.exists) {
        final data = userDoc.data()!;
        
        // 1. Atualizar nome do Firebase (prioridade máxima)
        final nomeFirebase = data['nome'] as String?;
        if (nomeFirebase != null && nomeFirebase.isNotEmpty) {
          print('🔄 Sincronizando nome do Firebase: $nomeFirebase');
          _userName = nomeFirebase;
          await _salvarNomeNoStorage(_userName);
        }
        
        // 2. Atualizar email do Firebase
        final emailFirebase = data['email'] as String?;
        if (emailFirebase != null && emailFirebase.isNotEmpty) {
          _userEmail = emailFirebase;
          await _salvarEmailNoStorage(_userEmail);
        }
        
        // 3. Carregar tarefas do Firebase (opcional - mantém local se vazio)
        final tarefasSnapshot = await _firestore
            .collection('usuarios')
            .doc(userId)
            .collection('tarefasRealizadas')
            .orderBy('data', descending: true)
            .limit(20)
            .get();
            
        if (tarefasSnapshot.docs.isNotEmpty) {
          final tarefasFirebase = tarefasSnapshot.docs
              .map((doc) => doc.data()['descricao'] as String? ?? '')
              .where((desc) => desc.isNotEmpty)
              .toList();
              
          if (tarefasFirebase.isNotEmpty) {
            _tarefasRealizadas = tarefasFirebase;
            await _salvarTarefasNoStorage();
          }
        }
      } else {
        // Se não existe documento no Firebase, criar um com dados locais
        print('📄 Criando novo documento no Firebase para usuário $userId');
        await _firestore.collection('usuarios').doc(userId).set({
          'nome': _userName,
          'email': _userEmail,
          'dataCriacao': DateTime.now(),
          'casas': [],
          'casaAtual': null,
          'status': 'ativo',
        });
      }
    } catch (e) {
      print('⚠️ Erro ao sincronizar com Firebase: $e');
    }
  }

  // ==================== GETTERS ====================
  
  static String get userEmail => _userEmail;
  static String get userName => _userName;
  static List<String> get tarefasRealizadas => List.from(_tarefasRealizadas);
  static bool get isInitialized => _isInitialized;
  static bool get isDefaultUser => _userEmail == "usuario@exemplo.com" && _userName == "Usuário";

  // ==================== MÉTODOS PRINCIPAIS ====================
  
  /// Define os dados do usuário (email e nome) salvando em ambos
  static Future<void> setUserData(String email, String name) async {
    print('💾 Salvando dados do usuário: $name ($email)');
    
    _userEmail = email;
    _userName = name;
    
    try {
      // 1. Salvar localmente
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', email);
      await prefs.setString('user_name', name);
      
      // 2. Salvar no Firebase (se usuário estiver logado)
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('usuarios').doc(user.uid).set({
          'nome': name,
          'email': email,
          'dataCriacao': DateTime.now(),
          'dataAtualizacao': DateTime.now(),
          'casas': [],
          'casaAtual': null,
          'status': 'ativo',
        }, SetOptions(merge: true));
        
        print('✅ Dados salvos no Firebase');
      }
    } catch (e) {
      print('❌ Erro ao salvar dados do usuário: $e');
      rethrow;
    }
  }

  /// Atualiza apenas o nome do usuário
  static Future<void> updateUserName(String newName) async {
    if (newName.trim().isEmpty) {
      print('⚠️ Nome vazio, ignorando atualização');
      return;
    }
    
    print('✏️ Atualizando nome para: $newName');
    _userName = newName.trim();
    
    try {
      // 1. Salvar localmente
      await _salvarNomeNoStorage(_userName);
      
      // 2. Salvar no Firebase
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('usuarios').doc(user.uid).update({
          'nome': _userName,
          'dataAtualizacao': DateTime.now(),
        });
        print('✅ Nome atualizado no Firebase');
      }
    } catch (e) {
      print('❌ Erro ao atualizar nome: $e');
      rethrow;
    }
  }

  /// Atualiza apenas o email do usuário
  static Future<void> updateUserEmail(String newEmail) async {
    _userEmail = newEmail;
    try {
      await _salvarEmailNoStorage(_userEmail);
      
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('usuarios').doc(user.uid).update({
          'email': _userEmail,
          'dataAtualizacao': DateTime.now(),
        });
      }
    } catch (e) {
      print('❌ Erro ao atualizar email: $e');
    }
  }

  /// Busca o nome diretamente do Firebase (para garantir dados atualizados)
  static Future<String> getNomeDoFirebase() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final userDoc = await _firestore.collection('usuarios').doc(user.uid).get();
        
        if (userDoc.exists) {
          final data = userDoc.data()!;
          final nomeFirebase = data['nome'] as String?;
          
          if (nomeFirebase != null && nomeFirebase.isNotEmpty) {
            // Atualizar localmente para consistência
            if (nomeFirebase != _userName) {
              print('🔄 Nome diferente: Local "$_userName" vs Firebase "$nomeFirebase"');
              _userName = nomeFirebase;
              await _salvarNomeNoStorage(nomeFirebase);
            }
            return nomeFirebase;
          }
        }
      }
    } catch (e) {
      print('⚠️ Erro ao buscar nome do Firebase: $e');
    }
    
    // Fallback para nome local
    return _userName;
  }

  /// Sincroniza forçadamente com Firebase
  static Future<void> syncWithFirebase() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        print('🔄 Forçando sincronização com Firebase...');
        await _sincronizarComFirebase(user.uid);
        print('✅ Sincronização completa');
      }
    } catch (e) {
      print('❌ Erro na sincronização: $e');
    }
  }

  // ==================== TAREFAS REALIZADAS ====================
  
  static void initializeWithSampleData() {
    _tarefasRealizadas = [
      "Organizar quarto",
      "Fazer compras no mercado",
      "Pagar contas mensais",
      "Estudar Flutter por 2 horas",
      "Fazer exercícios físicos",
      "Ler um livro por 30 minutos"
    ];
  }

  static Future<void> adicionarTarefaRealizada(String tarefa) async {
    if (tarefa.trim().isEmpty) return;
    
    _tarefasRealizadas.add(tarefa.trim());
    await _salvarTarefasNoStorage();
    
    // Salvar também no Firebase
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore
            .collection('usuarios')
            .doc(user.uid)
            .collection('tarefasRealizadas')
            .add({
              'descricao': tarefa.trim(),
              'data': DateTime.now(),
            });
      } catch (e) {
        print('⚠️ Erro ao salvar tarefa no Firebase: $e');
      }
    }
  }

  static Future<void> setTarefasRealizadas(List<String> tarefas) async {
    _tarefasRealizadas = List.from(tarefas);
    await _salvarTarefasNoStorage();
  }

  static Future<void> removerTarefaRealizada(String tarefa) async {
    _tarefasRealizadas.remove(tarefa);
    await _salvarTarefasNoStorage();
  }

  static Future<void> limparTarefasRealizadas() async {
    _tarefasRealizadas.clear();
    await _salvarTarefasNoStorage();
  }

  static bool contemTarefa(String tarefa) {
    return _tarefasRealizadas.contains(tarefa);
  }

  static int get quantidadeTarefasRealizadas => _tarefasRealizadas.length;

  // ==================== MÉTODOS AUXILIARES ====================
  
  static Future<void> _salvarTarefasNoStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('tarefas_realizadas', _tarefasRealizadas);
  }
  
  static Future<void> _salvarNomeNoStorage(String nome) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', nome);
  }
  
  static Future<void> _salvarEmailNoStorage(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_email', email);
  }

  static Map<String, dynamic> getUserData() {
    return {
      'email': _userEmail,
      'nome': _userName,
      'tarefasRealizadas': List.from(_tarefasRealizadas),
      'quantidadeTarefas': _tarefasRealizadas.length,
    };
  }

  /// Limpa todos os dados do usuário (logout)
  static Future<void> clearUserData() async {
    print('🧹 Limpando dados do usuário...');
    
    _userEmail = "usuario@exemplo.com";
    _userName = "Usuário";
    _tarefasRealizadas.clear();
    initializeWithSampleData();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_email');
      await prefs.remove('user_name');
      await prefs.remove('tarefas_realizadas');
      print('✅ Dados locais limpos');
    } catch (e) {
      print('❌ Erro ao limpar dados locais: $e');
    }
  }

  /// Verifica se o usuário está logado no Firebase
  static bool get isLoggedIn => _auth.currentUser != null;

  /// Obtém o ID do usuário atual
  static String? get userId => _auth.currentUser?.uid;

  /// Obtém o email do usuário atual do Firebase
  static String? get firebaseEmail => _auth.currentUser?.email;
}