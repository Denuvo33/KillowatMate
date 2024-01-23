import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:background_service/auth/auth_check.dart';
import 'package:background_service/auth/sign_in_page.dart';
import 'package:background_service/electronic_model.dart';
import 'package:background_service/firebase_options.dart';
import 'package:background_service/page/calculate_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

final FlutterLocalNotificationsPlugin flutterLocalPlugin =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel notificationChannel =
    AndroidNotificationChannel(
        'Energy Saver Foreground', 'Energy Saver Foreground Service',
        description: 'This is channel desc..', importance: Importance.low);
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initservice();
  Gemini.init(apiKey: '--Your API Key--');
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const MyApp());
}

Future<void> initservice() async {
  var service = FlutterBackgroundService();
  if (Platform.isIOS) {
    await flutterLocalPlugin.initialize(
      const InitializationSettings(iOS: DarwinInitializationSettings()),
    );
  }

  await flutterLocalPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(notificationChannel);

  await service.configure(
      iosConfiguration: IosConfiguration(),
      androidConfiguration: AndroidConfiguration(
          onStart: onStart,
          autoStart: false,
          //  notificationChannelId: 'Energy Saver Foreground',
          initialNotificationTitle: 'KillowatMate',
          initialNotificationContent: 'Realtime Track is Running',
          isForegroundMode: true));
  // service.startService();
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  var uid = FirebaseAuth.instance.currentUser!.uid;
  DartPluginRegistrant.ensureInitialized();
  int lastUpdateTime = 0;
  num totalDailyKwh = 0;

  Future<void> fetchDataAndUpdate() async {
    DatabaseReference db = FirebaseDatabase.instance.ref('users/$uid');
    num result = 0;
    num thisMonthKwh = 0;
    await db.onValue.first.then((event) {
      var data = event.snapshot.value;
      if (data != null && data is Map) {
        totalDailyKwh = data['totalDailyKwh'];
        thisMonthKwh = data['thisMonthKwh'];
      }
    });

    await db.child('tools').once().then((event) async {
      var data = event.snapshot.value;
      if (data != null && data is Map) {
        for (var entry in data.entries) {
          var key = entry.key;
          var value = entry.value;
          var condition = value['condition'];
          var runTime = value['runTime'];

          var watt = value['watt'];
          // var amount = value['amount'];
          var totalkwh = await value['totalKwh'];
          if (condition) {
            runTime += 1;
            totalkwh += await watt * 2;
            result += totalkwh;
            await db.child('tools').child('$key').update(
              {'totalKwh': totalkwh},
            );
            await db.child('tools').child('$key').update(
              {
                'runTime': runTime,
              },
            );
            runTime = 0;
          }
        }
      }
    });

    await db.update({'totalDailyKwh': result});
    totalDailyKwh = result;
    db.update(
      {
        'thisMonthKwh': thisMonthKwh += result,
      },
    );

    flutterLocalPlugin.show(
      90,
      "KillowatMate",
      'Total Daily kWh is ${totalDailyKwh.toStringAsFixed(2)}',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'Energy Saver Foreground',
          'Energy Saver Foreground Service',
          // icon: 'ic_bg_service_smal',
          ongoing: true,
        ),
      ),
    );
  }

  service.on('setAsForeground').listen((event) {
    debugPrint('This is Foreground =======');
    fetchDataAndUpdate();
  });

  Timer.periodic(Duration(seconds: 10), (timer) async {
    if (DateTime.now().millisecondsSinceEpoch - lastUpdateTime >= 5000) {
      debugPrint('background service running');
      await fetchDataAndUpdate();
    }
  });

  service.on('setAsBackground').listen((event) {
    debugPrint('This is Background =======');
  });

  service.on('stopService').listen((event) {
    service.stopSelf();
  });
}

