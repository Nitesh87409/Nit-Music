import 'dart:io';

void stripBom(String path) {
  final file = File(path);
  var bytes = file.readAsBytesSync();
  if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
    print('Stripping BOM from ' + path);
    file.writeAsBytesSync(bytes.sublist(3));
  }
}

void main() {
  stripBom('lib/widgets/queue_list_view.dart');
  stripBom('lib/services/common_services.dart');
}
