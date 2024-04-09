import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:root_patcher/apatch_helper.dart';
import 'package:root_patcher/patch_helper.dart';
import 'package:window_manager/window_manager.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

import 'package:root_patcher/magisk_helper.dart';
import 'package:root_patcher/kernelsu_helper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(800, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => MyAppState();

  static MyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<MyAppState>()!;
}

class MyAppState extends State<MyApp> {
  // This widget is the root of your application.
  ThemeMode _themeMode = ThemeMode.system;
  bool useMaterial3 = true;

  @override
  Widget build(BuildContext context) {
    var lightTheme = ThemeData.light(useMaterial3: useMaterial3);
    var darkTheme = ThemeData.dark(useMaterial3: useMaterial3);
    var lightSnackBarTheme = SnackBarThemeData(
      backgroundColor: lightTheme.cardColor,
      actionBackgroundColor: lightTheme.buttonTheme.colorScheme!.primary,
      actionTextColor: lightTheme.buttonTheme.colorScheme!.onPrimary,
      elevation: 4.0,
      width: 420,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(5),
      ),
      behavior: SnackBarBehavior.floating,
      contentTextStyle: const TextStyle(color: Colors.black),
      insetPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
    );
    var darkSnackBarTheme = SnackBarThemeData(
      backgroundColor: darkTheme.cardColor,
      actionBackgroundColor: darkTheme.buttonTheme.colorScheme!.primary,
      actionTextColor: darkTheme.buttonTheme.colorScheme!.onPrimary,
      elevation: 4.0,
      width: 420,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      behavior: SnackBarBehavior.floating,
      contentTextStyle: const TextStyle(color: Colors.white),
      insetPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
    );

    return MaterialApp(
      title: 'Flutter Demo',
      theme: lightTheme.copyWith(snackBarTheme: lightSnackBarTheme),
      darkTheme: darkTheme.copyWith(snackBarTheme: darkSnackBarTheme),
      themeMode: _themeMode,
      // snak bar theme

      home: Platform.isLinux
          ? ClipRRect(
              borderRadius: BorderRadius.circular(10.0),
              child: const MyHomePage())
          : const MyHomePage(),
    );
  }

  void changeThemeMode(ThemeMode themeMode) {
    setState(() {
      _themeMode = themeMode;
    });
  }

  void changeUseMaterialDesign3(bool value) {
    setState(() {
      useMaterial3 = value;
    });
  }
}

class MyIcons {
  static const String fontFamily = "MyCustomIcons";
  static const IconData magisk = IconData(
    0xec01,
    fontFamily: fontFamily,
  );
  static const IconData kernelsu = IconData(
    0xe602,
    fontFamily: fontFamily,
  );
  static const IconData apatch = IconData(
    0xe604,
    fontFamily: fontFamily,
  );
}

class MagiskSpec {
  static bool keepVerity = true;
  static bool keepForceEncrypt = true;
  static bool patchVbmetaFlag = false;
  static bool patchRecovery = false;
  static bool legacySAR = true;

  static List<String>? magiskList;
  static int magiskSelection = 0;
  static String? localMagiskApk;
  static Map<String, Map<String, String>>? magiskInfo;
}

class KernelSUSpec {
  static int ksuModuleSelection = 0;

  static List<String>? ksuModuleList;
  static Map<String, String>? ksuModuleInfo;
}

class ApatchSpec {
  static String? superKey;
}

class MyCfg {
  static int versionMajor = 1;
  static int versionMinor = 0;
  static int versionPatch = 0;
  static String versionString = "$versionMajor.$versionMinor.$versionPatch";

  // Settings initialized
  static bool isSettingsInitialed = false;

  // Common
  static String? bootImage;
  static bool isPatching = false;
  static bool useProxy = false;
  static String? proxy;

  // Magisk
  static bool magiskApkFromOnline = false;
  static bool magiskDownloadFromJsdelivr = true; // faster for everyone
  static bool magiskFromCustomSource = false;
  static String? magiskCustomSource;

  // KernelSU
  static bool kernelsuUseInitSpecified = false;
  static String? kernelsuInitSpecified;

  // APatch
  static bool apatchUseLocalKpimg = false;
  static String? apatchLocalKpimg;
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();

  static _MyHomePageState of(BuildContext context) =>
      context.findAncestorStateOfType<_MyHomePageState>()!;
}

