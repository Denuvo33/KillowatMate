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
  Gemini.init(apiKey: 'AIzaSyCPv3EnoImMB1AJn1z_iMqoLs25LsNkzFs');
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
          initialNotificationTitle: 'Energy Saver',
          initialNotificationContent: 'Service is Start',
          isForegroundMode: true));
  // service.startService();
}

@pragma('vm:enry:point')
void onStart(ServiceInstance service) async {
  var uid = FirebaseAuth.instance.currentUser!.uid;
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  DartPluginRegistrant.ensureInitialized();
  DatabaseReference db = FirebaseDatabase.instance.ref('users/$uid');

  int lastUpdateTime = 0;
  num totalDailyKwh = 0;
  void fetchDataAndUpdate() async {
    db.onValue.listen((event) {
      var data = event.snapshot.value;
      if (data != null && data is Map) {
        totalDailyKwh = data['totalDailyKwh'];
      }
    });
    db.child('tools').once().then((event) {
      var data = event.snapshot.value;
      if (data != null && data is Map) {
        data.forEach((key, value) async {
          var condition = value['condition'];
          if (condition) {
            var watt = value['watt'];
            var amount = value['amount'];
            var totalkwh = value['totalKwh'];
            totalkwh += (watt * 2 / 1000) * amount;
            totalDailyKwh += totalkwh;
            db.child('$key').update({'totalKwh': totalkwh});
            db.update({'totalDailyKwh': totalDailyKwh});
          }
        });
      }
    });

    flutterLocalPlugin.show(
      90,
      "Energy Saver",
      'Total Daily kWh is $totalDailyKwh',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'Energy Saver Foreground',
          'Energy Saver Foreground Service',
          ongoing: true,
        ),
      ),
    );
  }

  service.on('setAsForeground').listen((event) {
    debugPrint('This is Foreground =======');
    fetchDataAndUpdate();
  });

  Timer.periodic(Duration(seconds: 5), (timer) {
    if (DateTime.now().millisecondsSinceEpoch - lastUpdateTime >= 5000) {
      fetchDataAndUpdate();
    }
  });

  service.on('setAsBackground').listen((event) {
    debugPrint('This is Background =======');
  });

  service.on('stopService').listen((event) {
    service.stopSelf();
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: AuthPage(),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
          appBarTheme: AppBarTheme(color: Colors.cyan),
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
  List<ElectronicModel> toolsList = [];
  final TextEditingController _watts = TextEditingController();
  final TextEditingController _amount = TextEditingController();
  String toolsValue = 'AC';
  List<String> listDayOrMonth = ['Daily', 'month'];
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
    super.initState();
    getData();
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
                        var result =
                            num.parse(_amount.text) * num.parse(_watts.text);

                        db!.child('$toolsValue ${_watts.text} watts').update({
                          'watt': num.parse(_watts.text),
                          'name': toolsValue,
                          'amount': num.parse(_amount.text),
                          'condition': true,
                          'runTime': 0,
                          'totalKwh': result
                        });
                        _amount.clear();
                        _watts.clear();
                        toolsValue = 'AC';
                        Navigator.pop(context);
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
          thisMonthKwh = data['thisMonthKwh'] + totalDailyKwh;
          maxDailyKwh = data['maxDailyKwh'];
          userName = data['username'];
          thisMonth = data['month'];
          if (thisMonth != monthName) {
            dbTotal.update({'month': monthName});
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

  @override
  Widget build(BuildContext context) {
    var startText = 'Start';
    return Scaffold(
      appBar: AppBar(
        title: Text('KillowatMate'),
        actions: [IconButton(onPressed: () {}, icon: Icon(Icons.info))],
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
          onTap: () {},
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
                  color: Colors.tealAccent,
                  child: Container(
                    margin: const EdgeInsets.all(7),
                    child: Column(
                      children: [
                        Text('Max Daily kWh',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(maxDailyKwh == 0 ? 'Nothing' : '$maxDailyKwh kWh'),
                      ],
                    ),
                  ),
                ),
                Card(
                  color: Colors.tealAccent,
                  child: Container(
                    width: 80,
                    margin: const EdgeInsets.all(7),
                    child: Column(
                      children: [
                        Text(
                          'Today',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text('$totalDailyKwh kWh')
                      ],
                    ),
                  ),
                ),
                Card(
                  color: Colors.tealAccent,
                  child: Container(
                    width: 80,
                    margin: const EdgeInsets.all(7),
                    child: Column(
                      children: [
                        Text(thisMonth,
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('$thisMonthKwh kWh')
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
                          onPressed: () {
                            /*  Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (ctx) => CreatePage()));*/
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
                                      'Total Watts: ${toolsList[index].totalToolsKwh}',
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
                  ElevatedButton(
                      onPressed: () async {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Not Available Right Now')));
                      },
                      child: Row(
                        children: [
                          Icon(Icons.timer),
                          Text(startText),
                        ],
                      )),
                  ElevatedButton(
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
                      child: Row(
                        children: [
                          Icon(Icons.delete_forever),
                          Text('Clear All'),
                        ],
                      ))
                ],
              )
          ],
        ),
      ),
    );
  }
}
