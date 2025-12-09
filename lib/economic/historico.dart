import 'package:flutter/material.dart';
import 'package:mobile_tcc/models/transacao.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Adicione esta linha
import '../services/theme_service.dart';

// Importações das páginas (ajuste conforme sua estrutura)
import '../calendario/calendario.dart';
import '../economic/economico.dart';
import '../meu_casas.dart';
import '../perfil.dart';
import '../usuarios.dart';
import '../config.dart';
import '../main.dart';
import '../lista_compras.dart'; // Adicione esta linha

class HistoricoPage extends StatefulWidget {
  final List<Transacao> transacoes;
  
  const HistoricoPage({super.key, required this.transacoes});

  @override
  State<HistoricoPage> createState() => _HistoricoPageState();
}

class _HistoricoPageState extends State<HistoricoPage> {
  int selecionado = 7;
  final FirebaseAuth _auth = FirebaseAuth.instance; // Adicione esta linha

  // Agrupar transações por data
  Map<String, List<Transacao>> get _transacoesAgrupadas {
    Map<String, List<Transacao>> agrupadas = {};
    
    for (var transacao in widget.transacoes) {
      String dataKey = _formatarData(transacao.data);
      if (!agrupadas.containsKey(dataKey)) {
        agrupadas[dataKey] = [];
      }
      agrupadas[dataKey]!.add(transacao);
    }
    
    return agrupadas;
  }

  String _formatarData(DateTime data) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dataTransacao = DateTime(data.year, data.month, data.day);
    
