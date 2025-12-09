// lib/economic/economico.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:mobile_tcc/config.dart';
import 'package:mobile_tcc/home.dart';
import 'package:mobile_tcc/perfil.dart';
import 'package:mobile_tcc/usuarios.dart';
import 'package:mobile_tcc/meu_casas.dart';
import 'package:mobile_tcc/economic/historico.dart';
import 'package:mobile_tcc/services/theme_service.dart';
import 'package:mobile_tcc/models/transacao.dart';

class Economico extends StatefulWidget {
  final Map<String, String> casa;
  
  const Economico({super.key, required this.casa});

  @override
  State<Economico> createState() => _EconomicoState();
}

class _EconomicoState extends State<Economico> {
  double saldo = 0.0;
  double renda = 0.0;
  double gastos = 0.0;
  
  List<Transacao> historicoTransacoes = [
    Transacao(
      id: '1',
      valor: 2500.0,
      local: 'Salário',
      data: DateTime.now().subtract(const Duration(days: 2)),
      tipo: 'entrada',
      categoria: 'renda',
    ),
  ];

  final Map<String, double> valoresMensais = {};

  @override
  void initState() {
    super.initState();
    _atualizarValores();
    _atualizarGrafico();
  }

  void _atualizarValores() {
    double totalEntradas = 0;
    double totalSaidas = 0;
    
    for (var transacao in historicoTransacoes) {
      if (transacao.tipo == 'entrada') {
        totalEntradas += transacao.valor;
      } else {
        totalSaidas += transacao.valor;
      }
    }
    
    setState(() {
      renda = totalEntradas;
      gastos = totalSaidas;
      saldo = totalEntradas - totalSaidas;
    });
  }

  void _atualizarGrafico() {
    Map<String, double> transacoesPorMes = {};
    
    for (var transacao in historicoTransacoes) {
      String mes = _obterMesAbreviado(transacao.data);
      if (transacoesPorMes.containsKey(mes)) {
        transacoesPorMes[mes] = transacoesPorMes[mes]! + 
          (transacao.tipo == 'entrada' ? transacao.valor : -transacao.valor);
      } else {
        transacoesPorMes[mes] = transacao.tipo == 'entrada' ? transacao.valor : -transacao.valor;
      }
    }
    
    setState(() {
      valoresMensais.clear();
      valoresMensais.addAll(transacoesPorMes);
    });
  }

  String _obterMesAbreviado(DateTime data) {
    final meses = ['JAN', 'FEV', 'MAR', 'ABR', 'MAI', 'JUN', 'JUL', 'AGO', 'SET', 'OUT', 'NOV', 'DEZ'];
    return meses[data.month - 1];
  }

  Widget _buildGrafico(ThemeService themeService) {
    final meses = ['JAN', 'FEV', 'MAR', 'ABR', 'MAI', 'JUN', 'JUL', 'AGO', 'SET', 'OUT', 'NOV', 'DEZ'];
    final spots = List.generate(
      meses.length,
      (i) {
        final valor = valoresMensais[meses[i]] ?? 0.0;
        return FlSpot(i.toDouble(), valor);
      },
    );

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value >= 0 && value < meses.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        meses[value.toInt()],
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: themeService.primaryColor,
              barWidth: 3,
              belowBarData: BarAreaData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, ThemeService themeService) {
    final backgroundColor = themeService.backgroundColor;
    final textColor = themeService.textColor;
    final primaryColor = themeService.primaryColor;

    return Drawer(
      backgroundColor: backgroundColor,
      child: Column(
        children: [
          _buildDrawerHeader(themeService),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  icon: Icons.home, 
                  title: 'Home', 
                  textColor: textColor, 
                  primaryColor: primaryColor, 
                  onTap: () => _navigateToHome(context)
                ),
                _buildDrawerItem(
                  icon: Icons.history, 
                  title: 'Histórico', 
                  textColor: textColor, 
                  primaryColor: primaryColor, 
                  onTap: () => _navigateToHistorico(context)
                ),
                _buildDrawerItem(
                  icon: Icons.people, 
                  title: 'Usuários', 
                  textColor: textColor, 
                  primaryColor: primaryColor, 
                  onTap: () => _navigateToUsuarios(context)
                ),
                Divider(color: Colors.grey.withOpacity(0.3)),
                _buildDrawerItem(
                  icon: Icons.house, 
                  title: 'Minhas Casas', 
                  textColor: textColor, 
                  primaryColor: primaryColor, 
                  onTap: () => _navigateToMinhasCasas(context)
                ),
                _buildDrawerItem(
                  icon: Icons.person, 
                  title: 'Meu Perfil', 
                  textColor: textColor, 
                  primaryColor: primaryColor, 
                  onTap: () => _navigateToPerfil(context)
                ),
                _buildDrawerItem(
                  icon: Icons.settings, 
                  title: 'Configurações', 
                  textColor: textColor, 
                  primaryColor: primaryColor, 
                  onTap: () => _navigateToConfig(context)
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader(ThemeService themeService) {
    final primaryColor = themeService.primaryColor;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      color: primaryColor,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              radius: 25, 
              backgroundColor: Colors.white, 
              child: Text("TD", style: TextStyle(color: Color(0xFF133A67), fontWeight: FontWeight.bold))
            ),
            const SizedBox(height: 16),
            Text(
              widget.casa['nome'] ?? 'Minha Casa', 
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 4),
            const Text('Usuário', style: TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({ 
    required IconData icon, 
    required String title, 
    required Color textColor, 
    required Color primaryColor, 
    required VoidCallback onTap 
  }) {
    return ListTile(
      leading: Icon(icon, color: primaryColor),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w500, color: textColor)),
      onTap: onTap,
    );
  }

  void _navigateToHome(BuildContext context) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (context) => HomePage(casa: widget.casa)));
  }

