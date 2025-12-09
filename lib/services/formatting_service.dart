import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

class FormattingService {
  // FORMATAÇÃO DE DATA
  String formatDate(DateTime date, {String locale = 'pt_BR'}) {
    return DateFormat('EEE, dd MMM yyyy', locale).format(date);
    // Exemplo: "Seg, 25 Nov 2024"
  }

  // FORMATAÇÃO DE MOEDA
  String formatCurrency(double value, {String locale = 'pt_BR', String symbol = 'R\$'}) {
    return NumberFormat.currency(
      locale: locale,
      symbol: symbol,
      decimalDigits: 2,
    ).format(value);
    // Exemplo: "R$1500.50"
  }

  // PLURALIZAÇÃO
  String pluralize(String singular, String plural, int count, {String locale = 'pt_BR'}) {
    if (locale.startsWith('pt')) {
      return count == 1 ? singular : plural.replaceAll('{{count}}', count.toString());
    }
    return count == 1 ? singular : plural.replaceAll('{{count}}', count.toString());
  }
}