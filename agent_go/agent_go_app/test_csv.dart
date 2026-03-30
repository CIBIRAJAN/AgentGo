import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart';

void main() async {
  final input = File('../client_data_4b8d0c86-2be2-426c-8d55-d4c7d6731207.csv').openRead();
  final fields = await input
      .transform(utf8.decoder)
      .transform(const CsvDecoder())
      .toList();
  print(fields);
}
