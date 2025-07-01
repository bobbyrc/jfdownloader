import 'dart:io';

void main() async {
  print('Testing credentials file access...');
  print('Current working directory: ${Directory.current.path}');
  
  final possiblePaths = [
    'credentials.txt',
    '../credentials.txt', 
    '../../credentials.txt',
    '/Users/bcraig/code/jfdownloader/credentials.txt',
  ];
  
  for (final path in possiblePaths) {
    final file = File(path);
    final exists = await file.exists();
    print('Path: $path -> Exists: $exists');
    
    if (exists) {
      try {
        final lines = await file.readAsLines();
        print('  Content lines: ${lines.length}');
        if (lines.isNotEmpty) {
          print('  First line (email): ${lines[0].trim()}');
        }
        if (lines.length > 1) {
          print('  Second line (password): ${lines[1].length} characters');
        }
      } catch (e) {
        print('  Error reading file: $e');
      }
    }
  }
}
