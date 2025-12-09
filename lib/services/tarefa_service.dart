import 'package:flutter/material.dart';

class Tarefa {
  final String id;
  final String titulo;
  final String descricao;
  final DateTime data;
  final Color cor;
  final bool concluida;
  final String casaId;

  Tarefa({
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.data,
    required this.cor,
    this.concluida = false,
    required this.casaId,
  });

  // Adicione este método factory para criar uma cópia com campos atualizados
  Tarefa copyWith({
    String? id,
    String? titulo,
    String? descricao,
    DateTime? data,
    Color? cor,
    bool? concluida,
    String? casaId,
  }) {
    return Tarefa(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      descricao: descricao ?? this.descricao,
      data: data ?? this.data,
      cor: cor ?? this.cor,
      concluida: concluida ?? this.concluida,
      casaId: casaId ?? this.casaId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'titulo': titulo,
      'descricao': descricao,
      'data': data.millisecondsSinceEpoch,
      'cor': cor.value,
      'concluida': concluida,
      'casaId': casaId,
    };
  }

  factory Tarefa.fromMap(Map<String, dynamic> map) {
    return Tarefa(
      id: map['id'],
      titulo: map['titulo'],
      descricao: map['descricao'],
      data: DateTime.fromMillisecondsSinceEpoch(map['data']),
      cor: Color(map['cor']),
      concluida: map['concluida'],
      casaId: map['casaId'],
    );
  }
}

class TarefaService extends ChangeNotifier {
  final List<Tarefa> _tarefas = [];

  List<Tarefa> get tarefas => _tarefas;

  List<Tarefa> getTarefasPorCasa(String casaId) {
    return _tarefas.where((tarefa) => tarefa.casaId == casaId).toList();
  }

  List<Tarefa> getTarefasPendentesPorCasa(String casaId) {
    return _tarefas
        .where((tarefa) => tarefa.casaId == casaId && !tarefa.concluida)
        .toList();
  }

  List<Tarefa> getTarefasPorData(DateTime data, String casaId) {
    return _tarefas.where((tarefa) {
      return tarefa.casaId == casaId &&
          tarefa.data.year == data.year &&
          tarefa.data.month == data.month &&
          tarefa.data.day == data.day &&
          !tarefa.concluida;
    }).toList();
  }

  void adicionarTarefa(Tarefa tarefa) {
    _tarefas.add(tarefa);
    notifyListeners();
  }

  void removerTarefa(String id) {
    _tarefas.removeWhere((tarefa) => tarefa.id == id);
    notifyListeners();
  }

  // MÉTODO CORRIGIDO: toggleConcluida (inverte o estado)
  void toggleConcluida(String id) {
    final index = _tarefas.indexWhere((tarefa) => tarefa.id == id);
    if (index != -1) {
      final tarefa = _tarefas[index];
      _tarefas[index] = tarefa.copyWith(
        concluida: !tarefa.concluida,
      );
      notifyListeners();
    }
  }

  // NOVO MÉTODO: atualizarTarefa
  void atualizarTarefa(Tarefa tarefaAtualizada) {
    final index = _tarefas.indexWhere((tarefa) => tarefa.id == tarefaAtualizada.id);
    if (index != -1) {
      _tarefas[index] = tarefaAtualizada;
      notifyListeners();
    }
  }

  // Método existente (mantenha)
  void marcarComoConcluida(String id) {
    final index = _tarefas.indexWhere((tarefa) => tarefa.id == id);
    if (index != -1) {
      final tarefa = _tarefas[index];
      _tarefas[index] = tarefa.copyWith(concluida: true);
      notifyListeners();
    }
  }
}