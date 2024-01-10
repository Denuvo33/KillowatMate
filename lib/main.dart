import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:background_service/auth/auth_check.dart';
import 'package:background_service/auth/sign_in_page.dart';
import 'package:background_service/electronic_model.dart';
import 'package:background_service/firebase_options.dart';
import 'package:background_service/page/calculate_page.dart';
import 'package:background_service/page/create_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  DartPluginRegistrant.ensureInitialized();
  DatabaseReference db = FirebaseDatabase.instance.ref('users/1/tools');

  int lastUpdateTime = 0;
  num totalDailyKwh = 0;
  void fetchDataAndUpdate() async {
    db.once().then((event) {
      var data = event.snapshot.value;
      if (data != null && data is Map) {
        totalDailyKwh = data['totalDailyKwh'];
        data.forEach((key, value) async {
          var watt = value['watt'];
          var amount = value['amount'];
          var totalkwh = value['totalKwh'];
          totalkwh += (watt * 2 / 1000) * amount;
          totalDailyKwh += totalkwh;
          db.child('$key').update({'totalKwh': totalkwh});
          db.update({'totalDailyKwh': totalDailyKwh});
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
    // Fetch data only if 5 seconds have passed since the last update
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
  bool showList = false;
  DatabaseReference? db;
  var uid = FirebaseAuth.instance.currentUser!.uid;
  var auth = FirebaseAuth.instance;
  var userName = 'aa';
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    getData();
  }

  getData() {
    DatabaseReference dbTotal = FirebaseDatabase.instance.ref('users/$uid');
    dbTotal.onValue.listen((event) {
      var data = event.snapshot.value;
      debugPrint('value is $data');
      if (data != null && data is Map) {
        setState(() {
          totalDailyKwh = data['totalDailyKwh'];
          thisMonthKwh = data['thisMonthKwh'];
          maxDailyKwh = data['maxDailyKwh'];
          userName = data['username'];
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
          var totalLampKwh = value['totalKwh'];
          var amount = value['amount'];
          var image = value['image'];
          var condition = value['condition'];

          setState(() {
            toolsList.add(ElectronicModel(
                name: name,
                id: name,
                amount: amount,
                totalToolsKwh: totalLampKwh,
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
                    margin: const EdgeInsets.all(7),
                    child: Column(
                      children: [
                        Text('This Month',
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
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (ctx) => CreatePage()));
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
                                            Navigator.pop(context);
                                          },
                                          child: Text('Yes'))
                                    ],
                                  );
                                });
                          },
                          child: Container(
                            child: Card(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Column(
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.info),
                                          Text(
                                            toolsList[index].condition!
                                                ? 'Running'
                                                : 'Stopped',
                                            style: TextStyle(
                                                color:
                                                    toolsList[index].condition!
                                                        ? Colors.green
                                                        : Colors.red,
                                                fontWeight: FontWeight.bold),
                                          )
                                        ],
                                      ),
                                      SizedBox(
                                        height: 3,
                                      ),
                                      SizedBox(
                                        width: 100,
                                        child: Image.network(
                                          toolsList[index].image!,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      // Text('Hold For Delete')
                                    ],
                                  ),
                                  SizedBox(
                                    width: 10,
                                  ),
                                  Column(
                                    children: [
                                      Text(
                                        toolsList[index].name.toString(),
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15),
                                      ),
                                      Text('Watt: ${toolsList[index].watt}'),
                                      Text(
                                          'Amount: ${toolsList[index].amount}'),
                                      if (toolsList[index].amount! == 1)
                                        Text('Time Running:'),
                                      Divider(),
                                      SizedBox(
                                        height: 3,
                                      ),
                                      Text(
                                        'Total kWh: ${toolsList[index].totalToolsKwh}',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold),
                                      )
                                    ],
                                  ),
                                  const Spacer(),
                                  Switch(
                                      value: toolsList[index].condition!,
                                      onChanged: ((value) {
                                        setState(() {
                                          toolsList[index].condition = value;
                                        });
                                      }))
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    Container(
                      margin: const EdgeInsets.all(20),
                      child: FloatingActionButton(
                        onPressed: () {},
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
                      onPressed: () {},
                      child: Row(
                        children: [
                          Icon(Icons.calculate),
                          Text('Calculate'),
                        ],
                      )),
                  ElevatedButton(
                      onPressed: () {},
                      child: Row(
                        children: [
                          Icon(Icons.timer),
                          Text('Start'),
                        ],
                      )),
                  ElevatedButton(
                      onPressed: () {},
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