showInformationDialog(BuildContext context) {
  showDialog(
      context: context,
      builder: (builder) {
        return AlertDialog(
          title: const Text('Information'),
          content: const Text(
              'KilowattMate is your go-to app for real-time energy monitoring and efficiency management. Track electricity usage, calculate total wattage, and set consumption targets with ease. The apps AI analyzes your habits, offering personalized suggestions to reduce energy waste. Enjoy a user-friendly interface, receive alerts, and empower yourself for a greener tomorrow. Download KilowattMate now to take control of your electricity consumption and save on energy bills'),
          actions: [
            TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Close'))
          ],
        );
      });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const AuthPage(),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
          //appBarTheme: AppBarTheme(color: Colors.cyan),
          useMaterial3: true,
          colorSchemeSeed: Colors.cyan,
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ButtonStyle(
                backgroundColor: MaterialStateProperty.all<Color>(Colors.teal),
                foregroundColor:
                    MaterialStateProperty.all<Color>(Colors.white)),
          ),
          brightness: Brightness.light),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  num totalDailyKwh = 0;
  num thisMonthKwh = 0;
  num maxDailyKwh = 0;
  GlobalKey keyButton1 = GlobalKey();
  GlobalKey keyButton2 = GlobalKey();
  GlobalKey keyButton3 = GlobalKey();
  GlobalKey keyButton4 = GlobalKey();
  GlobalKey keyButton5 = GlobalKey();
  List<ElectronicModel> toolsList = [];
  final TextEditingController _watts = TextEditingController();
  final TextEditingController _amount = TextEditingController();
  String toolsValue = 'AC';
  bool tutor1Done = false;
  var startText = 'Start/Stop';
  bool tutor2Done = false;
  bool showTutor1 = false;
  bool showTutor2 = false;
  late TutorialCoachMark tutorialCoachMark;
  List<ElectronicModel> myTools = [];
  List<String> listTools = [
    'AC',
    'TV',
    'Lamp',
    'PC',
    'Fan',
    'Iron',
    'Water Machine',
    'Router',
  ];
  bool showList = false;
  DatabaseReference? db;
  var uid = FirebaseAuth.instance.currentUser!.uid;
  var auth = FirebaseAuth.instance;
  var userName = 'aa';
  var thisMonth = '';
  @override
  void initState() {
    // TODO: implement initState
    getData();
    super.initState();
  }

  createNewTools() {
    showDialog(
        barrierDismissible: false,
        context: context,
        builder: (builder) {
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter setstate) {
            return AlertDialog(
              title: Text('Add your tools'),
              content: Container(
                height: 400,
                child: Column(
                  children: [
                    DropdownButton<String>(
                        value: toolsValue,
                        items: listTools.map((String items) {
                          return DropdownMenuItem(
                            value: items,
                            child: Text(items),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setstate(() => toolsValue = value!);
                        }),
                    TextField(
                      controller: _watts,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'How many watts is it?',
                        suffixText: 'watts',
                        helperText: 'e.g.10',
                      ),
                    ),
                    TextField(
                      controller: _amount,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'how many are there?',
                        helperText: 'e.g.1',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text('Cancel')),
                TextButton(
                    onPressed: () async {
                      if (_amount.text.isEmpty || _watts.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Fill all required')));
                      } else {
                        /*    var result =
                            num.parse(_amount.text) * num.parse(_watts.text);*/

                        db!.child('$toolsValue ${_watts.text} watts').update({
                          'watt': num.parse(_watts.text),
                          'name': toolsValue,
                          'amount': num.parse(_amount.text),
                          'condition': true,
                          'runTime': 0,
                          'totalKwh': 0
                        });
                        _amount.clear();
                        _watts.clear();
                        toolsValue = 'AC';
                        Navigator.pop(context);
                        if (!tutor2Done) {
                          showTutor2 = true;
                          await Future.delayed(Duration(seconds: 1));
                          createTutorial();
                          showTutorial();
                        }
                      }
                    },
                    child: Text('Confirm'))
              ],
            );
          });
        });
  }

  getData() {
    DateTime currentDate = DateTime.now();
    int month = currentDate.month;

    String monthName =
        DateFormat.MMMM().format(DateTime(currentDate.year, month));

    DatabaseReference dbTotal = FirebaseDatabase.instance.ref('users/$uid');
    dbTotal.onValue.listen((event) {
      var data = event.snapshot.value;
      if (data != null && data is Map) {
        setState(() {
          totalDailyKwh = data['totalDailyKwh'];
          thisMonthKwh = data['thisMonthKwh'];
          tutor1Done = data['tutor1Done'];
          tutor2Done = data['tutor2Done'];
          maxDailyKwh = data['maxDailyKwh'];
          userName = data['username'];
          thisMonth = data['month'];
          if (thisMonth != monthName) {
            dbTotal.update({'month': monthName});
          }
          if (!tutor1Done) {
            showTutor1 = true;
            createTutorial();
            Future.delayed(Duration.zero, showTutorial);
          }
        });
      }
    });
    db = FirebaseDatabase.instance.ref('users/$uid/tools');
    db!.onValue.listen((event) {
      var data = event.snapshot.value;
      if (data != null && data is Map) {
        setState(() {
          toolsList = [];
        });
        data.forEach((key, value) {
          var watt = value['watt'];
          var name = value['name'];
          var totalKwh = value['totalKwh'];
          var amount = value['amount'];
          var image = value['image'];
          var condition = value['condition'];
          var runTime = value['runTime'];

          setState(() {
            toolsList.add(ElectronicModel(
                name: name,
                id: name,
                runTime: runTime,
                amount: amount,
                totalToolsKwh: totalKwh,
                condition: condition,
                image: image,
                watt: watt));
            showList = true;
          });
        });
      } else {
        setState(() {
          showList = false;
        });
      }
    });
  }

  void showTutorial() {
    tutorialCoachMark.show(context: context);
  }

  void createTutorial() {
    tutorialCoachMark = TutorialCoachMark(
      targets: showTutor1 ? _createTargets() : _createTargets2(),
      colorShadow: Colors.teal,
      textSkip: "Press the Button to continue",
      paddingFocus: 1,
      opacityShadow: 0.5,
      imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      onFinish: () {
        debugPrint("finish");
        DatabaseReference db = FirebaseDatabase.instance.ref('users/$uid');
        if (showTutor1) {
          db.update({
            'tutor1Done': true,
          });
        } else if (showTutor2) {
          db.update({
            'tutor2Done': true,
          });
        }
      },
      onClickTarget: (target) {
        debugPrint('onClickTarget: $target');
      },
      onClickTargetWithTapPosition: (target, tapDetails) {
        debugPrint("target: $target");
        debugPrint(
            "clicked at position local: ${tapDetails.localPosition} - global: ${tapDetails.globalPosition}");
      },
      onClickOverlay: (target) {
        debugPrint('onClickOverlay: $target');
      },
      onSkip: () {
        debugPrint("skip");
        return false;
      },
    );
  }

  List<TargetFocus> _createTargets() {
    List<TargetFocus> targets = [];
    targets.add(
      TargetFocus(
        identify: "Button Create",
        keyTarget: keyButton1,
        alignSkip: Alignment.topRight,
        enableOverlayTab: true,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  SizedBox(
                    height: 80,
                  ),
                  Text(
                    "This is where you add your tools for RealTime Track.",
                    style: TextStyle(color: Colors.white, fontSize: 17),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    targets.add(
      TargetFocus(
        identify: "Button Calculate",
        keyTarget: keyButton2,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    height: 80,
                  ),
                  Text(
                    "This is where you want to calculate all your tools usage and get best suggest by our AI for save energy result. ",
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
    return targets;
  }

  List<TargetFocus> _createTargets2() {
    debugPrint('calculate 2 start');
    List<TargetFocus> targets = [];
    targets.add(
      TargetFocus(
        identify: "Button Calculate",
        keyTarget: keyButton3,
        alignSkip: Alignment.topRight,
        enableOverlayTab: true,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Text(
                    "This is where you want to calculate all your tools usage and get best suggest by our AI for save energy result.",
                    style: TextStyle(color: Colors.white, fontSize: 17),
                  ),
                  SizedBox(
                    height: 50,
                  )
                ],
              );
            },
          ),
        ],
      ),
    );

    targets.add(
      TargetFocus(
        identify: "Button Start",
        keyTarget: keyButton4,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    "This button will Start Realtime Track based on your tools.",
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(
                    height: 40,
                  )
                ],
              );
            },
          ),
        ],
      ),
    );
    targets.add(
      TargetFocus(
        identify: "Button Clear",
        keyTarget: keyButton5,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    "In here if you want to clear all your tools list. ",
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(
                    height: 40,
                  )
                ],
              );
            },
          ),
        ],
      ),
    );
    return targets;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('KillowatMate'),
        centerTitle: true,
        actions: [
          IconButton(
              onPressed: () {
                showInformationDialog(context);
              },
              icon: Icon(Icons.info))
        ],
      ),
      drawer: NavigationDrawer(children: [
        UserAccountsDrawerHeader(
            accountName: Text(userName),
            currentAccountPicture: CircleAvatar(
              child: Text(
                userName.substring(0, 1),
                style: TextStyle(fontSize: 35),
              ),
            ),
            accountEmail: Text(auth.currentUser!.email!)),
        ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('Information'),
          onTap: () {
            showInformationDialog(context);
          },
        ),
        Divider(),
        ListTile(
          leading: Icon(Icons.logout),
          title: Text('Logout'),
          onTap: () {
            showDialog(
                context: context,
                builder: (builder) {
                  return AlertDialog(
                    title: Text('Are you sure want to logout?'),
                    actions: [
                      TextButton(
                          onPressed: () async {
                            await FirebaseAuth.instance.signOut();
                            Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (ctx) => SignInPage()));
                          },
                          child: Text('Yes')),
                      TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: Text('No'))
                    ],
                  );
                });
          },
        ),
        Divider()
      ]),
      body: Container(
        margin: EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Card(
                  // color: Colors.tealAccent,
                  child: Container(
                    margin: const EdgeInsets.all(7),
                    child: Column(
                      children: [
                        Text('Max Daily kWh',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(maxDailyKwh == 0
                            ? 'Nothing'
                            : '${maxDailyKwh.toStringAsFixed(2)} kWh'),
                      ],
                    ),
                  ),
                ),
                Card(
                  // color: Colors.tealAccent,
                  child: Container(
                    width: 80,
                    margin: const EdgeInsets.all(7),
                    child: Column(
                      children: [
                        Text(
                          'Today',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text('${totalDailyKwh.toStringAsFixed(2)} kWh')
                      ],
                    ),
                  ),
                ),
                Card(
                  // color: Colors.tealAccent,
                  child: Container(
                    width: 80,
                    margin: const EdgeInsets.all(7),
                    child: Column(
                      children: [
                        Text(thisMonth,
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('${thisMonthKwh.toStringAsFixed(2)} kWh')
                      ],
                    ),
                  ),
                )
              ],
            ),
            Visibility(
              visible: showList,
              replacement: Center(
                child: Column(
                  children: [
                    Text('You Dont Have Any Tools Running'),
                    SizedBox(
                      width: 150,
                      child: ElevatedButton(
                          key: keyButton1,
                          onPressed: () {
                            createNewTools();
                          },
                          child: Row(
                            children: [
                              Icon(Icons.create),
                              Text('Create New'),
                            ],
                          )),
                    ),
                    Text(
                        'or you just want to do kwh calculations on electricity usage?'),
                    SizedBox(
                      width: 150,
                      child: ElevatedButton(
                          key: keyButton2,
                          onPressed: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (ctx) => CalculatePage()));
                          },
                          child: Row(
                            children: [
                              Icon(Icons.calculate),
                              Text('Calculate'),
                            ],
                          )),
                    )
                  ],
                ),
              ),
              child: Expanded(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    ListView.builder(
                      itemCount: toolsList.length,
                      itemBuilder: (BuildContext context, int index) {
                        return GestureDetector(
                            onLongPress: () {
                              showDialog(
                                  context: context,
                                  builder: (builder) {
                                    return AlertDialog(
                                      title: Text(
                                          'Are you sure want to delete ${toolsList[index].name}?'),
                                      actions: [
                                        TextButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                            },
                                            child: Text('No')),
                                        TextButton(
                                            onPressed: () {
                                              db!
                                                  .child(
                                                      '${toolsList[index].name} ${toolsList[index].watt} watts')
                                                  .remove();
                                              Navigator.pop(context);
                                            },
                                            child: Text('Yes'))
                                      ],
                                    );
                                  });
                            },
                            child: Card(
                              child: ListTile(
                                title: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.info),
                                        Text(
                                          toolsList[index].condition!
                                              ? 'Running'
                                              : 'Stopped',
                                          style: TextStyle(
                                              color: toolsList[index].condition!
                                                  ? Colors.green
                                                  : Colors.red,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        Spacer(),
                                        Switch(
                                            value: toolsList[index].condition!,
                                            onChanged: ((value) {
                                              db!
                                                  .child(
                                                      '${toolsList[index].name} ${toolsList[index].watt} watts')
                                                  .update({'condition': value});
                                              setState(() {
                                                toolsList[index].condition =
                                                    value;
                                              });
                                            }))
                                      ],
                                    ),
                                    Text(
                                      toolsList[index].name!,
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    )
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Watts: ${toolsList[index].watt}'),
                                    Text('Amount: ${toolsList[index].amount}x'),
                                    Text(
                                        'Time Running: ${toolsList[index].runTime} minute'),
                                    Divider(),
                                    Text(
                                      'Total kWh: ${toolsList[index].totalToolsKwh!.toStringAsFixed(2)}',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    )
                                  ],
                                ),
                              ),
                            ));
                      },
                    ),
                    Container(
                      margin: const EdgeInsets.all(20),
                      child: FloatingActionButton(
                        onPressed: () {
                          createNewTools();
                        },
                        child: Icon(Icons.add),
                      ),
                    )
                  ],
                ),
              ),
            ),
            if (showList)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ElevatedButton(
                    key: keyButton3,
                    onPressed: () {
                      Navigator.push(context,
                          MaterialPageRoute(builder: (ctx) => CalculatePage()));
                    },
                    child: Text('Calculate'),
                  ),
                  ElevatedButton(
                    key: keyButton4,
                    onPressed: () async {
                      FlutterBackgroundService service =
                          FlutterBackgroundService();
                      var isRunning = await service.isRunning();

                      if (isRunning) {
                        service.invoke('stopService');
                      } else {
                        await service.startService();
                      }
                    },
                    child: Text(startText),
                  ),
                  ElevatedButton(
                    key: keyButton5,
                    onPressed: () {
                      showDialog(
                          context: context,
                          builder: (builder) {
                            return AlertDialog(
                              title: Text(
                                  'Are you sure want to clear your tools list?'),
                              actions: [
                                TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                    child: Text('No')),
                                TextButton(
                                    onPressed: () {
                                      db!.remove();
                                      Navigator.pop(context);
                                    },
                                    child: Text('Yes'))
                              ],
                            );
                          });
                    },
                    child: Text('Clear All'),
                  )
                ],
              )
          ],
        ),
      ),
    );
  }
}
