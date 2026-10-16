import 'package:intl/intl.dart';

final _number = NumberFormat.decimalPattern();
final _dateTime = DateFormat('dd/MM/yyyy hh:mm a');
final _date = DateFormat('dd/MM/yyyy');
final _dayMonth = DateFormat('dd/MM');
final _time = DateFormat('hh:mm a');

String fmtNumber(num value) => _number.format(value);

String fmtDateTime(DateTime? value) => value == null ? '–' : _dateTime.format(value);

String fmtDate(DateTime? value) => value == null ? '–' : _date.format(value);

String fmtDayMonth(DateTime value) => _dayMonth.format(value);

String fmtTime(DateTime? value) => value == null ? '–' : _time.format(value);

/// `1h 05m`, like the web.
String fmtDuration(int minutes) => '${minutes ~/ 60}h ${(minutes % 60).toString().padLeft(2, '0')}m';
