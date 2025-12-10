import 'package:flutter/material.dart';
import 'package:mobile_tcc/home.dart';
import 'package:mobile_tcc/main.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/theme_service.dart';

// Adicione as importações das suas páginas
import '../economic/economico.dart';
import '../meu_casas.dart';
import '../perfil.dart';
import '../usuarios.dart';
import '../config.dart';
import '../calendario/calendario.dart';

class ListaCompras extends StatefulWidget {
  const ListaCompras({super.key});

  @override
  State<ListaCompras> createState() => _ListaComprasState();
}

class _ListaComprasState extends State<ListaCompras> {
  List<Map<String, dynamic>> produtos = [];
  final FirebaseAuth _auth = FirebaseAuth.instance; // Adicione esta linha
  
  final TextEditingController produtoController = TextEditingController();
  final TextEditingController responsavelController = TextEditingController();

  void adicionarProduto(String produto, String responsavel) {
    setState(() {
      produtos.add({
        'produto': produto,
        'responsavel': responsavel,
        'feito': false,
      });
    });
  }

  void removerProduto(int index) {
    setState(() {
      produtos.removeAt(index);
    });
  }

  void marcarComoFeito(int index) {
    setState(() {
      produtos[index]['feito'] = !produtos[index]['feito'];
    });
  }

  void abrirModalAdicionar() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0D47A1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Center(
            child: Text(
              'Listamento',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: produtoController,
                decoration: const InputDecoration(
                  labelText: 'Produto:',
                  labelStyle: TextStyle(color: Colors.white),
                  filled: true,
                  fillColor: Colors.white24,
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: responsavelController,
                decoration: const InputDecoration(
                  labelText: 'Responsável:',
                  labelStyle: TextStyle(color: Colors.white),
                  filled: true,
                  fillColor: Colors.white24,
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (produtoController.text.isNotEmpty &&
                      responsavelController.text.isNotEmpty) {
                    adicionarProduto(
                        produtoController.text, responsavelController.text);
                    produtoController.clear();
                    responsavelController.clear();
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0D47A1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('CRIAR'),
              )
            ],
          ),
        );
      },
    );
  }

  // 🔥 ADICIONE AS FUNÇÕES DE NAVEGAÇÃO
  void _navigateTo(BuildContext context, Widget page) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }

  void _navigateToHome(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()), // Ajuste conforme sua MainPage
    );
  }

  void _navigateToEconomico(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => Economico(
          casa: {
            'id': 'default_id',
            'nome': 'Minha Casa',
          },
        ),
      ),
    );
  }

  void _logout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair'),
        content: const Text('Tem certeza que deseja sair?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              Navigator.pop(context); // Fecha o drawer
              await _auth.signOut();
              // Navegar para tela de login (ajuste conforme sua estrutura)
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()), // Ajuste conforme sua LoginPage
                (route) => false,
              );
            },
            child: const Text(
              'Sair',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 ADICIONE O DRAWER (igual ao seu código)
  Widget _buildDrawer(BuildContext context, ThemeService themeService) {
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final user = _auth.currentUser;

    return Drawer(
      backgroundColor: backgroundColor,
      child: Column(
        children: [
          // Header do Drawer
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
                _buildDrawerItem(
                  icon: Icons.attach_money,
                  title: 'Econômico',
                  textColor: textColor,
                  onTap: () => _navigateToEconomico(context),
                ),
                _buildDrawerItem(
                  icon: Icons.shopping_cart,
                  title: 'Lista de Compras',
                  textColor: textColor,
                  onTap: () {
                    Navigator.pop(context);
                    // Já está na página de Lista de Compras
                  },
                  isSelected: true,
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
                  onTap: () => _navigateTo(context, const Usuarios()),
                ),
                _buildDrawerItem(
                  icon: Icons.shopping_cart,
                  title: 'Lista de compras',
                  textColor: textColor,
                  onTap: () => _navigateTo(context, const ListaCompras()),
                ),
                Divider(color: Theme.of(context).dividerColor),
                _buildDrawerItem(
                  icon: Icons.house,
                  title: 'Minhas Casas',
                  textColor: textColor,
                  onTap: () => _navigateToHome(context),
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
                // Botão de logout igual ao usuários
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

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return Scaffold(
          backgroundColor: const Color(0xFF2D2D2D),
          // 🔥 ADICIONE O DRAWER AQUI
          drawer: _buildDrawer(context, themeService),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0D47A1),
            title: const Text(
              'Lista de Compras',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
            // 🔥 ÍCONE DO MENU
            leading: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          ),
          body: Column(
            children: [
              const SizedBox(height: 20),
              const Text(
                'Produtos:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: produtos.isEmpty
                    ? const Center(
                        child: Text(
                          'Não há nenhum produto listado no momento',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        itemCount: produtos.length,
                        itemBuilder: (context, index) {
                          final item = produtos[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 8),
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D47A1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ListTile(
                                leading: GestureDetector(
                                  onTap: () => marcarComoFeito(index),
                                  child: CircleAvatar(
                                    backgroundColor: item['feito']
                                        ? Colors.green
                                        : Colors.white,
                                    radius: 12,
                                    child: item['feito']
                                        ? const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 16,
                                          )
                                        : null,
                                  ),
                                ),
                                title: Text(
                                  item['produto'],
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    decoration: item['feito']
                                        ? TextDecoration.lineThrough
                                        : TextDecoration.none,
                                  ),
                                ),
                                subtitle: Text(
                                  "Responsável: ${item['responsavel']}",
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.white),
                                  onPressed: () => removerProduto(index),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 20),
              FloatingActionButton(
                onPressed: abrirModalAdicionar,
                backgroundColor: const Color(0xFF0D47A1),
                child: const Icon(Icons.add, color: Colors.white),
              ),
              const SizedBox(height: 20),
              Container(
                color: const Color(0xFF0D47A1),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: const [
                    SizedBox(height: 5),
                    Text(
                      'Organize suas tarefas de forma simples',
                      style: TextStyle(color: Colors.white),
                    ),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.facebook, color: Colors.white),
                        SizedBox(width: 10),
                        Icon(Icons.camera_alt, color: Colors.white),
                        SizedBox(width: 10),
                        Icon(FontAwesomeIcons.whatsapp, color: Colors.white),
                      ],
                    ),
                    SizedBox(height: 10),
                    Text(
                      '© Todos os direitos reservados - 2025',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
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
}