class _MyHomePageState extends State<MyHomePage> {
  var selectedIndex = 0;
  final List<Widget> pages = [
    const HelloPage(),
    const MagiskPatchPage(),
    const KernelSUPatchPage(),
    const APatchPage(),
    const SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    Widget page = pages[selectedIndex];
    return LayoutBuilder(builder: (context, constraints) {
      return Scaffold(
        appBar: PreferredSize(
            preferredSize: Size(constraints.maxWidth, 60),
            child: const TitleBar()),
        body: Row(
          children: [
            NavigationRail(
              extended: constraints.maxWidth >= 600,
              minWidth: 84,
              minExtendedWidth: 200,
              trailing: Expanded(
                child: Container(
                  alignment: Alignment.bottomLeft,
                  padding: const EdgeInsets.only(bottom: 20),
                  child: FilledButton(
                    child: const Text("Visit on Github"),
                    onPressed: () {
                      final Uri uri = Uri.parse("https://www.baidu.com");
                      launchUrl(uri);
                    },
                  ),
                ),
              ),
              destinations: [
                NavigationRailDestination(
                    icon: const Icon(Icons.home),
                    label: const Text("Home"),
                    disabled: MyCfg.isPatching),
                NavigationRailDestination(
                    icon: const Icon(MyIcons.magisk),
                    label: const Text("Magisk"),
                    disabled: MyCfg.isPatching),
                NavigationRailDestination(
                    icon: const Icon(MyIcons.kernelsu),
                    label: const Text("KernelSU"),
                    disabled: MyCfg.isPatching),
                NavigationRailDestination(
                    icon: const Icon(MyIcons.apatch),
                    label: const Text("APatch"),
                    disabled: MyCfg.isPatching),
                NavigationRailDestination(
                    icon: const Icon(Icons.settings),
                    label: const Text("Settings"),
                    disabled: MyCfg.isPatching)
              ],
              selectedIndex: selectedIndex,
              onDestinationSelected: (value) => {
                setState(() {
                  selectedIndex = value;
                })
              },
            ),
            Expanded(
                child: Container(
                    //color: Theme.of(context).primaryColor,
                    decoration: BoxDecoration(
                      color: Theme.of(context).hoverColor,
                      borderRadius: Theme.of(context).useMaterial3
                          ? const BorderRadius.only(
                              topLeft: Radius.circular(10))
                          : null,
                    ),
                    //color: Theme.of(context).primaryColor,
                    child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: page,
                        transitionBuilder:
                            (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: Tween<double>(
                              begin: 0.0,
                              end: 1.0,
                            ).animate(animation),
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.0, 0.05),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        }))),
          ],
        ),
      );
    });
  }
}

class HelloPage extends StatefulWidget {
  const HelloPage({super.key});

  @override
  State<HelloPage> createState() => _HelloPageState();
}

class _HelloPageState extends State<HelloPage> {
  final TextEditingController _textEditingController =
      TextEditingController(text: MyCfg.bootImage);

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: AlignmentDirectional.centerStart,
      padding: const EdgeInsets.all(25),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          const Text("Please select a boot image",
              style: TextStyle(
                fontSize: 24,
              )),
          IntrinsicHeight(
              child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textEditingController,
                  obscureText: false,
                  decoration: const InputDecoration(
                      border: OutlineInputBorder(), labelText: "Boot image"),
                  onChanged: (value) {
                    MyCfg.bootImage = value;
                  },
                ),
              ),
              IconButton(
                onPressed: () async {
                  FilePickerResult? result =
                      await FilePicker.platform.pickFiles();

                  if (result != null) {
                    _textEditingController.text = result.files.single.path!;
                    MyCfg.bootImage = _textEditingController.text;
                  }
                },
                icon: const Icon(Icons.file_open),
                style: ButtonStyle(iconSize: WidgetStateProperty.all(36)),
              ),
            ],
          )),
        ],
      ),
    );
  }
}

enum Archs {
  arm64,
  arm32,
  x86_64,
  x86,
}

class MagiskPatchPage extends StatefulWidget {
  const MagiskPatchPage({super.key});

  @override
  State<MagiskPatchPage> createState() => _MagiskPatchPageState();

  static _MagiskPatchPageState of(BuildContext context) {
    return context.findAncestorStateOfType<_MagiskPatchPageState>()!;
  }
}

class _MagiskPatchPageState extends State<MagiskPatchPage> {
  Archs archsView = Archs.arm64;

  String? magiskSelection;
  int magiskRadioSelection = 0;
  bool fetchDone = false;
  //bool isPatching = false;

  Future<List<String>> fetchData() async {
    var m = MagiskHelper();
    if (MagiskSpec.magiskList == null) {
      MagiskSpec.magiskInfo = await m.getMagiskReleasesInfo();
      MagiskSpec.magiskList = MagiskSpec.magiskInfo!.keys.toList();
    }
    return MagiskSpec.magiskList!;
  }

