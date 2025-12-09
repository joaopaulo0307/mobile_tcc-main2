import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_tcc/home.dart';
import '../services/theme_service.dart';

class MeuCasas extends StatefulWidget {
  const MeuCasas({super.key});

  @override
  State<MeuCasas> createState() => _MeuCasasState();
}

class _MeuCasasState extends State<MeuCasas> {
  final TextEditingController _nomeController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ✅ ENTRAR NA CASA
  void _entrarNaCasa(QueryDocumentSnapshot casaDoc) {
    final casaData = casaDoc.data() as Map<String, dynamic>;
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => HomePage(casa: {
          'id': casaDoc.id,
          'nome': casaData['nome'] ?? 'Minha Casa',
        }),
      ),
    );
  }

  // ✅ CRIAR CASA NO FIRESTORE
  Future<void> _criarCasa() async {
    final nomeCasa = _nomeController.text.trim();
    
    if (nomeCasa.isEmpty) {
      _mostrarErro('Por favor, insira um nome para a casa');
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      _mostrarErro('Usuário não autenticado');
      return;
    }

    try {
      // ✅ ADICIONA CASA NO FIRESTORE
      await _firestore.collection('casas').add({
        'nome': nomeCasa,
        'criadoEm': FieldValue.serverTimestamp(),
        'donoId': user.uid,
        'membros': [user.uid], // Usuário atual é membro
        'administradorId': user.uid,
      });

      // ✅ ADICIONA REFERÊNCIA NO USUÁRIO TAMBÉM
      await _firestore
          .collection('usuarios')
          .doc(user.uid)
          .collection('minhasCasas')
          .add({
            'nome': nomeCasa,
            'criadoEm': FieldValue.serverTimestamp(),
          });

      Navigator.pop(context); // Fecha o dialog
      _limparCampos();
      
      _mostrarSucesso('Casa "$nomeCasa" criada com sucesso!');
      
    } catch (e) {
      print('Erro ao criar casa: $e');
      _mostrarErro('Erro ao criar casa. Tente novamente.');
    }
  }

  // ✅ EXCLUIR CASA (MODIFICADA - sem where que precisa de índice)
  Future<void> _excluirCasa(String casaId, String casaNome) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Casa'),
        content: Text('Tem certeza que deseja excluir a casa "$casaNome"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Excluir',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // 1. Exclui a casa principal
        await _firestore.collection('casas').doc(casaId).delete();
        
        // 2. Remove da lista do usuário (MODIFICADO - sem where)
        final minhasCasasSnapshot = await _firestore
            .collection('usuarios')
            .doc(user.uid)
            .collection('minhasCasas')
            .get();
        
        // Filtra localmente (não precisa de índice)
        for (var doc in minhasCasasSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['nome'] == casaNome) {
            await doc.reference.delete();
            break; // Só deve ter um com este nome
          }
        }
        
        _mostrarSucesso('Casa "$casaNome" excluída com sucesso!');
      } catch (e) {
        print('Erro ao excluir casa: $e');
        _mostrarErro('Erro ao excluir casa');
      }
    }
  }

  Widget _buildEmptyState({required Color secondaryTextColor}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.home_outlined, 
            size: 64, 
            color: secondaryTextColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhuma casa cadastrada',
            style: TextStyle(
              color: secondaryTextColor, 
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              'Toque no botão + para criar sua primeira casa',
              style: TextStyle(
                color: secondaryTextColor.withOpacity(0.7), 
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCasaItem({
    required QueryDocumentSnapshot casaDoc,
    required Color textColor,
    required Color primaryColor,
  }) {
    final casaData = casaDoc.data() as Map<String, dynamic>;
    final nomeCasa = casaData['nome'] ?? 'Sem nome';
    final criadoEm = casaData['criadoEm'] != null 
        ? (casaData['criadoEm'] as Timestamp).toDate() 
        : null;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.house,
            color: primaryColor,
            size: 24,
          ),
        ),
        title: Text(
          nomeCasa,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: textColor,
            fontSize: 16,
          ),
        ),
        subtitle: criadoEm != null
            ? Text(
                'Criada em ${_formatarData(criadoEm)}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              )
            : null,
        trailing: IconButton(
          icon: Icon(Icons.delete, color: Colors.red[300], size: 20),
          onPressed: () => _excluirCasa(casaDoc.id, nomeCasa),
          tooltip: 'Excluir casa',
        ),
        onTap: () => _entrarNaCasa(casaDoc),
      ),
    );
  }

  String _formatarData(DateTime data) {
    return '${data.day}/${data.month}/${data.year}';
  }

  // ✅ FUNÇÃO PARA ORDENAR LOCALMENTE (nova)
  List<QueryDocumentSnapshot> _ordenarCasasPorData(List<QueryDocumentSnapshot> casas) {
    casas.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;
      final aCriado = aData['criadoEm'] as Timestamp?;
      final bCriado = bData['criadoEm'] as Timestamp?;
      
      if (aCriado == null || bCriado == null) return 0;
      return bCriado.compareTo(aCriado); // Mais recente primeiro
    });
    return casas;
  }

  Widget _buildListaCasas({
    required List<QueryDocumentSnapshot> casasDocs,
    required Color textColor,
    required Color primaryColor,
  }) {
    // Ordena localmente
    final casasOrdenadas = _ordenarCasasPorData(casasDocs);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
          child: Text(
            'Minhas Casas (${casasOrdenadas.length})',
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: casasOrdenadas.length,
            itemBuilder: (context, index) {
              final casaDoc = casasOrdenadas[index];
              return _buildCasaItem(
                casaDoc: casaDoc,
                textColor: textColor,
                primaryColor: primaryColor,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Carregando suas casas...'),
        ],
      ),
    );
  }

  Widget _buildNotLoggedInState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text('Usuário não logado', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          const Text('Faça login para ver suas casas', style: TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text('Erro ao carregar casas', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          Text(error, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildBodyWithCasas({
    required BuildContext context,
    required ThemeService themeService,
    required List<QueryDocumentSnapshot> casasDocs,
  }) {
    final backgroundColor = themeService.backgroundColor;
    final textColor = themeService.textColor;
    final secondaryTextColor = themeService.isDarkMode 
        ? Colors.grey[400]! 
        : Colors.grey[600]!;
    final primaryColor = themeService.primaryColor;

    return Column(
      children: [
        Expanded(
          child: Container(
            color: backgroundColor,
            child: casasDocs.isEmpty
                ? _buildEmptyState(secondaryTextColor: secondaryTextColor)
                : _buildListaCasas(
                    casasDocs: casasDocs,
                    textColor: textColor,
                    primaryColor: primaryColor,
                  ),
          ),
        ),
        _buildFooter(),
      ],
    );
  }

  void _mostrarDialogoCriarCasa() {
    showDialog(
      context: context,
      builder: (context) {
        final themeService = Provider.of<ThemeService>(context, listen: false);
        final textColor = themeService.textColor;
        final primaryColor = themeService.primaryColor;

        return AlertDialog(
          backgroundColor: themeService.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            'Criar Nova Casa',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nomeController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: 'Nome da Casa',
                  labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: primaryColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: primaryColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                textCapitalization: TextCapitalization.words,
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _limparCampos();
              },
              child: Text(
                'Cancelar',
                style: TextStyle(
                  color: textColor.withOpacity(0.7),
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _criarCasa,
              child: const Text(
                'Criar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _mostrarSucesso(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green,
        content: Text(mensagem),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red,
        content: Text(mensagem),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _limparCampos() {
    _nomeController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        final user = _auth.currentUser;
        
        return Scaffold(
          appBar: AppBar(
            backgroundColor: themeService.primaryColor,
            title: const Text(
              'MINHAS CASAS',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            centerTitle: true,
            elevation: 0,
          ),
          body: user == null
              ? _buildNotLoggedInState()
              : StreamBuilder<QuerySnapshot>(
                  // ✅ MODIFICADO: Removido o orderBy que precisa de índice
                  stream: _firestore
                      .collection('casas')
                      .where('membros', arrayContains: user.uid)
                      // .orderBy('criadoEm', descending: true) // REMOVIDO
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _buildLoadingState();
                    }
                    
                    if (snapshot.hasError) {
                      return _buildErrorState(snapshot.error.toString());
                    }
                    
                    final casasDocs = snapshot.data?.docs ?? [];
                    
                    return _buildBodyWithCasas(
                      context: context,
                      themeService: themeService,
                      casasDocs: casasDocs,
                    );
                  },
                ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: themeService.primaryColor,
            onPressed: _mostrarDialogoCriarCasa,
            child: const Icon(Icons.add, color: Colors.white),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        );
      },
    );
  }

  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF133A67),
            const Color(0xFF1E4A7A),
          ],
        ),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            child: const CircleAvatar(
              radius: 40,
              backgroundColor: Colors.white,
              child: Icon(
                Icons.task_alt,
                size: 40,
                color: Color(0xFF133A67),
              ),
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
    );
  }

  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }
}