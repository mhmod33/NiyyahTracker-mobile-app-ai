import 'package:http/http.dart' as http;
import 'dart:convert';
void main() async {
  var url2 = Uri.parse('https://api.foursquare.com/v2/venues/search?ll=30.0444,31.2357&categoryId=4bf58dd8d48988d138941735&client_id=2HEE4UX1Q3EMR4KJAR4FILQ0DTEW40STQOPJ4WMQMDWPHTWD&client_secret=TWILPFX4L35SDKJPLNNISCF5FTZTR5AWXN4DHSJ4MWMMZ2PS&v=20231010&limit=5&radius=10000');
  var resp2 = await http.get(url2);
  var data = jsonDecode(resp2.body);
  var venues = data['response']['venues'] as List?;
  print('Status: ' + resp2.statusCode.toString());
  print('Found ' + (venues?.length.toString() ?? '0') + ' venues in Cairo');
  if (venues != null) {
    for (var v in venues) {
      print('- ' + v['name'].toString());
    }
  }
}