  @override
  Widget build(BuildContext context) {
    return CommonPatchScaffold(
      child: Column(
        children: [
          Expanded(
            flex: 0,
            child: SegmentedButton<Archs>(
              segments: const <ButtonSegment<Archs>>[
                ButtonSegment<Archs>(
                  value: Archs.arm64,
                  label: Text("arm64"),
                  icon: Icon(Icons.architecture),
                ),
                ButtonSegment<Archs>(
                  value: Archs.arm32,
                  label: Text("arm32"),
                  icon: Icon(Icons.architecture),
                ),
                ButtonSegment<Archs>(
                  value: Archs.x86,
                  label: Text("x86"),
                  icon: Icon(Icons.architecture),
                ),
                ButtonSegment<Archs>(
                  value: Archs.x86_64,
                  label: Text("x86_64"),
                  icon: Icon(Icons.architecture),
                ),
              ],
              selected: <Archs>{archsView},
              onSelectionChanged: (value) {
                setState(() {
                  archsView = value.first;
                });
              },
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
              child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Expanded(child: MagiskPatchConfigListView()),
              const Divider(),
              Expanded(
                child: MyCfg.magiskApkFromOnline
                    ? FutureBuilder(
                        future: fetchData(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState !=
                              ConnectionState.done) {
                            return const Column(
                                children: [RefreshProgressIndicator()]);
                          } else {
                            if (snapshot.data == null) {
                              return const Text("Could not fetch");
                            } else {
                              fetchDone = true;
                              return const MagiskListView();
                            }
                          }
                        })
                    : const MagiskApkSelectCard(),
              )
            ],
          )),
        ],
      ),
    );
  }
}

class MagiskApkSelectCard extends StatefulWidget {
  const MagiskApkSelectCard({super.key});

  @override
  State<MagiskApkSelectCard> createState() => _MagiskApkSelectCardState();
}

class _MagiskApkSelectCardState extends State<MagiskApkSelectCard> {
  final _textEditingController =
      TextEditingController(text: MagiskSpec.localMagiskApk);

  @override
  Widget build(BuildContext context) {
    return CardTile(labelText: "Select a magisk apk", children: [
      Expanded(
          flex: 0,
          child: TextFormField(
            controller: _textEditingController,
            onChanged: (value) {
              setState(() {
                MagiskSpec.localMagiskApk = value;
              });
            },
          )),
      Container(
          padding: const EdgeInsets.all(20),
          alignment: Alignment.center,
          child: FilledButton.tonalIcon(
              onPressed: () async {
                var result = await FilePicker.platform.pickFiles();

                if (result != null) {
                  setState(() {
                    _textEditingController.text = result.files.single.path!;
                    MagiskSpec.localMagiskApk =
                        (_textEditingController.text == "")
                            ? null
                            : result.files.single.path!;
                  });
                }
              },
              icon: const Icon(Icons.file_open_rounded),
              label: const Text("Open"))),
    ]);
  }
}

class MagiskPatchConfigListView extends StatefulWidget {
  const MagiskPatchConfigListView({super.key});

  @override
  State<MagiskPatchConfigListView> createState() =>
      _MagiskPatchConfigListViewState();
}

class _MagiskPatchConfigListViewState extends State<MagiskPatchConfigListView> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        SwitchListTile(
            title: const Text("Magisk apk from github"),
            value: MyCfg.magiskApkFromOnline,
            onChanged: (value) {
              setState(() {
                MyCfg.magiskApkFromOnline = value;
              });
              MagiskPatchPage.of(context).setState(() {
                //MyCfg.magiskApkFromOnline = !MyCfg.magiskApkFromOnline;
              });
            }),
        CheckboxListTile(
            title: const Text("Keep verity"),
            value: MagiskSpec.keepVerity,
            onChanged: (value) => setState(() {
                  MagiskSpec.keepVerity = value!;
                })),
        CheckboxListTile(
            title: const Text("Keep force encrypt"),
            value: MagiskSpec.keepForceEncrypt,
            onChanged: (value) => setState(() {
                  MagiskSpec.keepForceEncrypt = value!;
                })),
        CheckboxListTile(
            title: const Text("Patch vbmeta flag"),
            value: MagiskSpec.patchVbmetaFlag,
            onChanged: (value) => setState(() {
                  MagiskSpec.patchVbmetaFlag = value!;
                })),
        CheckboxListTile(
            title: const Text("Patch recovery"),
            value: MagiskSpec.patchRecovery,
            onChanged: (value) => setState(() {
                  MagiskSpec.patchRecovery = value!;
                })),
        CheckboxListTile(
            title: const Text("Legacy SAR"),
            subtitle: const Text("On some sar device but no dynamic partition"),
            value: MagiskSpec.legacySAR,
            onChanged: (value) => setState(() {
                  MagiskSpec.legacySAR = value!;
                })),
      ],
    );
  }
}

class KernelSUPatchPage extends StatefulWidget {
  const KernelSUPatchPage({super.key});

  @override
  State<KernelSUPatchPage> createState() => _KernelSUPatchPageState();
}

class _KernelSUPatchPageState extends State<KernelSUPatchPage> {
  String? _kernelVersion;
  final selection = ValueNotifier(KernelSUSpec.ksuModuleSelection);

