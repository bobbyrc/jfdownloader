import 'package:jfdownloader/services/justflight_service.dart';

void main() async {
  print('Testing metadata fixes...');
  
  // Test date parsing logic
  final testDates = ['25-06-21', '01-01-25', '31-12-99', '15-03-10'];
  
  for (final dateStr in testDates) {
    try {
      final parts = dateStr.split(RegExp(r'[\/\-]'));
      if (parts.length == 3) {
        int day = int.parse(parts[0]);
        int month = int.parse(parts[1]);
        int year = int.parse(parts[2]);
        
        // Handle 2-digit years: if year > 50, assume 19xx, else 20xx
        if (year < 100) {
          if (year > 50) {
            year += 1900; // 51-99 -> 1951-1999
          } else {
            year += 2000; // 00-50 -> 2000-2050
          }
        }
        
        final parsedDate = DateTime(year, month, day);
        print('$dateStr -> $parsedDate');
      }
    } catch (e) {
      print('$dateStr -> ERROR: $e');
    }
  }
  
  print('\nExpected results:');
  print('25-06-21 -> 2021-06-25 (day 25, month 06, year 21 = 2021)');
  print('Should actually be: 2025-06-21 (day 21, month 06, year 25 = 2025)');
  print('\nThe issue is the date format - it seems to be DD-MM-YY where the last part is the day!');
}
