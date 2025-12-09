import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/theme_service.dart';
import '../home.dart';
import '../meu_casas.dart';
import '../perfil.dart';
import '../config.dart';
import '../calendario/calendario.dart';
import '../economic/economico.dart';

class Usuarios extends StatefulWidget {
  const Usuarios({super.key});

  @override
  State<Usuarios> createState() => _UsuariosState();
}

class _UsuariosState extends State<Usuarios> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nomeController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  String _searchQuery = '';
  List<Map<String, dynamic>> _membros = [];
  bool _isLoading = true;
  String? _currentHouseId;
  String? _currentHouseName;
  String? _houseOwnerId;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser?.uid;
    _loadCurrentHouse();
  }

  // 🔥 VERIFICAR SE USUÁRIO ATUAL É O MESMO DO AUTH
  bool _isValidUser() {
    final currentAuthUser = _auth.currentUser;
    if (currentAuthUser == null) return false;
    return currentAuthUser.uid == _currentUserId;
  }

  // 🔥 CARREGAR CASA ATUAL
  Future<void> _loadCurrentHouse() async {
    try {
      if (!_isValidUser()) {
        print('❌ USUÁRIO INVÁLIDO - Redirecionando...');
        _logoutSilently();
        return;
      }

      final user = _auth.currentUser;
      if (user == null) {
        print('❌ Usuário não autenticado');
        return;
      }

      print('🔍 Buscando casa do usuário: ${user.uid}');
      print('📧 Email do usuário: ${user.email}');

      // Buscar TODAS as casas onde o usuário é membro
      final housesSnapshot = await _firestore
          .collection('casas')
          .where('membros.${user.uid}', isNotEqualTo: null)
          .get();

      print('🏠 Número de casas encontradas: ${housesSnapshot.docs.length}');

      if (housesSnapshot.docs.isNotEmpty) {
        // Pegar a primeira casa (poderia implementar seleção de casa depois)
        final houseDoc = housesSnapshot.docs.first;
        final houseData = houseDoc.data() as Map<String, dynamic>;
        
        print('✅ Casa selecionada: ${houseData['nome']}');
        print('🔑 ID da casa: ${houseDoc.id}');
        print('👑 Dono da casa: ${houseData['donoId']}');
        
        setState(() {
          _currentHouseId = houseDoc.id;
          _currentHouseName = houseData['nome'] ?? 'Minha Casa';
          _houseOwnerId = houseData['donoId'];
        });
        
        _loadMembros();
      } else {
        print('⚠️  Nenhuma casa encontrada para o usuário');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('❌ Erro ao carregar casa: $e');
      setState(() => _isLoading = false);
    }
  }

  // 🔥 LOGOUT SILENCIOSO
  void _logoutSilently() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _auth.signOut();
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    });
  }

  // 🔥 CARREGAR MEMBROS DA CASA (SIMPLIFICADO)
  Future<void> _loadMembros() async {
    try {
      if (_currentHouseId == null) {
        setState(() => _isLoading = false);
        return;
      }

      print('🔍 Carregando membros da casa: $_currentHouseId');

      final houseDoc = await _firestore.collection('casas').doc(_currentHouseId!).get();
      
      if (!houseDoc.exists) {
        print('❌ Casa não encontrada');
        setState(() => _isLoading = false);
        return;
      }

      final houseData = houseDoc.data() as Map<String, dynamic>;
      
      // Extrair membros
      final membrosData = houseData['membros'] as Map<String, dynamic>? ?? {};
      final List<Map<String, dynamic>> membrosList = [];
      
      print('👥 Número de membros na casa: ${membrosData.length}');

      for (var entry in membrosData.entries) {
        final userId = entry.key;
        final memberData = entry.value as Map<String, dynamic>;
        
        try {
          final userDoc = await _firestore.collection('usuarios').doc(userId).get();
          
          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            
            membrosList.add({
              'uid': userId,
              'nome': userData['nome'] ?? userData['email']?.toString().split('@')[0] ?? 'Usuário',
              'email': userData['email']?.toString() ?? '',
              'cargo': (memberData['cargo'] as String?) ?? 'Membro',
              'isOwner': userId == _houseOwnerId,
              'dataEntrada': (memberData['dataEntrada'] as Timestamp?)?.toDate() ?? DateTime.now(),
              'fotoUrl': userData['fotoUrl']?.toString(),
            });
            
            print('✅ Membro carregado: ${userData['email']}');
          }
        } catch (e) {
          print('⚠️  Erro ao carregar usuário $userId: $e');
        }
      }

      // Ordenar membros
      membrosList.sort((a, b) {
        if (a['isOwner'] as bool) return -1;
        if (b['isOwner'] as bool) return 1;
        if (a['cargo'] == 'Administrador' && b['cargo'] != 'Administrador') return -1;
        if (b['cargo'] == 'Administrador' && a['cargo'] != 'Administrador') return 1;
        return (a['nome'] as String).compareTo(b['nome'] as String);
      });

      print('✅ Total de membros carregados: ${membrosList.length}');
      
      setState(() {
        _membros = membrosList;
        _isLoading = false;
      });
      
    } catch (e) {
      print('❌ Erro ao carregar membros: $e');
      setState(() {
        _membros = [];
        _isLoading = false;
      });
    }
  }

  // ✅ ADICIONAR MEMBRO DIRETAMENTE (SEM CONVITE COMPLEXO)
  Future<void> _adicionarMembroDireto(String email, String role, BuildContext context) async {
    try {
      print('=== ADICIONANDO MEMBRO DIRETAMENTE ===');
      print('📧 Email: $email');
      print('🎭 Cargo: $role');

      // 🔴 VALIDAÇÃO: Usuário autenticado
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        _mostrarErro('Usuário não autenticado');
        return;
      }

      // 🔴 VALIDAÇÃO: Casa selecionada
      if (_currentHouseId == null) {
        _mostrarErro('Nenhuma casa selecionada');
        return;
      }

      // Buscar usuário pelo email
      final usersSnapshot = await _firestore
          .collection('usuarios')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (usersSnapshot.docs.isEmpty) {
        _mostrarErro('Usuário não encontrado. Peça para ele se cadastrar no app primeiro.');
        return;
      }

      final userDoc = usersSnapshot.docs.first;
      final userId = userDoc.id;
      final userData = userDoc.data() as Map<String, dynamic>;
      
      print('✅ Usuário encontrado: $userId');
      print('📝 Nome: ${userData['nome']}');

      // Verificar se já é membro
      if (_membros.any((m) => m['uid'] == userId)) {
        _mostrarErro('Este usuário já é membro desta casa');
        return;
      }

      // 🔥 1. ADICIONAR À CASA
      await _firestore.collection('casas').doc(_currentHouseId!).update({
        'membros.$userId': {
          'cargo': role,
          'dataEntrada': FieldValue.serverTimestamp(),
        }
      });

      // 🔥 2. ADICIONAR REFERÊNCIA DA CASA AO USUÁRIO
      await _firestore.collection('usuarios').doc(userId).update({
        'casas.$_currentHouseId': {
          'nome': _currentHouseName ?? 'Minha Casa',
          'cargo': role,
          'dataEntrada': FieldValue.serverTimestamp(),
        }
      });

      // 🔥 3. CRIAR NOTIFICAÇÃO PARA O USUÁRIO
      await _firestore
          .collection('usuarios')
          .doc(userId)
          .collection('notificacoes')
          .add({
            'titulo': 'Você foi adicionado a uma casa!',
            'mensagem': '${currentUser.email?.split('@')[0] ?? currentUser.displayName} adicionou você à casa "$_currentHouseName"',
            'tipo': 'nova_casa',
            'casaId': _currentHouseId,
            'casaNome': _currentHouseName,
            'lida': false,
            'data': FieldValue.serverTimestamp(),
          });

      print('✅ Membro adicionado com sucesso!');
      
      // Atualizar lista
      _loadMembros();

      if (context.mounted) {
        Navigator.of(context).pop();
        _mostrarSucesso('$email foi adicionado à casa como $role!');
      }

    } catch (e) {
      print('❌ ERRO: $e');
      _mostrarErro('Erro ao adicionar membro: ${e.toString()}');
    }
  }

  // 🔥 MODAL PARA ADICIONAR MEMBRO
  void _showAddMemberModal(BuildContext context) {
    final emailController = TextEditingController();
    String selectedRole = 'Membro';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Text(
                'Adicionar Membro',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'E-mail do usuário',
                        hintText: 'usuario@email.com',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    if (_isCurrentUserAdmin)
                      Column(
                        children: [
                          const Text(
                            'Cargo:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: selectedRole,
                            items: ['Membro', 'Administrador']
                                .map((role) => DropdownMenuItem(
                                      value: role,
                                      child: Text(role),
                                    ))
                                .toList(),
                            onChanged: (value) => setState(() => selectedRole = value!),
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.info, color: Colors.blue, size: 24),
                          SizedBox(height: 8),
                          Text(
                            'O usuário precisa estar cadastrado no app com este email.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Ele receberá uma notificação e poderá acessar a casa imediatamente.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue,
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final email = emailController.text.trim();
                    if (email.isEmpty) {
                      _mostrarErro('Digite um e-mail válido');
                      return;
                    }

                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
                      _mostrarErro('Digite um e-mail válido');
                      return;
                    }

                    if (_membros.any((m) => m['email'] == email)) {
                      _mostrarErro('Este usuário já é membro da casa');
                      return;
                    }

                    // Mostrar loading
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(
                        child: CircularProgressIndicator(),
                      ),
                    );

                    await _adicionarMembroDireto(email, selectedRole, context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Adicionar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 🔥 MODAL PARA CRIAR NOVA CASA
  void _showCreateHouseModal(BuildContext context) {
    final houseNameController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text(
            'Criar Nova Casa',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: houseNameController,
                decoration: const InputDecoration(
                  labelText: 'Nome da Casa',
                  hintText: 'Ex: Minha Casa, Família Silva',
                  prefixIcon: Icon(Icons.house),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.info, color: Colors.blue, size: 20),
                    SizedBox(height: 4),
                    Text(
                      'Você será o administrador desta casa',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Pode adicionar membros depois nas configurações',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final houseName = houseNameController.text.trim();
                if (houseName.isEmpty) {
                  _mostrarErro('Digite um nome para a casa');
                  return;
                }

                // Mostrar loading
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                );

                await _criarNovaCasa(houseName, context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Criar'),
            ),
          ],
        );
      },
    );
  }

  // 🔥 CRIAR NOVA CASA NO FIRESTORE
  Future<void> _criarNovaCasa(String houseName, BuildContext context) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _mostrarErro('Usuário não autenticado');
        return;
      }

      // Obter dados do usuário
      final userDoc = await _firestore.collection('usuarios').doc(user.uid).get();
      final userData = userDoc.data() as Map<String, dynamic>? ?? {};

      // Criar documento da casa
      final novaCasa = {
        'nome': houseName,
        'donoId': user.uid,
        'donoEmail': user.email ?? '',
        'donoNome': userData['nome'] ?? user.email?.split('@')[0] ?? 'Usuário',
        'dataCriacao': FieldValue.serverTimestamp(),
        'membros': {
          user.uid: {
            'cargo': 'Dono',
            'dataEntrada': FieldValue.serverTimestamp(),
          }
        },
        'totalMembros': 1,
      };

      final casaDocRef = await _firestore.collection('casas').add(novaCasa);
      final casaId = casaDocRef.id;

      // Atualizar usuário com a referência da casa
      await _firestore.collection('usuarios').doc(user.uid).update({
        'casas.$casaId': {
          'nome': houseName,
          'cargo': 'Dono',
          'dataEntrada': FieldValue.serverTimestamp(),
        }
      });

      print('✅ Casa criada com ID: $casaId');

      // Fechar diálogos
      if (context.mounted) {
        Navigator.of(context).pop(); // Fechar loading
        Navigator.of(context).pop(); // Fechar modal
      }

      // Navegar para a tela de casas
      if (context.mounted) {
        _navigateToHome(context);
      }

    } catch (e) {
      print('❌ Erro ao criar casa: $e');
      
      if (context.mounted) {
        Navigator.of(context).pop(); // Fechar loading
        _mostrarErro('Erro ao criar casa: ${e.toString()}');
      }
    }
  }

  // 🔥 VERIFICAR SE USUÁRIO ATUAL É ADMINISTRADOR
  bool get _isCurrentUserAdmin {
    final currentUser = _auth.currentUser;
    if (currentUser == null || _currentHouseId == null) return false;
    
    if (currentUser.uid == _houseOwnerId) return true;
    
    final currentMember = _membros.firstWhere(
      (m) => m['uid'] == currentUser.uid,
      orElse: () => <String, dynamic>{},
    );
    
    return currentMember['cargo'] == 'Administrador';
  }

  // 🔥 VERIFICAR SE É DONO DA CASA
  bool get _isCurrentUserOwner {
    final currentUser = _auth.currentUser;
    return currentUser?.uid == _houseOwnerId;
  }

  // ✅ FILTRAR MEMBROS POR PESQUISA
  List<Map<String, dynamic>> get _filteredMembros {
    if (_searchQuery.isEmpty) return _membros;
    return _membros.where((membro) =>
      membro['nome'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
      membro['email'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
      membro['cargo'].toString().toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  // ==================== DRAWER ====================
  Widget _buildDrawer(BuildContext context, ThemeService themeService) {
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final user = _auth.currentUser;

    return Drawer(
      backgroundColor: backgroundColor,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: Theme.of(context).primaryColor,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.white,
                    child: Text(
                      user?.email?.substring(0, 1).toUpperCase() ?? 'U',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.email?.split('@')[0] ?? 'Usuário',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? '',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_isCurrentUserOwner)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '⭐ Dono',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  icon: Icons.attach_money,
                  title: 'Econômico',
                  textColor: textColor,
                  onTap: () => _navigateToEconomico(context),
                ),
                _buildDrawerItem(
                  icon: Icons.calendar_today,
                  title: 'Calendário',
                  textColor: textColor,
                  onTap: () => _navigateTo(context, const CalendarPage()),
                ),
                _buildDrawerItem(
                  icon: Icons.people,
                  title: 'Usuários',
                  textColor: textColor,
                  onTap: () {
                    Navigator.pop(context);
                  },
                  isSelected: true,
                ),
                Divider(color: Theme.of(context).dividerColor),
                _buildDrawerItem(
                  icon: Icons.house,
                  title: 'Minhas Casas',
                  textColor: textColor,
                  onTap: () => _navigateToHome(context),
                ),
                _buildDrawerItem(
                  icon: Icons.add_home,
                  title: 'Criar Nova Casa',
                  textColor: textColor,
                  onTap: () => _showCreateHouseModal(context),
                ),
                _buildDrawerItem(
                  icon: Icons.person,
                  title: 'Meu Perfil',
                  textColor: textColor,
                  onTap: () => _navigateTo(context, const PerfilPage()),
                ),
                _buildDrawerItem(
                  icon: Icons.settings,
                  title: 'Configurações',
                  textColor: textColor,
                  onTap: () => _navigateTo(context, const ConfigPage()),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ElevatedButton.icon(
                    onPressed: () => _logout(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.logout, size: 20),
                    label: const Text('Sair'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required Color textColor,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Colors.blue : textColor,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.blue : textColor,
        ),
      ),
      trailing: isSelected ? const Icon(Icons.check, color: Colors.blue, size: 16) : null,
      onTap: onTap,
    );
  }

  // ==================== LOGOUT ====================
  Future<void> _logout(BuildContext context) async {
    try {
      await _auth.signOut();
      if (context.mounted) {
        Navigator.of(context).pushReplacementNamed('/');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao fazer logout: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ==================== APP BAR ====================
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF2D2D2D),
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _currentHouseName ?? 'Membros',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            _membros.isEmpty 
              ? 'Nenhum membro'
              : '${_membros.length} membro${_membros.length > 1 ? 's' : ''}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
      centerTitle: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white),
          onPressed: () => _showSearchDialog(context),
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: _loadMembros,
          tooltip: 'Atualizar',
        ),
        IconButton(
          icon: const Icon(Icons.add_home, color: Colors.white),
          onPressed: () => _showCreateHouseModal(context),
          tooltip: 'Criar Nova Casa',
        ),
      ],
    );
  }

  // ==================== BARRA DE PESQUISA ====================
  void _showSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pesquisar Membros'),
        content: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Digite nome ou e-mail...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _searchQuery = '';
                _searchController.clear();
              });
              Navigator.pop(context);
            },
            child: const Text('Limpar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  // ==================== LISTA DE MEMBROS ====================
  Widget _buildListaMembros(BuildContext context) {
    if (_isLoading) {
      return const Expanded(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Expanded(
      child: Container(
        color: const Color(0xFF1E1E1E),
        child: _filteredMembros.isEmpty
            ? _buildEmptyState()
            : Column(
                children: [
                  if (_searchQuery.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.search, size: 16, color: Colors.grey[400]),
                          const SizedBox(width: 8),
                          Text(
                            '${_filteredMembros.length} resultado${_filteredMembros.length > 1 ? 's' : ''} encontrado${_filteredMembros.length > 1 ? 's' : ''}',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredMembros.length,
                      itemBuilder: (context, index) {
                        final membro = _filteredMembros[index];
                        final isCurrentUser = _auth.currentUser?.uid == membro['uid'];
                        final role = membro['cargo'] as String? ?? 'Membro';
                        final isOwner = membro['isOwner'] as bool;
                        final roleColor = isOwner ? Colors.red : 
                                         role == 'Administrador' ? Colors.orange : Colors.blue;

                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 12),
                          color: const Color(0xFF2D2D2D),
                          child: ListTile(
                            leading: membro['fotoUrl'] != null
                                ? CircleAvatar(
                                    backgroundImage: NetworkImage(membro['fotoUrl'] as String),
                                    radius: 20,
                                  )
                                : Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: roleColor.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isOwner 
                                        ? Icons.star 
                                        : role == 'Administrador' 
                                          ? Icons.admin_panel_settings 
                                          : Icons.person,
                                      color: roleColor,
                                      size: 20,
                                    ),
                                  ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    membro['nome'] as String,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: roleColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    isOwner ? '⭐ Dono' : role,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: roleColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  membro['email'] as String,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (isCurrentUser)
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Você',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            onTap: () => _showMemberDetailsModal(index, context),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'Nenhum membro na casa',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Adicione membros para sua casa',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showAddMemberModal(context),
              icon: const Icon(Icons.add),
              label: const Text('Adicionar Primeiro Membro'),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== BOTÕES DE AÇÃO ====================
  Widget _buildBotoesAcao(BuildContext context) {
    if (!_isCurrentUserAdmin && !_isCurrentUserOwner) {
      return Container(); // Não mostra botão se não for admin/dono
    }

    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF1E1E1E),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _showAddMemberModal(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.add, color: Colors.white, size: 20),
              label: const Text(
                '+ Adicionar Membro',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== DETALHES DO MEMBRO ====================
  void _showMemberDetailsModal(int index, BuildContext context) {
    final membro = _filteredMembros[index];
    final isCurrentUser = _auth.currentUser?.uid == membro['uid'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(membro['nome'] as String),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (membro['fotoUrl'] != null)
                Center(
                  child: CircleAvatar(
                    radius: 40,
                    backgroundImage: NetworkImage(membro['fotoUrl'] as String),
                  ),
                ),
              const SizedBox(height: 16),
              _buildDetailItem('E-mail', membro['email'] as String?),
              _buildDetailItem('Cargo', membro['cargo'] as String?),
              _buildDetailItem('Entrou em', 
                membro['dataEntrada'] is DateTime 
                  ? '${(membro['dataEntrada'] as DateTime).day}/${(membro['dataEntrada'] as DateTime).month}/${(membro['dataEntrada'] as DateTime).year}'
                  : 'Data não disponível'
              ),
              if (membro['isOwner'] as bool)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.star, color: Colors.red, size: 16),
                      SizedBox(width: 8),
                      Text('⭐ Dono da Casa', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value ?? 'Não informado')),
        ],
      ),
    );
  }

  // ==================== MENSAGENS ====================
  void _mostrarSucesso(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _mostrarErro(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Erro'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ==================== FOOTER ====================
  Widget _buildFooter(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      color: const Color(0xFF2D2D2D),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _currentHouseName ?? 'Organize suas tarefas de forma simples',
            style: const TextStyle(color: Colors.white, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          const Text(
            "© Todos os direitos reservados - 2025",
            style: TextStyle(color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ==================== MÉTODOS DE NAVEGAÇÃO ====================
  void _navigateTo(BuildContext context, Widget page) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }

  void _navigateToEconomico(BuildContext context) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Economico(
          casa: {
            'nome': _currentHouseName ?? 'Casa Atual',
            'id': _currentHouseId ?? '1',
          },
        ),
      ),
    );
  }

  void _navigateToHome(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const MeuCasas()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nomeController.dispose();
    super.dispose();
  }

  // ==================== BUILD PRINCIPAL ====================
  @override
  Widget build(BuildContext context) {
    // Verificar se usuário é válido
    if (!_isValidUser()) {
      return Scaffold(
        backgroundColor: const Color(0xFF1E1E1E),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                'Verificando autenticação...',
                style: TextStyle(color: Colors.grey[400]),
              ),
            ],
          ),
        ),
      );
    }

    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: const Color(0xFF1E1E1E),
          appBar: _buildAppBar(context),
          drawer: _buildDrawer(context, themeService),
          body: Column(
            children: [
              _buildListaMembros(context),
              _buildBotoesAcao(context),
              _buildFooter(context),
            ],
          ),
        );
      },
    );
  }
}