  @override
  Widget build(BuildContext context) {
    return CommonPatchScaffold(
        //onPatchPressed: () async {},
        child: Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(children: [
          Expanded(
              child: FilledButton.tonal(
                  onPressed: () async {
                    _kernelVersion = null;
                    var _bootImage = File(MyCfg.bootImage ?? "");
                    if (_bootImage.existsSync()) {
                      _kernelVersion =
                          await KernelSUHelper.getKernelVersion(_bootImage);
                    }
                    if (context.mounted) {
                      showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: const Text("Fetched kernel version"),
                              content: Text(
                                (_kernelVersion == null)
                                    ? "Could not fetch kernel version"
                                    : "Fetched your kernel version is: $_kernelVersion",
                              ),
                              actions: [
                                TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                    child: const Text("OK")),
                              ],
                            );
                          });
                    }
                  },
                  child: const Text("Get kernel version"))),
          const SizedBox(
            width: 10,
          ),
          Expanded(
              child: FilledButton.tonal(
                  onPressed: () async {
                    _kernelVersion = null;
                    var _bootimage = File(MyCfg.bootImage ?? "");
                    if (_bootimage.existsSync()) {
                      _kernelVersion =
                          await KernelSUHelper.getKernelVersion(_bootimage);

                      if (_kernelVersion != null &&
                          KernelSUSpec.ksuModuleList != null) {
                        var kmi = KernelSUSpec.ksuModuleList
                            ?.indexOf("${_kernelVersion}_kernelsu.ko");
                        if (kmi != null || kmi! > 0) {
                          //KernelSUSpec.ksuModuleSelection = kmi;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(
                                "Suggest you select ${_kernelVersion}_kernelsu.ko"),
                            action:
                                SnackBarAction(label: "OK", onPressed: () {}),
                          ));
                          selection.value = KernelSUSpec.ksuModuleSelection;
                        } else {
                          showDialog(
                            context: context,
                            builder: (context) => const AlertDialog(
                              icon: Icon(Icons.warning),
                              title: Text(
                                  "Cannot suggest, please check on your phone"),
                              content: Text(
                                  "Cannot find your kernel version on given list"),
                            ),
                          );
                        }
                      }
                    }
                  },
                  child: const Text("Try suggest select"))),
        ]),
        Expanded(
          child: KernelSULKMListView(selection),
        ),
      ],
    ));
  }
}

class KernelSULKMListView extends StatefulWidget {
  const KernelSULKMListView(this.selection, {super.key});

  final ValueListenable<int> selection;

  @override
  State<KernelSULKMListView> createState() => _KernelSULKMListViewState();
}

class _KernelSULKMListViewState extends State<KernelSULKMListView> {
  Future<List<String>?> fetchData() async {
    KernelSUSpec.ksuModuleInfo = await KernelSUHelper.getKernelSUKPMInfo();
    KernelSUSpec.ksuModuleList = KernelSUSpec.ksuModuleInfo?.keys.toList();

    return KernelSUSpec.ksuModuleList;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.list),
          title: const Text("LKM List"),
          trailing: Tooltip(
            message: "Press me to refresh list",
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  KernelSUHelper.reset();
                });
              },
              label: const Icon(Icons.refresh),
            ),
          ),
        ),
        FutureBuilder(
          future: fetchData(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                alignment: Alignment.topCenter,
                child: const RefreshProgressIndicator(),
              );
            } else {
              if (snapshot.data == null) {
                return const Text("Cannot fetch data from github");
              }
              return Expanded(child: KernelSULKMList(data: snapshot.data!, selection: widget.selection,));
            }
          },
        ),
      ],
    );
  }
}

class KernelSULKMList extends StatefulWidget {
  const KernelSULKMList({super.key, required this.data, required this.selection});

  final List<String> data;
  final ValueListenable<int> selection;

  @override
  State<KernelSULKMList> createState() => _KernelSULKMListState();
}

class _KernelSULKMListState extends State<KernelSULKMList> {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: widget.data.length,
      itemBuilder: (context, index) {
        return RadioListTile<int>(
            title: Text(widget.data[index]),
            value: index,
            groupValue: KernelSUSpec.ksuModuleSelection,
            onChanged: (value) {
              setState(() {
                KernelSUSpec.ksuModuleSelection = value!;
                //context.findAncestorStateOfType<_KernelSUPatchPageState>()?.setState(() {
                //  
                //});
              });
            });
      },
    );
  }
}

class CommonPatchScaffold extends StatefulWidget {
  const CommonPatchScaffold(
      {super.key,
      required this.child,
      //required this.onPatchPressed,
      this.disabled = false});

  final Widget child;
  //final Future<void> Function()? onPatchPressed;
  final bool disabled;

  @override
  State<CommonPatchScaffold> createState() => CommonPatchScaffoldState();

