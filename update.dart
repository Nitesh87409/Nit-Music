import 'dart:io';

void main() {
  final file = File('lib/widgets/queue_list_view.dart');
  String content = file.readAsStringSync();
  
  content = content.replaceAll(
    '''import 'package:musify/widgets/confirmation_dialog.dart';''',
    '''import 'package:musify/utilities/formatter.dart';\nimport 'package:musify/widgets/confirmation_dialog.dart';'''
  );

  content = content.replaceAll(
    '''static const double _artRadius = 10;\n\n  @override''',
    '''static const double _artRadius = 10;\n\n  String get _subtitle {\n    final artistName = song['artist']?.toString() ?? '';\n    final duration = song['duration'];\n\n    int? durationInt;\n    if (duration is int) {\n      durationInt = duration;\n    } else if (duration is String) {\n      durationInt = int.tryParse(duration);\n    }\n\n    if (durationInt != null && durationInt > 0) {\n      final formattedDuration = formatDuration(durationInt);\n      return artistName.isNotEmpty\n          ? '\\\ • \\\'\n          : formattedDuration;\n    }\n    return artistName;\n  }\n\n  @override'''
  );
  
  content = content.replaceAll(
    '''static const double _artRadius = 10;\r\n\r\n  @override''',
    '''static const double _artRadius = 10;\r\n\r\n  String get _subtitle {\n    final artistName = song['artist']?.toString() ?? '';\n    final duration = song['duration'];\n\n    int? durationInt;\n    if (duration is int) {\n      durationInt = duration;\n    } else if (duration is String) {\n      durationInt = int.tryParse(duration);\n    }\n\n    if (durationInt != null && durationInt > 0) {\n      final formattedDuration = formatDuration(durationInt);\n      return artistName.isNotEmpty\n          ? '\\\ • \\\'\n          : formattedDuration;\n    }\n    return artistName;\n  }\n\n  @override'''
  );

  content = content.replaceAll(
    '''Text(\n                        song['artist']?.toString() ?? '',''',
    '''Text(\n                        _subtitle,'''
  );
  
  content = content.replaceAll(
    '''Text(\r\n                        song['artist']?.toString() ?? '',''',
    '''Text(\r\n                        _subtitle,'''
  );

  file.writeAsStringSync(content);
  print('Done');
}