    if (dataTransacao == today) return 'Hoje';
    if (dataTransacao == yesterday) return 'Ontem';
    
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}';
  }

  List<Transacao> get _transacoesFiltradas {
    final dias = selecionado;
    final dataLimite = DateTime.now().subtract(Duration(days: dias));
    
    return widget.transacoes.where((transacao) => 
      transacao.data.isAfter(dataLimite)
    ).toList();
  }

  Widget _buildPeriodoButton(String label, int dias) {
    final bool ativo = selecionado == dias;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selecionado = dias),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: ativo ? const Color(0xFF133A67) : const Color(0xFF446B9F),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildRegistro(Transacao transacao) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF446B9F),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transacao.tipo == 'entrada' ? 
                    'R\$ +${transacao.valor.toStringAsFixed(2)}' : 
                    'R\$ -${transacao.valor.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: transacao.tipo == 'entrada' ? Colors.green : Colors.red, 
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  transacao.local,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Categoria: ${_formatarCategoria(transacao.categoria)}',
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
                if (transacao.descricao != null && transacao.descricao!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Desc: ${transacao.descricao}',
                      style: const TextStyle(color: Colors.white54, fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '${transacao.data.hour.toString().padLeft(2, '0')}:${transacao.data.minute.toString().padLeft(2, '0')}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _formatarCategoria(String categoria) {
    switch (categoria.toLowerCase()) {
      case 'alimentacao': return 'Alimentação';
      case 'transporte': return 'Transporte';
      case 'lazer': return 'Lazer';
      case 'saude': return 'Saúde';
      case 'educacao': return 'Educação';
      case 'moradia': return 'Moradia';
      case 'contas': return 'Contas';
      case 'vestuario': return 'Vestuário';
      case 'outros': return 'Outros';
      default: return categoria;
    }
  }

  Widget _buildSecao(String titulo, List<Transacao> transacoes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          "$titulo:",
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        ...transacoes.map((transacao) => _buildRegistro(transacao)),
      ],
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
      MaterialPageRoute(builder: (context) => const LoginPage()), 
    );
  }

  void _navigateToEconomico(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const Economico(
        casa: {
            'id': 'default_id', 
            'nome': 'Minha Casa',
          },
      )),
    );
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
            onPressed: () async {
              Navigator.pop(context);
              Navigator.pop(context); // Fecha o drawer
              await _auth.signOut();
              // Navegar para tela de login (ajuste conforme sua estrutura)
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()), // Ajuste
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

  // 🔥 DRAWER COMPLETO (igual ao seu código)
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
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToEconomico(context);
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.shopping_cart,
                  title: 'Lista de Compras',
                  textColor: textColor,
                  onTap: () {
                    Navigator.pop(context);
                    _navigateTo(context, const ListaCompras());
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.calendar_today,
                  title: 'Calendário',
                  textColor: textColor,
                  onTap: () {
                    Navigator.pop(context);
                    _navigateTo(context, const CalendarPage());
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.people,
                  title: 'Usuários',
                  textColor: textColor,
                  onTap: () {
                    Navigator.pop(context);
                    _navigateTo(context, const Usuarios());
                  },
                ),
                Divider(color: Theme.of(context).dividerColor),
                _buildDrawerItem(
                  icon: Icons.house,
                  title: 'Minhas Casas',
                  textColor: textColor,
                  onTap: () {
                    Navigator.pop(context);
                    _navigateTo(context, const MeuCasas());
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.person,
                  title: 'Meu Perfil',
                  textColor: textColor,
                  onTap: () {
                    Navigator.pop(context);
                    _navigateTo(context, const PerfilPage());
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.settings,
                  title: 'Configurações',
                  textColor: textColor,
                  onTap: () {
                    Navigator.pop(context);
                    _navigateTo(context, const ConfigPage());
                  },
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

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final transacoesAgrupadasFiltradas = <String, List<Transacao>>{};
    
    for (var transacao in _transacoesFiltradas) {
      String dataKey = _formatarData(transacao.data);
      if (!transacoesAgrupadasFiltradas.containsKey(dataKey)) {
        transacoesAgrupadasFiltradas[dataKey] = [];
      }
      transacoesAgrupadasFiltradas[dataKey]!.add(transacao);
    }

    // Ordenar por data (mais recente primeiro)
    final entries = transacoesAgrupadasFiltradas.entries.toList()
      ..sort((a, b) {
        final transacaoA = a.value.first;
        final transacaoB = b.value.first;
        return transacaoB.data.compareTo(transacaoA.data);
      });

    // Calcular totais
    double totalEntradas = 0;
    double totalSaidas = 0;
    
    for (var transacao in _transacoesFiltradas) {
      if (transacao.tipo == 'entrada') {
        totalEntradas += transacao.valor;
      } else {
        totalSaidas += transacao.valor;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      // 🔥 ADICIONE O DRAWER COM ThemeService
      drawer: _buildDrawer(context, themeService),
      appBar: AppBar(
        backgroundColor: const Color(0xFF133A67),
        centerTitle: true,
        title: const Text("HISTÓRICO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        // 🔥 ÍCONE DO MENU
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          children: [
            // Botões de filtro de período
            Row(
              children: [
                _buildPeriodoButton("Últimos 7 dias", 7),
                const SizedBox(width: 6),
                _buildPeriodoButton("Últimos 15 dias", 15),
                const SizedBox(width: 6),
                _buildPeriodoButton("Últimos 30 dias", 30),
              ],
            ),

            const SizedBox(height: 20),

            // Card de resumo
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2D2D2D),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text(
                    'RESUMO DO PERÍODO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text(
                            'ENTRADAS',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            'R\$ ${totalEntradas.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          const Text(
                            'SAÍDAS',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            'R\$ ${totalSaidas.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          const Text(
                            'SALDO',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            'R\$ ${(totalEntradas - totalSaidas).toStringAsFixed(2)}',
                            style: TextStyle(
                              color: (totalEntradas - totalSaidas) >= 0 ? Colors.green : Colors.red,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Lista de históricos
            if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.receipt_long,
                      color: Colors.white54,
                      size: 60,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Nenhuma transação no período selecionado',
                      style: TextStyle(color: Colors.white54, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ...entries.map((entry) => _buildSecao(entry.key, entry.value)),

            const SizedBox(height: 40),

            // Rodapé
            Container(
              width: double.infinity,
              color: const Color(0xFF133A67),
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: const [
                  Text(
                    "Organize suas finanças de forma simples",
                    style: TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.facebook, color: Colors.white),
                      SizedBox(width: 16),
                      Icon(Icons.photo_camera, color: Colors.white),
                      SizedBox(width: 16),
                      Icon(Icons.email, color: Colors.white),
                      SizedBox(width: 16),
                      Icon(Icons.chat, color: Colors.white),
                    ],
                  ),
                  SizedBox(height: 10),
                  Text(
                    "© Todos os direitos reservados - 2025",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}