  static CommonPatchScaffoldState? of(BuildContext context) =>
      context.findAncestorStateOfType<CommonPatchScaffoldState>();
}

class CommonPatchScaffoldState extends State<CommonPatchScaffold> {
  static String? _statusString;
  static double? _progressValue;

  void changeProgressInfo(String? statusString, double? progressValue) =>
      setState(() {
        _statusString = statusString;
        _progressValue = progressValue;
      });

  void changeProgressStatusString(String? statusString) => setState(() {
        _statusString = statusString;
      });

  void changeProgressValue(double? progressValue) => setState(() {
        _progressValue = progressValue;
      });

  @override
  Widget build(BuildContext context) {
    void changeNavigateRialWhenPatching() {
      MyHomePage.of(context).setState(() {
        // void
      });
    }

    return Container(
      alignment: Alignment.topCenter,
      padding: const EdgeInsets.all(20.0),
      child: Column(
        //mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.only(right: 20),
                child: const Text("Boot image:"),
              ),
              Expanded(
                child: TextFormField(
                  initialValue: MyCfg.bootImage,
                  enabled: false,
                ),
              )
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: widget.child,
          ),
          const Divider(),
          Container(
              alignment: Alignment.bottomCenter,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  MyCfg.isPatching
                      ? Expanded(
                          child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          child: Container(
                            padding: const EdgeInsets.only(left: 10, right: 10),
                            child: Text(_statusString ?? "Patching..."),
                          ),
                        ))
                      : Container(),
                  MyCfg.isPatching
                      ? Expanded(
                          child: Container(
                          padding: const EdgeInsets.only(left: 10, right: 10),
                          child: LinearProgressIndicator(
                            value: _progressValue,
                          ),
                        ))
                      : Container(),
                  TextButton(
                    onPressed: !MyCfg.isPatching
                        ? () async {
                            setState(() {
                              MyCfg.isPatching = !MyCfg.isPatching;
                              changeNavigateRialWhenPatching();
                              _statusString = null;
                              _progressValue = null;
                            });

                            bool result = false;
                            if (context.mounted) {
                              try {
                                switch (MyHomePage.of(context).selectedIndex) {
                                  case 1:
                                    if ((MyCfg.magiskApkFromOnline)
                                        ? (MagiskSpec.magiskList == null)
                                        : (MagiskSpec.localMagiskApk == null ||
                                            !File(MagiskSpec.localMagiskApk!)
                                                .existsSync())) {
                                      showDialog(
                                        context: context,
                                        builder: (context) {
                                          return const AlertDialog(
                                            icon: Icon(Icons.error),
                                            title: Text("Error"),
                                            content: Text(
                                                "Could not fetch magisk cause no magisk list can be found"),
                                          );
                                        },
                                      );
                                      break;
                                    }

                                    log("patch from local file: ${MagiskSpec.localMagiskApk}");
                                    log("patch from online: ${MyCfg.magiskApkFromOnline}");

                                    var key = MagiskSpec.magiskList?[
                                        MagiskSpec.magiskSelection];
                                    var downloadUrl = MagiskSpec.magiskInfo ==
                                            null
                                        ? ''
                                        : MagiskSpec
                                            .magiskInfo![key]!['download_url'];
                                    var patcher = MagiskPatcher(MyCfg.bootImage,
                                        fetchFromOnline:
                                            MyCfg.magiskApkFromOnline,
                                        localApk: MagiskSpec.localMagiskApk,
                                        downloadUrl: downloadUrl,
                                        arch: MagiskPatchPage.of(context)
                                            .archsView
                                            .toString()
                                            .split('.')[1],
                                        keepVerity: MagiskSpec.keepVerity,
                                        keepForceEncrypt:
                                            MagiskSpec.keepForceEncrypt,
                                        patchRecovery: MagiskSpec.patchRecovery,
                                        patchVbmetaFlag:
                                            MagiskSpec.patchVbmetaFlag,
                                        legacySAR: MagiskSpec.legacySAR);
                                    result =
                                        await patcher.patch(changeProgressInfo);
                                    break;
                                  case 2:
                                    try {
                                      var ksupatcher = KernelSUPatcher(
                                          MyCfg.bootImage,
                                          useLocalInit:
                                              MyCfg.kernelsuUseInitSpecified,
                                          localInit:
                                              MyCfg.kernelsuInitSpecified,
                                          moduleUrl: KernelSUSpec
                                                  .ksuModuleInfo?[
                                              KernelSUSpec.ksuModuleList?[
                                                  KernelSUSpec
                                                      .ksuModuleSelection]]);
                                      result = await ksupatcher
                                          .patch(changeProgressInfo);
                                    } catch (e) {
                                      showDialog(
                                        context: context,
                                        builder: (context) {
                                          return AlertDialog(
                                            icon: const Icon(Icons.error),
                                            title: const Text("Catch errors"),
                                            content: Text("$e"),
                                          );
                                        },
                                      );
                                    }
                                    break;
                                  case 3:
                                    break;
                                  default:
                                    break;
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  showDialog(
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        icon: const Icon(Icons.error),
                                        title: const Text("Catch errors"),
                                        content: Text("$e"),
                                      );
                                    },
                                  );
                                }
                              }
                            }
                            if (context.mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(
                                content: Text(result
                                    ? "😊Seems success"
                                    : "😟Seems not success"),
                                action: SnackBarAction(
                                  label: result ? "Open folder" : "Fine",
                                  onPressed: () {
                                    if (result) {
                                      OpenFile.open(path.join(
                                          File(Platform.resolvedExecutable)
                                              .parent
                                              .path,
                                          "out/"));
                                    }
                                  },
                                ),
                              ));
                            }

