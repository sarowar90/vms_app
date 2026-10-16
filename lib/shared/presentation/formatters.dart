import 'package:intl/intl.dart';

final _number = NumberFormat.decimalPattern();
final _dateTime = DateFormat('dd/MM/yyyy hh:mm a');
final _date = DateFormat('dd/MM/yyyy');
final _dayMonth = DateFormat('dd/MM');

String fmtNumber(num value) => _number.format(value);

String fmtDateTime(DateTime? value) => value == null ? '–' : _dateTime.format(value);

String fmtDate(DateTime? value) => value == null ? '–' : _date.format(value);

String fmtDayMonth(DateTime value) => _dayMonth.format(value);
