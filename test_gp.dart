import 'package:http/http.dart' as http;
import 'dart:convert';
void main() async {
  var apiKey = 'AIzaSyCkZrc5PDyqqkmCsVQDPcwBUoAtI_iDWJg';
  var url = Uri.parse('https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=29.1981549,31.0821005&radius=5000&type=mosque&key=\$apiKey');
  var resp = await http.get(url);
  print(resp.body);
}