                            setState(() {
                              MyCfg.isPatching = !MyCfg.isPatching;
                              changeNavigateRialWhenPatching();
                            });
                          }
                        : null,
                    child: const Text(
                      "Patch",
                      textScaler: TextScaler.linear(1.5),
                    ),
                  )
                ],
              ))
        ],
      ),
    );
  }
}

class MagiskListView extends StatefulWidget {
  const MagiskListView({super.key});

  @override
  State<MagiskListView> createState() => _MagiskListViewState();
}

class _MagiskListViewState extends State<MagiskListView> {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: MagiskSpec.magiskList!.length,
      itemBuilder: (context, index) {
        return RadioListTile(
          title: Text(MagiskSpec.magiskList![index]),
          value: index,
          groupValue: MagiskSpec.magiskSelection,
          onChanged: (value) {
            setState(() {
              MagiskSpec.magiskSelection = value!;
            });
          },
        );
      },
    );
  }
}

class APatchPage extends StatelessWidget {
  // get non prerelease version
  final bool _useLatest = false;

  const APatchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CommonPatchScaffold(
      //onPatchPressed: () async {},
      child: ListView(
        children: [
          CardTile(labelText: "Common", children: [
            FutureBuilder(
              future: ApatchHelper.getAPatchLatestVersionTag(_useLatest),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Container(
                    alignment: Alignment.topCenter,
                    child: const LinearProgressIndicator(),
                  );
                } else {
                  return APatchLatestVersionListTile(labelText: snapshot.data);
                }
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: TextEditingController(text: ApatchSpec.superKey),
              decoration: const InputDecoration(
                labelText: "SuperKey",
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                ApatchSpec.superKey = value;
              },
            )
          ]),
          const CardTile(labelText: "Advanced", children: [
            ListTile(
                title: Text("This component has not been implemented yet.")),
          ])
        ],
      ),
    );
  }
}

class APatchLatestVersionListTile extends StatefulWidget {
  const APatchLatestVersionListTile({super.key, required this.labelText});

  final String? labelText;

  @override
  State<APatchLatestVersionListTile> createState() =>
      _APatchLatestVersionListTileState();
}

class _APatchLatestVersionListTileState
    extends State<APatchLatestVersionListTile> {
  bool _useLatest = false;
  String? labelText;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.cloud),
      title: Text(
          labelText ?? (widget.labelText ?? "Could not fetch latest version")),
      subtitle:
          const Text("Change this switch to switch latest/stable channel"),
      trailing: Switch(
        value: _useLatest,
        onChanged: (value) async {
          labelText = await ApatchHelper.getAPatchLatestVersionTag(value);
          setState(() {
            _useLatest = value;
          });
        },
      ),
    );
  }
}

class TitleBar extends StatefulWidget {
  const TitleBar({super.key});

  @override
  State<TitleBar> createState() => _TitleBarState();
}

class _TitleBarState extends State<TitleBar> with WindowListener {
  @override
  void initState() {
    windowManager.addListener(this);
    super.initState();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Brightness brightness = Theme.of(context).brightness;

    return PreferredSize(
      preferredSize: const Size.fromHeight(80),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        child: Row(
          children: [
            Expanded(
              child: DragToMoveArea(
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        margin: const EdgeInsets.all(20),
                        child: const Icon(Icons.android),
                      ),
                      const Text(
                        "Root Patcher",
                        style: TextStyle(
                          fontSize: 24,
                        ),
                      ),
                    ]),
              ),
            ),
            const ChangeMaterialDesign3Button(),
            const LightDarkButtons(),
            PreferredSize(
                preferredSize: const Size.fromHeight(36),
                child: Row(children: [
                  WindowCaptionButton.minimize(
                    brightness: brightness,
                    onPressed: () async {
                      bool isMinimized = await windowManager.isMinimized();
                      if (isMinimized) {
                        windowManager.restore();
                      } else {
                        windowManager.minimize();
                      }
                    },
                  ),
                  FutureBuilder(
                    future: windowManager.isMaximized(),
                    builder: (context, snapshot) {
                      if (snapshot.data == false) {
                        return WindowCaptionButton.maximize(
                          brightness: brightness,
                          onPressed: () {
                            windowManager.maximize();
                          },
                        );
                      } else {
                        return WindowCaptionButton.unmaximize(
                          brightness: brightness,
                          onPressed: () {
                            windowManager.unmaximize();
                          },
                        );
                      }
                    },
                  ),
                  WindowCaptionButton.close(
                    brightness: brightness,
                    onPressed: () {
                      windowManager.close();
                    },
                  ),
                ])),
          ],
        ),
      ),
    );
  }

  @override
  void onWindowMaximize() {
    setState(() {});
  }

  @override
  void onWindowUnmaximize() {
    setState(() {});
  }
}

