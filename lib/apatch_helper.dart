import  'dart:convert';

import 'package:http/http.dart' as http;

class ApatchHelper {
  static const String _githubApiUrlString = "https://api.github.com/repos/bmax121/KernelPatch/releases";
  static String? rawData;
  static dynamic jsonData;

  Future<void> getAPatchReleasesInfo() async {
    Uri uri = Uri.parse(_githubApiUrlString);

    var response = await http.get(uri);

    if (response.statusCode == 200) {
      rawData = response.body;
      jsonData = jsonDecode(response.body);
    }
  }

  Future<String?> getAPatchLatestVersionTag(bool useLatest) async {
    if (rawData == null) {
      getAPatchReleasesInfo();
    }

    if (rawData != null) {
      if (useLatest) {
        return jsonData[0]['tag_name'];
      } else {
        
      }
    }
  }

}