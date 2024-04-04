import  'dart:convert';

import 'package:http/http.dart' as http;


class MagiskHelper {
  static const String _githubApiUrlString = "https://api.github.com/repos/topjohnwu/Magisk/releases";
  static dynamic jsonData;
  static String? rawData;

  Future<Map<String,Map<String,String>>> getMagiskReleasesInfo() async {
    Uri uri = Uri.parse(_githubApiUrlString);

    var response = await http.get(uri);

    if (response.statusCode == 200) {
      rawData = response.body;
      if (rawData != null) {
        jsonData = jsonDecode(rawData!);
      }
    }

    Map<String,Map<String,String>> ret = {};

    // Stop when Magisk v22.0
    for (var element in List?.of(jsonData)) {
      List assets = element['assets'];

      String key = element['name'];
      
      for (var asset in assets) {
        String name = asset['name'];
        if (name.startsWith('Magisk') && name.endsWith('.apk')) {
          String durl = asset['browser_download_url'];
          //int size = asset['size'];
          ret[key] = {
            'download_url': durl,
            'name': name,
            //'size': size,
          };
        }
      }

      // Do not support too old version
      if (key == 'Magisk v22.0') {
        break;
      }
    }

    return ret;
  }
}