// models/transacao.dart
class Transacao {
  final String id;
  final String tipo; // 'entrada' ou 'saida'
  final double valor;
  final String local;
  final DateTime data;
  final String categoria;
  final String? descricao;

  Transacao({
    required this.id,
    required this.tipo,
    required this.valor,
    required this.local,
    required this.data,
    required this.categoria,
    this.descricao,
  });

  // Método para converter para Map (para Firebase)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tipo': tipo,
      'valor': valor,
      'local': local,
      'data': data.toIso8601String(),
      'categoria': categoria,
      'descricao': descricao,
    };
  }

  // Método para criar a partir de Map (do Firebase)
  factory Transacao.fromMap(Map<String, dynamic> map) {
    return Transacao(
      id: map['id'] ?? '',
      tipo: map['tipo'] ?? 'saida',
      valor: (map['valor'] ?? 0.0).toDouble(),
      local: map['local'] ?? '',
      data: DateTime.parse(map['data'] ?? DateTime.now().toIso8601String()),
      categoria: map['categoria'] ?? 'outros',
      descricao: map['descricao'],
    );
  }

  // Cópia com alterações
  Transacao copyWith({
    String? id,
    String? tipo,
    double? valor,
    String? local,
    DateTime? data,
    String? categoria,
    String? descricao,
  }) {
    return Transacao(
      id: id ?? this.id,
      tipo: tipo ?? this.tipo,
      valor: valor ?? this.valor,
      local: local ?? this.local,
      data: data ?? this.data,
      categoria: categoria ?? this.categoria,
      descricao: descricao ?? this.descricao,
    );
  }
}