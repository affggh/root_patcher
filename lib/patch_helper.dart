import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:system_info2/system_info2.dart';

final dio = Dio();

/// Function get current CPU architecture
String getCPUArchitecture() {
  // return x86_64 on window AMD64 arch
  // only support window linux macos
  // maybe return 'unknow'
  return SysInfo.cores[0].architecture.toString().toLowerCase();
}

Future<bool> downloadFile(
    String url, String saveto, void Function(double?) setProgressValue) async {
  var ret = false;
  try {
    var response = await dio.download(
      url,
      saveto,
      onReceiveProgress: (count, total) => setProgressValue(count / total),
    );
    if (response.statusCode == 200) {
      ret = true;
    }
  } catch (e) {
    log(e.toString());
    setProgressValue(null);
    ret = false;
  }

  // reset
  setProgressValue(null);

  return ret;
}

/// return value from file key supplied
String? grepProp(String key, File input) {
  var data = input.readAsLinesSync();
  String? value;
  for (var line in data) {
    if (line.contains('=') && !line.contains('#')) {
      value = line.split('=')[1];
    }
  }
  return value;
}

class Magiskboot {
  static String? execPath;

  /// If available, will get platform fit magiskboot download url
  static Future<String?> getPlatformFitMagiskboot() async {
    String? ret;
    if (Platform.isAndroid || Platform.isLinux) {
      // TODO: get ndk static build magiskboot from magisk apk install package
      // Impl here...
    } else if (Platform.isWindows || Platform.isMacOS) {
      String fetchGithubApiUrl =
          "https://api.github.com/repos/ookiineko/magiskboot_build/releases/latest";

      var response = await http.get(Uri.parse(fetchGithubApiUrl));
      if (response.statusCode == 200) {
        List? jsonData = jsonDecode(response.body)['assets'];

        jsonData?.forEach((element) {
          String? name = element['name'];

          if (name != null) {
            if (name.contains(Platform.operatingSystem) &&
                name.contains(getCPUArchitecture())) {
              ret = element['browser_download_url'];
            }
          }
        });
        return ret;
      }
    }
    // Seems there is no support for you platform
    // This is really sad 😟
    return null;
  }

  static Future<bool> ensureMagiskbootBinary(
      void Function(String?, double?) setProgressInfo) async {
    bool ret = false;

    var binaryDir =
        path.join(File(Platform.resolvedExecutable).parent.path, "bin");
    var magiskBin = path.join(
        binaryDir, Platform.isWindows ? "magiskboot.exe" : "magiskboot");

    if (!File(magiskBin).existsSync()) {
      var durl = await getPlatformFitMagiskboot();
      if (durl == null) {
        setProgressInfo("Could not fetch", null);
        return ret;
      }

      var downloadFileName = Uri.parse(durl).pathSegments.last;

      log("Get magisk download url: $durl");
      void setProgressValue(double? value) =>
          setProgressInfo("Fetching magiskboot...", value);
      var status = await downloadFile(
          durl, path.join(binaryDir, downloadFileName), setProgressValue);
      if (!status) {
        setProgressInfo("Failed download magiskboot", null);
        return false;
      }

      var archive = ZipDecoder().decodeBytes(
          File(path.join(binaryDir, downloadFileName)).readAsBytesSync());

      for (final file in archive) {
        if (file.name.contains(
                Platform.isWindows ? "magiskboot.exe" : "magiskboot") &&
            file.isFile) {
          final List<int> content = file.content;
          File(magiskBin)
            ..createSync(recursive: true)
            ..writeAsBytesSync(content);
        }
      }
    }
    execPath = magiskBin;

    return ret;
  }

  /// return exit code
  static ProcessResult doMagiskbootCommand(
    List<String> args, {
    String? workdir,
    Map<String, String>? env,
  }) {
    if (execPath == null) {
      throw Exception("Please ensureMagiskbootBinary first");
    }

    var result = Process.runSync(
      execPath!,
      args,
      workingDirectory: workdir,
      environment: env,
    );

    log("run magiskboot command: $args");
    log("stdout: ${result.stdout}");
    log("stderr: ${result.stderr}");

    return result;
  }
}

