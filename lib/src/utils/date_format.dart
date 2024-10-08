import 'package:intl/intl.dart';

String formatDate(DateTime date) {
  return DateFormat('yy/MM/dd HH:mm').format(date);
}
