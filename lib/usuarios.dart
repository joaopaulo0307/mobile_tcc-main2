import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:mobile_tcc/calendario/calendario.dart';
import 'package:mobile_tcc/config.dart';
import 'package:mobile_tcc/lista_compras.dart';
import 'package:mobile_tcc/perfil.dart';
import 'package:provider/provider.dart';

import '../services/theme_service.dart';
import '../meu_casas.dart';

class Usuarios extends StatefulWidget {
  const Usuarios({super.key});

  @override
  State<Usuarios> createState() => _UsuariosState();
}

class _UsuariosState extends State<Usuarios> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<Map<String, dynamic>> _membros = [];
  String? _casaAtualId;
  String? _casaAtualNome;
  bool _isAdmin = false;
  bool _isLoading = true;
  
  final TextEditingController _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Buscar casa atual do usuário
        final userDoc = await _firestore.collection('usuarios').doc(user.uid).get();
        final userData = userDoc.data();
        
        if (userData != null && userData['casaAtual'] != null) {
          _casaAtualId = userData['casaAtual'];
          
          // Buscar informações da casa
          final casaDoc = await _firestore.collection('casas').doc(_casaAtualId).get();
          if (casaDoc.exists) {
            final casaData = casaDoc.data()!;
            _casaAtualNome = casaData['nome'];
            _isAdmin = casaData['donoId'] == user.uid;
            
            // Buscar membros da casa
            final membrosQuery = await _firestore
                .collection('casas')
                .doc(_casaAtualId)
                .collection('membros')
                .get();
            
            _membros.clear();
            
            for (var membroDoc in membrosQuery.docs) {
              final membroData = membroDoc.data();
              final usuarioDoc = await _firestore.collection('usuarios').doc(membroDoc.id).get();
              final usuarioData = usuarioDoc.data();
              
              _membros.add({
                'id': membroDoc.id,
                'nome': usuarioData?['nome'] ?? 'Usuário',
                'email': usuarioData?['email'] ?? membroData['email'],
                'funcao': membroData['funcao'] ?? 'Membro',
                'isAdmin': membroData['isAdmin'] ?? false,
                'dataConvite': membroData['dataConvite']?.toDate(),
                'aceitouConvite': membroData['aceitouConvite'] ?? false,
              });
            }
            
            // Ordenar: admin primeiro, depois por nome
            _membros.sort((a, b) {
              if (a['isAdmin'] && !b['isAdmin']) return -1;
              if (!a['isAdmin'] && b['isAdmin']) return 1;
              return a['nome'].compareTo(b['nome']);
            });
          }
        }
      }
    } catch (e) {
      print('Erro ao carregar dados: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  // ==================== DRAWER ====================
  Widget _buildDrawer(BuildContext context) {
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
                ],
              ),
            ),
          ),
          
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: Icon(Icons.attach_money, color: textColor),
                  title: Text('Home', style: TextStyle(color: textColor)),
                  onTap: () => _navigateToHome(context),
                ),
                ListTile(
                  leading: Icon(Icons.attach_money, color: textColor),
                  title: Text('Econômico', style: TextStyle(color: textColor)),
                  onTap: () => _navigateToEconomico(context),
                ),
                ListTile(
                  leading: Icon(Icons.calendar_today, color: textColor),
                  title: Text('Calendário', style: TextStyle(color: textColor)),
                  onTap: () => _navigateToCalendario(context),
                ),
                ListTile(
                  leading: Icon(Icons.people, color: Colors.blue),
                  title: const Text('Usuários', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.check, color: Colors.blue, size: 16),
                  onTap: () => _navigateToUsuarios(context),
                ),
                ListTile(
                  leading: Icon(Icons.shopping_cart, color: Colors.blue),
                  title: const Text('Lista de Compras', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.check, color: Colors.blue, size: 16),
                  onTap: () => _navigateToListaCompras(context),
                ),
                Divider(color: Theme.of(context).dividerColor),
                ListTile(
                  leading: Icon(Icons.house, color: textColor),
                  title: Text('Minhas Casas', style: TextStyle(color: textColor)),
                  onTap: () => _navigateToMinhasCasas(context),
                ),
                ListTile(
                  leading: Icon(Icons.person, color: textColor),
                  title: Text('Meu Perfil', style: TextStyle(color: textColor)),
                  onTap: () => _navigateToPerfil(context),
                ),
                ListTile(
                  leading: Icon(Icons.settings, color: textColor),
                  title: Text('Configurações', style: TextStyle(color: textColor)),
                  onTap: () => _navigateToConfiguracoes(context),
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

  // ==================== APP BAR ====================
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu, color: Colors.black),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      title: Text(
        _casaAtualNome != null ? 'Membros - $_casaAtualNome' : 'Membros',
        style: const TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: false,
      iconTheme: const IconThemeData(color: Colors.black),
      actions: _isAdmin ? [
        IconButton(
          icon: const Icon(Icons.person_add, color: Colors.black),
          onPressed: () => _mostrarDialogoConvite(context),
          tooltip: 'Convidar membro',
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.black),
          onPressed: _carregarDados,
          tooltip: 'Atualizar',
        ),
      ] : null,
    );
  }

  // ==================== BODY CONTENT ====================
  Widget _buildContent(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_casaAtualId == null) {
      return _buildSemCasa();
    }

    return Container(
      color: Colors.grey[50],
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '# Membros',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_membros.length} membro${_membros.length != 1 ? 's' : ''} na casa',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  if (_isAdmin) const SizedBox(height: 8),
                  if (_isAdmin) Text(
                    'Você é o administrador desta casa',
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Lista de membros
            if (_membros.isEmpty)
              _buildSemMembros()
            else
              ..._membros.map((membro) => _buildMembroCard(membro)).toList(),

            // Seção "Destinos" da imagem
            Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '## Destinos',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDestinoItem('Editor', Colors.blue),
                  const SizedBox(height: 12),
                  _buildDestinoItem('Escolar', Colors.green),
                  if (_isAdmin) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blue[100]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue[700], size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Como administrador, você pode gerenciar funções e permissões dos membros.',
                              style: TextStyle(
                                color: Colors.blue[800],
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Footer
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildSemCasa() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.house_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            const Text(
              '## Nenhum membro na casa',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Você ainda não tem uma casa. Crie uma primeiro.',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _navigateToHome(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.add_home),
              label: const Text('Criar Uma Casa Primeiro'),
            ),
            const SizedBox(height: 40),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildSemMembros() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.people_outline,
            size: 60,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          const Text(
            'Nenhum membro ainda',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Convide pessoas para participar da casa',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          if (_isAdmin)
            ElevatedButton.icon(
              onPressed: () => _mostrarDialogoConvite(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.person_add),
              label: const Text('Convidar Primeiro Membro'),
            ),
        ],
      ),
    );
  }

  Widget _buildMembroCard(Map<String, dynamic> membro) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _mostrarDetalhesMembro(membro),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: membro['isAdmin'] ? Colors.blue[100] : Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      membro['nome'].substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        color: membro['isAdmin'] ? Colors.blue[800] : Colors.grey[700],
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Informações
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '## ${membro['nome']}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          if (membro['isAdmin']) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.blue[100]!),
                              ),
                              child: Text(
                                'Admin',
                                style: TextStyle(
                                  color: Colors.blue[800],
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        membro['funcao'],
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        membro['email'],
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (!membro['aceitouConvite']) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.pending, size: 12, color: Colors.orange),
                            const SizedBox(width: 4),
                            Text(
                              'Convite pendente',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange[700],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Botões de ação
                if (_isAdmin && !membro['isAdmin'] && _auth.currentUser?.uid != membro['id'])
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.grey),
                    onSelected: (value) {
                      if (value == 'remover') {
                        _removerMembro(membro);
                      } else if (value == 'promover') {
                        _promoverParaAdmin(membro);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'promover',
                        child: Row(
                          children: [
                            Icon(Icons.star, size: 18),
                            SizedBox(width: 8),
                            Text('Promover a Admin'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'remover',
                        child: Row(
                          children: [
                            Icon(Icons.person_remove, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Remover da casa', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDestinoItem(String titulo, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            titulo == 'Editor' ? Icons.edit : Icons.school,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              titulo,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            size: 14,
            color: color.withOpacity(0.7),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Organizar seus serviços de forma simples.",
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            "© Todos os direitos reservados - 2025",
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            "TaskDomus v1.0.0",
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== FUNÇÕES DE CONVITE ====================
  void _mostrarDialogoConvite(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Convidar para a casa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email do convidado',
                hintText: 'exemplo@gmail.com',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.email),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _emailController.clear(),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Função (opcional)',
                hintText: 'ex: Editor, Escolar, etc.',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.work),
              ),
              onChanged: (value) {
                // Armazenar função temporariamente
              },
            ),
            const SizedBox(height: 16),
            Text(
              'O convidado receberá um email e a casa aparecerá na conta dele.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () => _enviarConvite(context),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('ENVIAR CONVITE'),
          ),
        ],
      ),
    );
  }

  Future<void> _enviarConvite(BuildContext context) async {
    final email = _emailController.text.trim();
    
    if (email.isEmpty) {
      _mostrarMensagem('Digite um email válido');
      return;
    }

    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      _mostrarMensagem('Email inválido');
      return;
    }

    try {
      // Verificar se usuário existe
      final users = await _firestore
          .collection('usuarios')
          .where('email', isEqualTo: email)
          .get();

      String usuarioId;
      
      if (users.docs.isEmpty) {
        // Criar usuário pendente
        final novoUsuarioDoc = _firestore.collection('usuarios').doc();
        usuarioId = novoUsuarioDoc.id;
        
        await novoUsuarioDoc.set({
          'email': email,
          'nome': email.split('@')[0],
          'status': 'pendente',
          'dataCriacao': DateTime.now(),
        });
      } else {
        usuarioId = users.docs.first.id;
      }

      // Adicionar como membro pendente na casa
      await _firestore
          .collection('casas')
          .doc(_casaAtualId)
          .collection('membros')
          .doc(usuarioId)
          .set({
            'email': email,
            'isAdmin': false,
            'aceitouConvite': false,
            'dataConvite': DateTime.now(),
            'funcao': 'Membro',
            'convitePor': _auth.currentUser?.uid,
          });

      // Adicionar casa à lista de convites pendentes do usuário
      await _firestore
          .collection('usuarios')
          .doc(usuarioId)
          .collection('convitesPendentes')
          .doc(_casaAtualId)
          .set({
            'casaNome': _casaAtualNome,
            'casaId': _casaAtualId,
            'dataConvite': DateTime.now(),
            'convitePor': _auth.currentUser?.email,
          });

      Navigator.pop(context);
      _emailController.clear();
      
      _mostrarSucesso('Convite enviado para $email');
      _carregarDados();
      
    } catch (e) {
      _mostrarErro('Erro ao enviar convite: $e');
    }
  }

  Future<void> _removerMembro(Map<String, dynamic> membro) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover membro'),
        content: Text('Tem certeza que deseja remover ${membro['nome']} da casa?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('REMOVER'),
          ),
        ],
      ),
    );

    if (confirmado == true) {
      try {
        await _firestore
            .collection('casas')
            .doc(_casaAtualId)
            .collection('membros')
            .doc(membro['id'])
            .delete();

        // Remover casa da lista do usuário removido
        await _firestore
            .collection('usuarios')
            .doc(membro['id'])
            .update({
              'casas': FieldValue.arrayRemove([_casaAtualId])
            });

        _mostrarSucesso('${membro['nome']} removido da casa');
        _carregarDados();
      } catch (e) {
        _mostrarErro('Erro ao remover membro: $e');
      }
    }
  }

  Future<void> _promoverParaAdmin(Map<String, dynamic> membro) async {
    try {
      await _firestore
          .collection('casas')
          .doc(_casaAtualId)
          .collection('membros')
          .doc(membro['id'])
          .update({
            'isAdmin': true,
            'funcao': 'Administrador',
          });

      _mostrarSucesso('${membro['nome']} promovido a administrador');
      _carregarDados();
    } catch (e) {
      _mostrarErro('Erro ao promover membro: $e');
    }
  }

  void _mostrarDetalhesMembro(Map<String, dynamic> membro) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(membro['nome']),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: ${membro['email']}'),
            const SizedBox(height: 8),
            Text('Função: ${membro['funcao']}'),
            const SizedBox(height: 8),
            Text('Status: ${membro['aceitouConvite'] ? 'Membro ativo' : 'Convite pendente'}'),
            if (membro['dataConvite'] != null) ...[
              const SizedBox(height: 8),
              Text('Convidado em: ${membro['dataConvite'].toString().split(' ')[0]}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('FECHAR'),
          ),
        ],
      ),
    );
  }

  // ==================== NAVEGAÇÃO ====================
  void _navigateToMinhasCasas(context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const MeuCasas()),
      (route) => false,
    );
  }

  void _navigateToHome(BuildContext context) {
    Navigator.pop(context);
    // Navegar para Home
  }

  void _navigateToEconomico(BuildContext context) {
    Navigator.pop(context);
    // Navegar para Econômico
  }

  void _navigateToCalendario(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const CalendarPage()),
      (route) => false,
    );
    // Navegar para Calendário
  }

  void _navigateToUsuarios(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const Usuarios()),
      (route) => false,
    );
    // Navegar para Usuários
  }

  void _navigateToListaCompras(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const ListaCompras()),
      (route) => false,
    );
    // Navegar para Lista de Compras
  }

  void _navigateToPerfil(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const PerfilPage()),
      (route) => false,
    );
    // Navegar para Perfil
  }

  void _navigateToConfiguracoes(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const ConfigPage()),
      (route) => false,
    );
    // Navegar para Configurações
  }

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _mostrarMensagem(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ==================== BUILD PRINCIPAL ====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(context),
      drawer: _buildDrawer(context),
      body: _buildContent(context),
    );
  }
}