import 'package:http/http.dart' as http;

void main() async {
  final checkUrl = 'https://api.github.com/repos/Nitesh87409/Nit-Music/releases/latest';
  final response = await http.get(Uri.parse(checkUrl));
  print('Status code: ${response.statusCode}');
  print('Headers: ${response.headers}');
}