class ChangeMaterialDesign3Button extends StatefulWidget {
  const ChangeMaterialDesign3Button({super.key});

  @override
  State<ChangeMaterialDesign3Button> createState() =>
      _ChangeMaterialDesign3ButtonState();
}

class _ChangeMaterialDesign3ButtonState
    extends State<ChangeMaterialDesign3Button> {
  @override
  Widget build(BuildContext context) {
    bool md3 = Theme.of(context).useMaterial3;

    return IconButton(
        onPressed: () {
          MyApp.of(context).changeUseMaterialDesign3(!md3);
        },
        icon: Icon(md3 ? Icons.looks_3_outlined : Icons.looks_two_outlined));
  }
}

class LightDarkButtons extends StatefulWidget {
  const LightDarkButtons({super.key});

  @override
  State<LightDarkButtons> createState() => _LightDarkButtonsState();
}

class _LightDarkButtonsState extends State<LightDarkButtons> {
  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        IconButton(
            onPressed: () {
              setState(() {
                MyApp.of(context)
                    .changeThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
                isDark = !isDark;
              });
            },
            icon: Icon(isDark ? Icons.dark_mode : Icons.light_mode)),
      ],
    );
  }
}

class CardTile extends StatelessWidget {
  const CardTile({super.key, required this.labelText, required this.children});

  final String? labelText;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
        color: Theme.of(context).cardColor,
        child: Container(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
                  Text(
                    labelText!,
                    style: const TextStyle(
                        fontSize: 24, fontStyle: FontStyle.normal),
                  ),
                ] +
                children,
          ),
        ));
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();

  //static _SettingsPageState of(BuildContext context) =>
  //  context.findAncestorStateOfType<_SettingsPageState>()!;
}

class _SettingsPageState extends State<SettingsPage> {
  final _kpimgEditingController =
      TextEditingController(text: MyCfg.apatchLocalKpimg);
  final _ksuInitEditingController =
      TextEditingController(text: MyCfg.kernelsuInitSpecified);

  @override
  void initState() {
    super.initState();
    _loadSettings();
    MyCfg.isSettingsInitialed = true;
  }

