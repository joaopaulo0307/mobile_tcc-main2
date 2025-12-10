// lib/services/finance_service.dart
import 'package:flutter/material.dart';
import 'package:mobile_tcc/models/transacao.dart';

class FinanceService extends ChangeNotifier {
  List<Transacao> _transacoes = [
    Transacao(
      id: '1',
      valor: 2500.0,
      local: 'Salário',
      data: DateTime.now().subtract(const Duration(days: 2)),
      tipo: 'entrada',
      categoria: 'renda',
    ),
  ];

  List<Transacao> get transacoes => _transacoes;

  double get saldo {
    double totalEntradas = 0;
    double totalSaidas = 0;
    
    for (var transacao in _transacoes) {
      if (transacao.tipo == 'entrada') {
        totalEntradas += transacao.valor;
      } else {
        totalSaidas += transacao.valor;
      }
    }
    
    return totalEntradas - totalSaidas;
  }

  double get renda {
    return _transacoes
        .where((t) => t.tipo == 'entrada')
        .fold(0.0, (sum, transacao) => sum + transacao.valor);
  }

  double get gastos {
    return _transacoes
        .where((t) => t.tipo == 'saida')
        .fold(0.0, (sum, transacao) => sum + transacao.valor);
  }

  void adicionarTransacao(Transacao transacao) {
    _transacoes.insert(0, transacao);
    notifyListeners();
  }

  void removerTransacao(String id) {
    _transacoes.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  Map<String, double> getValoresMensais() {
    Map<String, double> transacoesPorMes = {};
    
    for (var transacao in _transacoes) {
      String mes = _obterMesAbreviado(transacao.data);
      if (transacoesPorMes.containsKey(mes)) {
        transacoesPorMes[mes] = transacoesPorMes[mes]! + 
          (transacao.tipo == 'entrada' ? transacao.valor : -transacao.valor);
      } else {
        transacoesPorMes[mes] = transacao.tipo == 'entrada' ? transacao.valor : -transacao.valor;
      }
    }
    
    return transacoesPorMes;
  }

  String _obterMesAbreviado(DateTime data) {
    final meses = ['JAN', 'FEV', 'MAR', 'ABR', 'MAI', 'JUN', 'JUL', 'AGO', 'SET', 'OUT', 'NOV', 'DEZ'];
    return meses[data.month - 1];
  }

  List<Transacao> getTransacoesRecentes({int limite = 5}) {
    return _transacoes.take(limite).toList();
  }
}