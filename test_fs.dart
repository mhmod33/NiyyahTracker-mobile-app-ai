import 'package:http/http.dart' as http;
void main() async {
  var url = Uri.parse('https://api.foursquare.com/v3/places/search?categories=12028&ll=29.1981549,31.0821005&radius=2000');
  var resp = await http.get(url, headers: {'Authorization': 'S3RGWUZM0KKKDCNDUOI1ZX2XFWIQK2VNXSPXDGGL3YROP2A1'});
  print('Status: ${resp.statusCode}');
  print('Body: ${resp.body}');
  
  var url2 = Uri.parse('https://api.foursquare.com/v2/venues/search?ll=29.1981549,31.0821005&categoryId=4bf58dd8d48988d138941735&client_id=2HEE4UX1Q3EMR4KJAR4FILQ0DTEW40STQOPJ4WMQMDWPHTWD&client_secret=TWILPFX4L35SDKJPLNNISCF5FTZTR5AWXN4DHSJ4MWMMZ2PS&v=20231010');
  var resp2 = await http.get(url2);
  print('Status v2: ${resp2.statusCode}');
}
