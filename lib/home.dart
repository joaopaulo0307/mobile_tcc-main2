import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart'; 

// Serviços
import './services/theme_service.dart';
import './services/formatting_service.dart';
import 'services/finance_service.dart';

// Telas
import './calendario/calendario.dart';
import './economic/economico.dart';
import './meu_casas.dart';
import './perfil.dart';
import './usuarios.dart';
import './config.dart';
import 'main.dart';
import './lista_compras.dart';

class HomePage extends StatefulWidget {
  final Map<String, String> casa;
  
  const HomePage({super.key, required this.casa});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FirebaseAuth _auth = FirebaseAuth.instance; 
  String _userName = "Usuário";

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  void _loadUserName() {
    final user = _auth.currentUser;
    if (user != null && user.email != null) {
      setState(() {
        _userName = user.email!.split('@')[0];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Obter o ThemeService do contexto atual
    final themeService = Provider.of<ThemeService>(context);
    
    return Scaffold(
      key: _scaffoldKey,
      appBar: _buildAppBar(context),
      drawer: _buildDrawer(context),
      body: _buildBody(context),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.menu),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Olá $_userName',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Consumer<FormattingService>(
            builder: (context, formattingService, child) {
              final currentDate = formattingService.formatDate(DateTime.now());
              return Text(
                currentDate,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
                ),
              );
            },
          ),
        ],
      ),
      actions: [
        // Removido o seletor de idioma
      ],
    );
  }

  Widget _buildDrawer(BuildContext context) {
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
                // Botão de logout
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ElevatedButton.icon(
                    onPressed: () => _confirmLogout(context),
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

  Widget _buildBody(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          _buildListaTarefas(context),
          _buildResumoFinanceiro(context),
          _buildSecaoOpcoes(context),
          _buildFooter(context),
        ],
      ),
    );
  }

  // ✅ NOVA SEÇÃO: RESUMO FINANCEIRO
  Widget _buildResumoFinanceiro(BuildContext context) {
    return Consumer<FinanceService>(
      builder: (context, financeService, child) {
        return Consumer<FormattingService>(
          builder: (context, formattingService, child) {
            return Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resumo Financeiro',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInfoFinanceira(
                        context: context,
                        label: 'Saldo',
                        value: formattingService.formatCurrency(financeService.saldo),
                        icon: Icons.account_balance_wallet,
                        color: financeService.saldo >= 0 ? Colors.green : Colors.red,
                      ),
                      _buildInfoFinanceira(
                        context: context,
                        label: 'Renda',
                        value: formattingService.formatCurrency(financeService.renda),
                        icon: Icons.arrow_upward,
                        color: Colors.green,
                      ),
                      _buildInfoFinanceira(
                        context: context,
                        label: 'Gastos',
                        value: formattingService.formatCurrency(financeService.gastos),
                        icon: Icons.arrow_downward,
                        color: Colors.red,
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoFinanceira({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildListaTarefas(BuildContext context) {
    return Expanded(
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 64,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              ),
              const SizedBox(height: 16),
              Consumer<FormattingService>(
                builder: (context, formattingService, child) {
                  final mensagemTarefas = formattingService.pluralize(
                    'uma tarefa',
                    '{{count}} tarefas',
                    0
                  );
                  
                  return Text(
                    mensagemTarefas,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Adicione tarefas para começar',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecaoOpcoes(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Acesso Rápido',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          _buildGridOpcoes(context),
        ],
      ),
    );
  }

  Widget _buildGridOpcoes(BuildContext context) {
    final opcoes = [
      {
        'icon': Icons.people,
        'label': 'Usuários',
        'onTap': () => _navigateTo(context, const Usuarios()),
      },
      {
        'icon': Icons.attach_money,
        'label': 'Econômico',
        'onTap': () => _navigateToEconomico(context),
      },
      {
        'icon': Icons.calendar_today,
        'label': 'Calendário',
        'onTap': () => _navigateTo(context, const CalendarPage()),
      },
      {
        'icon': Icons.house,
        'label': 'Minhas Casas',
        'onTap': () => _navigateToHome(context),
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.5,
      ),
      itemCount: opcoes.length,
      itemBuilder: (context, index) {
        final opcao = opcoes[index];
        return _buildOpcaoItem(
          context: context,
          icon: opcao['icon'] as IconData,
          label: opcao['label'] as String,
          onTap: opcao['onTap'] as VoidCallback,
        );
      },
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      color: Theme.of(context).primaryColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Organize suas tarefas de forma simples',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary, 
              fontSize: 14
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Consumer<FormattingService>(
            builder: (context, formattingService, child) {
              return Text(
                formattingService.formatDate(DateTime.now()),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8), 
                  fontSize: 12
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          Text(
            'Todos os direitos reservados',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7), 
              fontSize: 12
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOpcaoItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Theme.of(context).primaryColor,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ✅ MÉTODOS DE NAVEGAÇÃO E LOGOUT

  void _navigateTo(BuildContext context, Widget page) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }

  void _navigateToEconomico(BuildContext context) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Economico(casa: widget.casa),
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

  // ✅ MÉTODO DE LOGOUT

  Future<void> _logout() async {
    try {
      await _auth.signOut();
      
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()), 
        (route) => false,
      );
      
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao sair: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _confirmLogout(BuildContext context) {
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
            onPressed: () {
              Navigator.pop(context);
              _logout();
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
}