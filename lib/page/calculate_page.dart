import 'package:background_service/electronic_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';

class CalculatePage extends StatefulWidget {
  const CalculatePage({super.key});

  @override
  State<CalculatePage> createState() => _CalculatePageState();
}

class _CalculatePageState extends State<CalculatePage> {
  final TextEditingController _watts = TextEditingController();
  final TextEditingController _hours = TextEditingController();
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _maxkWh = TextEditingController();
  final gemini = Gemini.instance;
  String prompt = '';
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

  calculatingDialog(BuildContext ctx) async {
    var suggest = '';
    showDialog(
        context: ctx,
        barrierDismissible: false,
        builder: (builder) {
          return AlertDialog(
            actions: [
              TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                  },
                  child: Text('Close')),
            ],
            content: Container(
              height: 150,
              child: Column(
                children: [
                  Text(
                      'Calculating(This my take time so dont press Close button)'),
                  CircularProgressIndicator()
                ],
              ),
            ),
          );
        });

    num totalToolsKwh = 0;

    myTools.forEach((element) {
      totalToolsKwh += element.watt! * element.hours! / 1000;
    });

    myTools.forEach((tool) {
      prompt +=
          "${tool.amount} ${tool.name} ${tool.totalToolsKwh} watts and used for ${tool.hours} hours per day, ";
    });

    prompt = prompt.substring(0, prompt.length - 2);

    if (totalToolsKwh > num.parse(_maxkWh.text)) {
      gemini
          .text(
              'i set my max kWh to $_maxkWh for daily,and i use this electronic tools : $prompt, and the result is the total kWh from those tools is more than just i set for my max kWh before,what the usage tools should i reduce from that?,and give me advice to save energy usage')
          .then((value) {
        suggest = '${value?.output}';

        Navigator.pop(ctx);
        showDialog(
            context: context,
            barrierDismissible: false,
            builder: (builder) {
              return AlertDialog(
                title: Text('Result'),
                actions: [
                  TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: Text('Close'))
                ],
                content: SingleChildScrollView(
                  child: Container(
                    child: Text(suggest),
                  ),
                ),
              );
            });
      });
    } else {
      await Future.delayed(Duration(seconds: 3));
      Navigator.pop(ctx);
    }
  }

  setKwhFun(BuildContext ctx) {
    showDialog(
        barrierDismissible: false,
        context: ctx,
        builder: (builder) {
          return StatefulBuilder(
              builder: (BuildContext ctx, StateSetter setState) {
            return AlertDialog(
              title: const Text('Set your max kWh'),
              actions: [
                TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                    },
                    child: const Text('Close')),
                TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      calculatingDialog(context);
                    },
                    child: const Text('Confirm'))
              ],
              content: Container(
                height: 200,
                child: Column(
                  children: [
                    const Text(
                        'In here you should set your max daily kWh you want to use,so we can calculate your tools usage. If your tools reach the max limit,we can suggest you some help based on your data'),
                    TextField(
                      controller: _maxkWh,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                          labelText: 'set your max kWh', suffix: Text('kWh')),
                    )
                  ],
                ),
              ),
            );
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Calculate'),
      ),
      body: Container(
        margin: EdgeInsets.all(10),
        child: Column(
          children: [
            Text(
                'Here if you want to calculate all of your Electronic Usage without using it and you will know how much Kwh per day you use it.'),
            SizedBox(
              height: 20,
            ),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () {
                    showDialog(
                        barrierDismissible: false,
                        context: context,
                        builder: (builder) {
                          return StatefulBuilder(builder:
                              (BuildContext context, StateSetter setstate) {
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
                                    TextField(
                                      controller: _hours,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText:
                                            'How long will this stay on?',
                                        suffixText: 'Hours',
                                        helperText: 'in hours',
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
                                      if (_amount.text.isEmpty ||
                                          _hours.text.isEmpty ||
                                          _watts.text.isEmpty) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                                content:
                                                    Text('Fill all required')));
                                      } else {
                                        var result = num.parse(_amount.text) *
                                            num.parse(_watts.text);
                                        setState(() {
                                          myTools.add(ElectronicModel(
                                              name: toolsValue,
                                              id: toolsValue,
                                              image: '',
                                              hours: int.parse(_hours.text),
                                              amount: num.parse(_amount.text),
                                              totalToolsKwh: result,
                                              condition: false,
                                              watt: num.parse(_watts.text)));
                                        });
                                        _amount.clear();
                                        _hours.clear();
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
                  },
                  child: Row(
                    children: [
                      Icon(Icons.handyman),
                      Text('Add your tools'),
                    ],
                  ),
                ),
              ],
            ),
            Expanded(
              child: ListView.builder(
                itemCount: myTools.length,
                itemBuilder: (BuildContext context, int index) {
                  return Column(
                    children: [
                      ListTile(
                        onTap: () {
                          showDialog(
                              context: context,
                              builder: (builder) {
                                return AlertDialog(
                                  title:
                                      Text('Are you sure want to delete it?'),
                                  actions: [
                                    TextButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                        },
                                        child: Text('No')),
                                    TextButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          setState(() {
                                            myTools.removeAt(index);
                                          });
                                        },
                                        child: Text('Yes')),
                                  ],
                                );
                              });
                        },
                        leading: Icon(Icons.delete),
                        title: Text(
                            '${myTools[index].name} ${myTools[index].watt} watts'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Tools Amount: ${myTools[index].amount}x'),
                            Text(
                                'Total watts: ${myTools[index].totalToolsKwh}watts'),
                          ],
                        ),
                        trailing: Text('${myTools[index].hours} Hours'),
                      ),
                      Divider()
                    ],
                  );
                },
              ),
            ),
            Visibility(
              visible: myTools.isNotEmpty,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                      onPressed: () {
                        setState(() {
                          myTools = [];
                        });
                      },
                      child: Text('Clear')),
                  ElevatedButton(
                      onPressed: () {
                        setKwhFun(context);
                      },
                      child: Text('Calculate'))
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
