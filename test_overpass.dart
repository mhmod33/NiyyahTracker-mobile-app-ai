import 'package:http/http.dart' as http;
void main() async {
  var url = Uri.parse('https://overpass-api.de/api/interpreter?data=%5Bout%3Ajson%5D%5Btimeout%3A15%5D%3B%28nwr%5B%22amenity%22%3D%22place_of_worship%22%5D%5B%22religion%22%3D%22muslim%22%5D%28around%3A2000%2C29.1981549%2C31.0821005%29%3Bnwr%5B%22amenity%22%3D%22mosque%22%5D%28around%3A2000%2C29.1981549%2C31.0821005%29%3Bnwr%5B%22building%22%3D%22mosque%22%5D%28around%3A2000%2C29.1981549%2C31.0821005%29%3B%29%3Bout%20center%3B');
  var resp = await http.get(url, headers: {'User-Agent': 'NiyyahTrackerApp/1.0'});
  print('Status: ${resp.statusCode}');
  print('Body: ${resp.body}');
}
