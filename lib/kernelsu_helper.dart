import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:root_patcher/patch_helper.dart';

class KernelSUHelper {
  static const String _githubApiUrlString =
      "https://api.github.com/repos/tiann/KernelSU/releases/latest";
  static String? rawData;
  static dynamic jsonData;

  static Future<void> getKernelSUReleasesInfo() async {
    Uri uri = Uri.parse(_githubApiUrlString);

    var response = await http.get(uri);

    if (response.statusCode == 200) {
      rawData = response.body;
      jsonData = jsonDecode(response.body);
    }
  }

  static reset() {
    rawData = null;
    jsonData = null;
  }

  static Future<Map<String, String>> getKernelSUKPMInfo() async {
    if (rawData == null) {
      await getKernelSUReleasesInfo();
    }

    Map<String, String> ret = {};

    List? assets = jsonData["assets"];

    assets?.forEach((element) {
      String name = element['name'];
      String durl = element['browser_download_url'];

      if (name.endsWith("kernelsu.ko")) {
        ret[name] = durl;
      }
    });

    return ret;
  }

  static Future<List<String>> getKernelSUKPMList() async {
    var info = await getKernelSUKPMInfo();

    return info.keys.toList();
  }

  /// regex binary kernel banner
  ///
  /// [file] Input kernel file
  ///
  /// if matched, will return like "android13-5.15"
  /// if not, will return null
  static Future<String?> getKernelVersion(File file) async {
    await Magiskboot.ensureMagiskbootBinary((String? a, double? b) {
      log("$a");
    });
    var tmpDir = await Directory.systemTemp.createTemp();

    magiskboot(List<String> args) => Magiskboot.doMagiskbootCommand(args,
        workdir: tmpDir.path, env: {'MAGISKBOOT_WINSUP_NOCASE': '1'});
    //var linuxBanner = "Linux version ";
    var regExp = RegExp(r"version ([0-9]+\.[0-9]+)\.[0-9]+-([a-zA-Z0-9]+)");

    await file.copy(path.join(tmpDir.path, 'boot.img'));
    magiskboot(['unpack', 'boot.img']);
    var kernel = File(path.join(tmpDir.path, 'kernel'));

    if (await kernel.exists()) {
      var data = String.fromCharCodes(await file.readAsBytes());

      var matches = regExp.allMatches(data);

      if (matches.isNotEmpty) {
        return "${matches.first.group(2)}-${matches.first.group(1)}";
      }
    }

    await tmpDir.delete();
    return null;
  }
}