  void _navigateToHistorico(BuildContext context) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (context) => HistoricoPage(transacoes: historicoTransacoes)));
  }

  void _navigateToUsuarios(BuildContext context) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (context) => const Usuarios()));
  }

  void _navigateToMinhasCasas(BuildContext context) {
    Navigator.pop(context);
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const MeuCasas()), (route) => false);
  }

  void _navigateToPerfil(BuildContext context) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (context) => const PerfilPage()));
  }

  void _navigateToConfig(BuildContext context) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (context) => const ConfigPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        final primaryColor = themeService.primaryColor;
        
        return Scaffold(
          appBar: AppBar(
            title: const Text('Econômico'),
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            actions: [
              IconButton(icon: const Icon(Icons.add), onPressed: _mostrarModalAlterarValor),
            ],
          ),
          drawer: _buildDrawer(context, themeService),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildResumoCards(),
                const SizedBox(height: 24),
                _buildGraficoSection(themeService),
                const SizedBox(height: 24),
                _buildHistoricoRecente(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildResumoCards() {
    return Row(
      children: [
        Expanded(child: _buildResumoCard(title: 'Saldo', valor: saldo, cor: saldo >= 0 ? Colors.green : Colors.red, icon: Icons.account_balance_wallet)),
        const SizedBox(width: 12),
        Expanded(child: _buildResumoCard(title: 'Receitas', valor: renda, cor: Colors.green, icon: Icons.arrow_upward)),
        const SizedBox(width: 12),
        Expanded(child: _buildResumoCard(title: 'Despesas', valor: gastos, cor: Colors.red, icon: Icons.arrow_downward)),
      ],
    );
  }

  Widget _buildResumoCard({ required String title, required double valor, required Color cor, required IconData icon }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: cor, size: 24),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text('R\$${valor.toStringAsFixed(2)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cor)),
        ]),
      ),
    );
  }

  Widget _buildGraficoSection(ThemeService themeService) {
    return Card(
      elevation: 2, 
      child: Padding(
        padding: const EdgeInsets.all(16), 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, 
          children: [
            const Text('Resumo Mensal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), 
            const SizedBox(height: 16), 
            _buildGrafico(themeService)
          ]
        )
      )
    );
  }

  Widget _buildHistoricoRecente() {
    final transacoesRecentes = historicoTransacoes.take(5).toList();
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, 
          children: [
            Row(
              children: [
                const Text('Histórico Recente', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton(
                  onPressed: () => _navigateToHistorico(context), 
                  child: const Text('Ver tudo')
                ),
              ]
            ),
            const SizedBox(height: 12),
            ...transacoesRecentes.map((transacao) => _buildItemHistorico(transacao)),
          ]
        ),
      ),
    );
  }

  Widget _buildItemHistorico(Transacao transacao) {
    return ListTile(
      leading: Icon(
        transacao.tipo == 'entrada' ? Icons.arrow_upward : Icons.arrow_downward, 
        color: transacao.tipo == 'entrada' ? Colors.green : Colors.red
      ),
      title: Text(transacao.local),
      subtitle: Text('${transacao.data.day}/${transacao.data.month}/${transacao.data.year}'),
      trailing: Text(
        'R\$${transacao.valor.toStringAsFixed(2)}', 
        style: TextStyle(
          color: transacao.tipo == 'entrada' ? Colors.green : Colors.red, 
          fontWeight: FontWeight.bold
        )
      ),
    );
  }

  void _mostrarModalAlterarValor() {
    final TextEditingController valorController = TextEditingController();
    final TextEditingController localController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        String acao = 'entrada';
        String categoria = 'outros';

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: Theme.of(context).cardColor,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min, 
                    children: [
                      Text(
                        'Adicionar Transação', 
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface, 
                          fontSize: 20, 
                          fontWeight: FontWeight.bold
                        )
                      ),
                      const SizedBox(height: 12),

                      Align(
                        alignment: Alignment.centerLeft, 
                        child: Text(
                          'Valor (R\$):', 
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), 
                            fontWeight: FontWeight.bold
                          )
                        )
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: valorController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          hintText: '0,00', 
                          filled: true, 
                          fillColor: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.04), 
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8), 
                            borderSide: BorderSide.none
                          )
                        ),
                      ),
                      const SizedBox(height: 12),

                      Align(
                        alignment: Alignment.centerLeft, 
                        child: Text(
                          'Descrição:', 
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), 
                            fontWeight: FontWeight.bold
                          )
                        )
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: localController, 
                        decoration: InputDecoration(
                          hintText: 'Informe a descrição', 
                          filled: true, 
                          fillColor: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.04), 
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8), 
                            borderSide: BorderSide.none
                          )
                        )
                      ),
                      const SizedBox(height: 12),

                      Align(
                        alignment: Alignment.centerLeft, 
                        child: Text(
                          'Tipo:', 
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), 
                            fontWeight: FontWeight.bold
                          )
                        )
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.04), 
                          borderRadius: BorderRadius.circular(8)
                        ),
                        child: DropdownButton<String>(
                          value: acao,
                          dropdownColor: Theme.of(context).cardColor,
                          underline: const SizedBox(),
                          isExpanded: true,
                          items: [
                            DropdownMenuItem(
                              value: 'entrada', 
                              child: Text(
                                'Entrada (Renda)', 
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface)
                              )
                            ),
                            DropdownMenuItem(
                              value: 'saida', 
                              child: Text(
                                'Saída (Gasto)', 
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface)
                              )
                            ),
                          ],
                          onChanged: (v) => setModalState(() => acao = v ?? 'entrada'),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Align(
                        alignment: Alignment.centerLeft, 
                        child: Text(
                          'Categoria:', 
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), 
                            fontWeight: FontWeight.bold
                          )
                        )
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.04), 
                          borderRadius: BorderRadius.circular(8)
                        ),
                        child: DropdownButton<String>(
                          value: categoria,
                          dropdownColor: Theme.of(context).cardColor,
                          underline: const SizedBox(),
                          isExpanded: true,
                          items: [
                            DropdownMenuItem(
                              value: 'alimentacao', 
                              child: Text(
                                'Alimentação', 
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface)
                              )
                            ),
                            DropdownMenuItem(
                              value: 'transporte', 
                              child: Text(
                                'Transporte', 
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface)
                              )
                            ),
                            DropdownMenuItem(
                              value: 'lazer', 
                              child: Text(
                                'Lazer', 
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface)
                              )
                            ),
                            DropdownMenuItem(
                              value: 'saude', 
                              child: Text(
                                'Saúde', 
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface)
                              )
                            ),
                            DropdownMenuItem(
                              value: 'educacao', 
                              child: Text(
                                'Educação', 
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface)
                              )
                            ),
                            DropdownMenuItem(
                              value: 'outros', 
                              child: Text(
                                'Outros', 
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface)
                              )
                            ),
                          ],
                          onChanged: (v) => setModalState(() => categoria = v ?? 'outros'),
                        ),
                      ),

                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red, 
                                padding: const EdgeInsets.symmetric(vertical: 12), 
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                              ),
                              child: const Text('Cancelar', style: TextStyle(color: Colors.white)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                final raw = valorController.text.replaceAll(',', '.');
                                final valor = double.tryParse(raw) ?? 0.0;
                                final descricao = localController.text.trim();

                                if (valor > 0 && descricao.isNotEmpty) {
                                  final novaTransacao = Transacao(
                                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                                    valor: valor,
                                    local: descricao,
                                    data: DateTime.now(),
                                    tipo: acao,
                                    categoria: categoria,
                                  );

                                  setState(() {
                                    historicoTransacoes.insert(0, novaTransacao);
                                    _atualizarValores();
                                    _atualizarGrafico();
                                  });

                                  Navigator.pop(context);
                                  _mostrarModalConfirmacao(context);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Preencha todos os campos corretamente'), 
                                      backgroundColor: Colors.red
                                    )
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green, 
                                padding: const EdgeInsets.symmetric(vertical: 12), 
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                              ),
                              child: const Text('Confirmar', style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ]
                  ),
                ),
              ),
            );
          }
        );
      },
    );
  }

  void _mostrarModalConfirmacao(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Consumer<ThemeService>(
          builder: (context, themeService, child) {
            final cardColor = themeService.cardColor;
            final textColor = themeService.textColor;
            final primaryColor = themeService.primaryColor;
            
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: cardColor,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min, 
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 60),
                    const SizedBox(height: 12),
                    Text(
                      'Transação adicionada!', 
                      style: TextStyle(
                        color: textColor, 
                        fontSize: 18, 
                        fontWeight: FontWeight.bold
                      )
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context), 
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor, 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                      ), 
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10), 
                        child: Text('OK', style: TextStyle(color: Colors.white))
                      )
                    ),
                  ]
                ),
              ),
            );
          },
        );
      },
    );
  }
}