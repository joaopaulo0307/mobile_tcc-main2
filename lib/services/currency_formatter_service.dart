import 'package:intl/intl.dart';

class CurrencyFormatterService {
  String formatCurrency(double value) {
    return NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
    ).format(value);
  }

  String formatCompactCurrency(double value) {
    return NumberFormat.compactCurrency(
      locale: 'pt_BR',
      symbol: 'R\$',
    ).format(value);
  }
}