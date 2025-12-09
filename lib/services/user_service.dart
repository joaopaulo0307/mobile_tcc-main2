import 'package:shared_preferences/shared_preferences.dart';

class UserService {
  static String _userEmail = "usuario@exemplo.com";
  static List<String> _tarefasRealizadas = [];
  static String _userName = "Usuário";
  static bool _isInitialized = false;

  // Método de inicialização completo
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Carregar dados do usuário
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
      
      _isInitialized = true;
      print('UserService inicializado com sucesso');
    } catch (e) {
      print('Erro ao inicializar UserService: $e');
      // Fallback para dados de exemplo em caso de erro
      initializeWithSampleData();
      _isInitialized = true;
    }
  }

  // Setters com persistência
  static Future<void> setUserData(String email, String name) async {
    _userEmail = email;
    _userName = name;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', email);
      await prefs.setString('user_name', name);
    } catch (e) {
      print('Erro ao salvar dados do usuário: $e');
    }
  }

  static Future<void> setTarefasRealizadas(List<String> tarefas) async {
    _tarefasRealizadas = List.from(tarefas); // Cria uma cópia para evitar modificações externas
    
    try {
      await _salvarTarefasNoStorage();
    } catch (e) {
      print('Erro ao salvar tarefas: $e');
    }
  }

  // Método auxiliar para salvar tarefas
  static Future<void> _salvarTarefasNoStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('tarefas_realizadas', _tarefasRealizadas);
  }

  // Getters
  static String get userEmail => _userEmail;
  static String get userName => _userName;
  static List<String> get tarefasRealizadas => List.from(_tarefasRealizadas); // Retorna cópia

  // Adicione algumas tarefas de exemplo
  static void initializeWithSampleData() {
    _tarefasRealizadas = [
      "Passear com o cachorro",
      "Comprar arroz",
      "Limpar a casa",
      "Fazer exercícios",
      "Estudar Flutter"
    ];
  }

  // Métodos adicionais para manipulação de tarefas
  static Future<void> adicionarTarefaRealizada(String tarefa) async {
    _tarefasRealizadas.add(tarefa);
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

  // Método para verificar se o serviço está inicializado
  static bool get isInitialized => _isInitialized;

  // Método para obter dados do usuário em formato de mapa
  static Map<String, dynamic> getUserData() {
    return {
      'email': _userEmail,
      'nome': _userName,
      'tarefasRealizadas': List.from(_tarefasRealizadas),
      'quantidadeTarefas': _tarefasRealizadas.length,
    };
  }

  // Método para atualizar apenas o nome
  static Future<void> updateUserName(String newName) async {
    _userName = newName;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', newName);
    } catch (e) {
      print('Erro ao atualizar nome do usuário: $e');
    }
  }

  // Método para atualizar apenas o email
  static Future<void> updateUserEmail(String newEmail) async {
    _userEmail = newEmail;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', newEmail);
    } catch (e) {
      print('Erro ao atualizar email do usuário: $e');
    }
  }

  // Método para limpar todos os dados (logout)
  static Future<void> clearUserData() async {
    _userEmail = "usuario@exemplo.com";
    _userName = "Usuário";
    _tarefasRealizadas.clear();
    initializeWithSampleData();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_email');
      await prefs.remove('user_name');
      await prefs.remove('tarefas_realizadas');
    } catch (e) {
      print('Erro ao limpar dados do usuário: $e');
    }
  }

  // Método para verificar se é o usuário padrão
  static bool get isDefaultUser => _userEmail == "usuario@exemplo.com" && _userName == "Usuário";
}