  Future<void> _loadSettings() async {
    if (!MyCfg.isSettingsInitialed) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      setState(() {
        MyCfg.useProxy = prefs.getBool('useProxy')!;
        MyCfg.proxy = prefs.getString('proxy');
        MyCfg.magiskFromCustomSource = prefs.getBool('magiskFromCustomSource')!;
        MyCfg.magiskCustomSource = prefs.getString('magiskCustomSource');
        MyCfg.magiskDownloadFromJsdelivr =
            prefs.getBool('magiskDownloadFromJsdelivr')!;
        // no init for kernelsu
        // no init for apatch
      });
    }
  }

  Future<void> _saveSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs
      ..setBool('useProxy', MyCfg.useProxy)
      ..setString('proxy', MyCfg.proxy ?? "")
      ..setBool('magiskFromCustomSource', MyCfg.magiskFromCustomSource)
      ..setString('magiskCustomSource', MyCfg.magiskCustomSource ?? "")
      ..setBool('magiskDownloadFromJsdelivr', MyCfg.magiskDownloadFromJsdelivr);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Expanded(
            child: ListView(children: [
              CardTile(labelText: "General", children: [
                SwitchListTile(
                    title: const Text("Use Proxy"),
                    value: MyCfg.useProxy,
                    onChanged: (value) => setState(() {
                          MyCfg.useProxy = value;
                        })),
                MyCfg.useProxy
                    ? Expanded(
                        flex: 0,
                        child: TextFormField(
                          decoration: const InputDecoration(
                            label: Text("Proxy"),
                            //border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            MyCfg.proxy = value;
                          },
                        ))
                    : Container()
              ]),
              CardTile(
                labelText: 'Magisk',
                children: [
                  SwitchListTile(
                      title: const Text("Magisk from custom source"),
                      subtitle: const Text(
                          "Parse magisk list and download info from custom source"),
                      value: MyCfg.magiskFromCustomSource,
                      onChanged: (value) => setState(() {
                            MyCfg.magiskFromCustomSource = value;
                          })),
                  MyCfg.magiskFromCustomSource
                      ? Expanded(
                          flex: 0,
                          child: TextFormField(
                            decoration: const InputDecoration(
                              label: Text("Custom source"),
                              //border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              MyCfg.magiskCustomSource = value;
                            },
                          ))
                      : Container(),
                  SwitchListTile(
                      title: const Text("Fetch magisk from jsDelivr"),
                      subtitle: const Text(
                          "If you patch magisk from github, will parse github download url to jsDelivr download url"),
                      value: MyCfg.magiskDownloadFromJsdelivr,
                      onChanged: (value) => setState(() {
                            MyCfg.magiskDownloadFromJsdelivr = value;
                          })),
                ],
              ),
              CardTile(labelText: "KernelSU", children: [
                SwitchListTile(
                    title: const Text("Use init from local"),
                    value: MyCfg.kernelsuUseInitSpecified,
                    onChanged: (value) => setState(() {
                          MyCfg.kernelsuUseInitSpecified = value;
                        })),
                MyCfg.kernelsuUseInitSpecified
                    ? Row(children: [
                        Expanded(
                          child: TextFormField(
                            controller: _ksuInitEditingController,
                            decoration: const InputDecoration(
                              label: Text("init path"),
                              //border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              MyCfg.kernelsuInitSpecified = value;
                            },
                          ),
                        ),
                        IconButton.filledTonal(
                            onPressed: () async {
                              var result =
                                  await FilePicker.platform.pickFiles();

                              if (result != null) {
                                setState(
                                  () {
                                    _ksuInitEditingController.text =
                                        result.paths.single!;
                                  },
                                );
                              }
                            },
                            icon: const Icon(Icons.file_open))
                      ])
                    : Container(),
              ]),
              CardTile(labelText: "APatch", children: [
                SwitchListTile(
                    title: const Text("Use kpimg from local"),
                    value: MyCfg.apatchUseLocalKpimg,
                    onChanged: (value) => setState(() {
                          MyCfg.apatchUseLocalKpimg = value;
                        })),
                MyCfg.apatchUseLocalKpimg
                    ? Row(children: [
                        Expanded(
                          child: TextFormField(
                            controller: _kpimgEditingController,
                            decoration: const InputDecoration(
                              label: Text("Kpimg path"),
                              //border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              MyCfg.apatchLocalKpimg = value;
                            },
                          ),
                        ),
                        IconButton.filledTonal(
                            onPressed: () async {
                              var result =
                                  await FilePicker.platform.pickFiles();

                              if (result != null) {
                                setState(
                                  () {
                                    _kpimgEditingController.text =
                                        result.paths.single!;
                                  },
                                );
                              }
                            },
                            icon: const Icon(Icons.file_open))
                      ])
                    : Container(),
              ]),
              CardTile(labelText: "About", children: [
                const ListTile(
                  title: Text("Author"),
                  trailing: Text("affggh"),
                ),
                ListTile(
                  title: const Text("Version"),
                  trailing: Text(MyCfg.versionString),
                ),
                FutureBuilder(
                    future: fetchGithubApiLimit(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const ListTile(
                          title: Text("Github api access limit rate"),
                          leading: Icon(Icons.rate_review),
                          trailing: CircularProgressIndicator(),
                        );
                      } else {
                        int limit = 0;
                        int remaining = 0;
                        int reset = 0;
                        String subtitle =
                            "Could not fetch github api limit rate";
                        if (snapshot.data != null) {
                          limit = snapshot.data['rate']['limit'];
                          remaining = snapshot.data['rate']['remaining'];
                          reset = snapshot.data['rate']['reset'];
                          subtitle =
                              "limit: $limit remaining: $remaining\nreset_time:${DateTime.fromMillisecondsSinceEpoch(reset * 1000).toString()}";
                        }

                        return ListTile(
                          leading: const Icon(Icons.rate_review),
                          title: const Text("Github API rate limit"),
                          subtitle: Text(subtitle),
                          trailing: ElevatedButton.icon(
                              onPressed: () {
                                setState(() {});
                              },
                              label: const Icon(Icons.refresh)),
                        );
                      }
                    })
              ]),
            ]),
          ),
          const Divider(),
          Container(
            alignment: Alignment.bottomRight,
            child: TextButton(
                onPressed: () async {
                  await _saveSettings();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: const Text("Saved!"),
                      action: SnackBarAction(label: "OK", onPressed: () {}),
                    ));
                  }
                },
                child: const Text(
                  "Save",
                  textScaler: TextScaler.linear(1.5),
                )),
          ),
        ]));
  }
}

Future<dynamic> fetchGithubApiLimit() async {
  var apiUrl = Uri.parse("https://api.github.com/rate_limit");

  var response = await http.get(apiUrl);

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  }

  return null;
}