class MagiskPatcher {
  MagiskPatcher(this.bootimage,
      {this.fetchFromOnline = false,
      this.localApk,
      this.downloadUrl,
      this.arch,
      this.keepVerity = false,
      this.keepForceEncrypt = false,
      this.patchVbmetaFlag = false,
      this.patchRecovery = false,
      this.legacySAR = false});

  String? bootimage;

  bool fetchFromOnline;
  String? arch;
  String? localApk;
  String? downloadUrl;

  bool keepVerity;
  bool keepForceEncrypt;
  bool patchVbmetaFlag;
  bool patchRecovery;
  bool legacySAR;

  Future<void> patch(
    void Function(String? pstring, double? pvalue) changeProgressInfo,
  ) async {
    await Magiskboot.ensureMagiskbootBinary(changeProgressInfo);
    if (Magiskboot.execPath == null) {
      changeProgressInfo("Magiskboot binary path not set!", null);
      return;
    }

    if (bootimage == null) {
      changeProgressInfo("Boot image is invalid", null);
      return;
    }

    if (arch == null) {
      changeProgressInfo("Arch not set!", null);
      return;
    }

    changeProgressInfo("Prepare needed files...", null);
    void changeProgressValue(double? value) =>
        changeProgressInfo("Download magisk apk...", value);

    var workdir = await Directory.systemTemp.createTemp();

    log("Copy needed files...");
    log("Created temp directory at: $workdir");
    // get magisk app package
    var magiskApk = path.join(workdir.path, "app.apk");
    if (!fetchFromOnline) {
      File(localApk!).copySync(magiskApk);
    } else {
      await downloadFile(downloadUrl!, magiskApk, changeProgressValue);
    }

    magiskboot(List<String> args) =>
        Magiskboot.doMagiskbootCommand(args, workdir: workdir.path, env: {
          'KEEPVERITY': keepVerity.toString(),
          'KEEPFORCEENCRYPT': keepForceEncrypt.toString(),
          'PATCHVBMETAFLAG': patchVbmetaFlag.toString(),
          // No case sensitive act, ignore casesensitive on windows build
          'MAGISKBOOT_WINSUP_NOCASE': '1',
        });

    var magiskArchive = File(magiskApk);
    if (!magiskArchive.existsSync()) {
      changeProgressInfo('Could not fetch magisk archive', null);
      return;
    }

    var archive = ZipDecoder().decodeBytes(magiskArchive.readAsBytesSync());

    var archValue = <String, String>{
          'arm64': 'arm64-v8a',
          'arm32': 'armeabi-v7a',
          // x86 and x86_64 is same, no need to replace
        }[arch] ??
        arch!;

    String strimPrefixAndSuffix(String name) {
      if (name.startsWith('lib') && name.endsWith('.so')) {
        name = name.substring(3);
        name = name.substring(0, name.length - 3);
      }
      return name;
    }

    int? magiskVersionCode;
    for (var info in archive) {
      if (info.name.contains('assets/util_functions.sh')) {
        List<int> data = info.content;
        var dataString = String.fromCharCodes(data);
        for (var line in dataString.split('\n')) {
          if (line.startsWith('MAGISK_VER_CODE')) {
            magiskVersionCode = int.parse(line.split('=')[1]);
          }
        }
      }

      if (info.name.contains("$archValue/libmagisk64.so") ||
          info.name.contains("$archValue/libmagisk32.so") ||
          info.name.contains("$archValue/libmagiskinit.so") ||
          info.name.contains("assets/stub.apk")) {
        List<int> data = info.content;
        var name = path.basename(info.name);

        name = strimPrefixAndSuffix(name);
        log("Extracting... [$name]");

        File(path.join(workdir.path, name))
          ..createSync(recursive: true)
          ..writeAsBytesSync(data);
      }
      // copy libmagisk32.so also
      if (archValue == 'arm64-v8a') {
        if (info.name.contains('armeabi-v7a/libmagisk32.so')) {
          List<int> data = info.content;
          var name = path.basename(info.name);
          name = strimPrefixAndSuffix(name);
          log("Extracting... [$name]");
          File(path.join(workdir.path, name))
            ..createSync(recursive: true)
            ..writeAsBytesSync(data);
        }
      }

      if (archValue == 'x86_64') {
        if (info.name.contains('x86/libmagisk32.so')) {
          List<int> data = info.content;
          var name = path.basename(info.name);
          name = strimPrefixAndSuffix(name);
          log("Extracting... [$name]");
          File(path.join(workdir.path, name))
            ..createSync(recursive: true)
            ..writeAsBytesSync(data);
        }
      }
    }

    if (magiskVersionCode == null) {
      changeProgressInfo('Cannot find magisk version code', null);
      return;
    }
    log("Find magisk version code is: $magiskVersionCode");

    File(bootimage!).copySync(path.join(workdir.path, 'boot.img'));

    // boot patch part
    changeProgressInfo('- Unpack boot image', null);
    var result = magiskboot(
      ['unpack', 'boot.img'],
    );

    switch (result.exitCode) {
      case 0:
        break;
      case 1:
        changeProgressInfo('! Unsupported/Unknown image format', null);
        return;
      case 2:
        changeProgressInfo('- ChromeOS boot image not support', null);
        return;
      default:
        changeProgressInfo('! Unable to unpack boot image', null);
        return;
    }

    // Test patch status and do restore
    changeProgressInfo('- Checking ramdisk status', null);
    int status;
    String skip_backup = '';
    if (File(path.join(workdir.path, 'ramdisk.cpio')).existsSync()) {
      var result = magiskboot(
        ['cpio', 'ramdisk.cpio', 'test'],
      );
      status = result.exitCode;
    } else {
      status = 0;
      skip_backup = '#';
    }

    String? sha1;
    switch (status) {
      case 0: // Stock boot
        changeProgressInfo('- Stock boot image detected', null);
        var result = magiskboot(
          ['sha1', 'boot.img'],
        );
        sha1 = result.stdout.toString().trim();
        // you are patch on desktop dude, only need to backup ramdisk.cpio.orig
        File(path.join(workdir.path, 'ramdisk.cpio'))
            .copySync(path.join(workdir.path, 'ramdisk.cpio.orig'));
        break;
      case 1:
        changeProgressInfo('- Magisk patched boot image detected', null);
        magiskboot(
          [
            'cpio',
            'ramdisk.cpio',
            'extract .backup/.magisk config.orig',
            'restore'
          ],
        );
        //File(path.join(workdir.path, 'ramdisk.cpio'))
        //    .copySync(path.join(workdir.path, 'ramdisk.cpio.orig'));
        break;
      case 2:
        changeProgressInfo('! Boot image unsupport', null);
        break;
    }

    var configOrig = File(path.join(workdir.path, 'config.orig'));
    if (configOrig.existsSync()) {
      if (Platform.isLinux || Platform.isMacOS) {
        // Ensure access on linux
        Process.runSync(
            'chmod', ['0644', path.join(workdir.path, 'config.orig')]);
      }
      sha1 = grepProp('SHA1', configOrig);
      // PREINITDEVICE is not support on desktop environment
      configOrig.deleteSync();
    }

    changeProgressInfo('- Patching ramdisk', null);
    String skip_32 = '#';
    String skip_64 = '#';
    if (magiskVersionCode >= 27000) {
      File(path.join(workdir.path, 'magisk32'))
        ..copySync(path.join(workdir.path, 'magisk'))
        ..deleteSync();
      magiskboot(['compress=xz', 'magisk', 'magisk.xz']);
    } else {
      if (File(path.join(workdir.path, 'magisk32')).existsSync()) {
        magiskboot(['compress=xz', 'magisk32', 'magisk32.xz']);
        skip_32 = '';
      }
      if (File(path.join(workdir.path, 'magisk64')).existsSync()) {
        magiskboot(['compress=xz', 'magisk64', 'magisk64.xz']);
        skip_64 = '';
      }
    }
    String skip_stub = '#';
    if (File(path.join(workdir.path, 'stub.apk')).existsSync()) {
      magiskboot(['compress=xz', 'stub.apk', 'stub.xz']);
      skip_stub = '';
    }

    var configFile = File(path.join(workdir.path, 'config'));
    configFile
      ..createSync(recursive: true)
      ..writeAsStringSync("KEEPVERITY=${keepVerity.toString()}\n",
          mode: FileMode.append)
      ..writeAsStringSync("KEEPFORCEENCRYPT=${keepForceEncrypt.toString()}\n",
          mode: FileMode.append)
      ..writeAsStringSync("RECOVERYMODE=${patchRecovery.toString()}\n",
          mode: FileMode.append);

    if (sha1 != null) {
      configFile.writeAsString("SHA1=$sha1", mode: FileMode.append);
    }

    result = magiskboot([
          'cpio',
          'ramdisk.cpio',
          'add 0750 init magiskinit',
          'mkdir 0750 overlay.d',
          'mkdir 0750 overlay.d/sbin',
        ] +
        // If version below 27000
        (magiskVersionCode < 27000
            ? [
                '$skip_32 add 0644 overlay.d/sbin/magisk32.xz magisk32.xz',
                '$skip_64 add 0644 overlay.d/sbin/magisk64.xz magisk64.xz',
              ]
            : ['add 0644 overlay.d/sbin/magisk.xz magisk.xz']) +
        [
          // Since magisk 26000
          '$skip_stub add 0644 overlay.d/sbin/stub.xz stub.xz',
          'patch',
          '$skip_backup backup ramdisk.cpio.orig',
          'mkdir 000 .backup',
          'add 000 .backup/.magisk config'
        ]);

    if (result.exitCode != 0) {
      changeProgressInfo('! Unable to patch ramdisk', null);
      return;
    }

    for (var l in [
      'ramdisk.cpio.orig',
      'config',
      'magisk.xz',
      'magisk32.xz',
      'magisk64.xz',
      'stub.xz'
    ]) {
      var f = File(path.join(workdir.path, l));
      if (f.existsSync()) {
        f.deleteSync();
      }
    }

    for (var dt in ['dtb', 'kernel_dtb', 'extra']) {
      var f = File(path.join(workdir.path, dt));
      if (f.existsSync()) {
        var result = magiskboot(['dtb', dt, 'test']);
        if (result.exitCode != 0) {
          changeProgressInfo(
              '! Boot image $dt was patched by old (unsupported) Magisk', null);
          return;
        }
        result = magiskboot(['dtb', dt, 'patch']);
        if (result.exitCode == 0) {
          changeProgressInfo('- Patch fstab in boot image $dt', null);
        }
      }
    }

    var kernel = File(path.join(workdir.path, 'kernel'));
    if (kernel.existsSync()) {
      var patchedKernel = false;
      var result = magiskboot([
        'hexpatch',
        'kernel',
        '49010054011440B93FA00F71E9000054010840B93FA00F7189000054001840B91FA00F7188010054',
        'A1020054011440B93FA00F7140020054010840B93FA00F71E0010054001840B91FA00F7181010054'
      ]);
      if (result.exitCode == 0) {
        patchedKernel = true;
      }
      result = magiskboot(['hexpatch', 'kernel', '821B8012', 'E2FF8F12']);
      if (result.exitCode == 0) {
        patchedKernel = true;
      }
      if (legacySAR) {
        result = magiskboot([
          'hexpatch',
          'kernel',
          '736B69705F696E697472616D667300',
          '77616E745F696E697472616D667300'
        ]);
        if (result.exitCode == 0) {
          patchedKernel = true;
        }
      }

      if (!patchedKernel) {
        kernel.deleteSync();
      }
    }
    result = magiskboot([
      'repack',
      'boot.img',
    ]);

    if (result.exitCode != 0) {
      changeProgressInfo('! Unable to repack boot image', null);
      return;
    }
    return;
  }
}
