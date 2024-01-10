import 'package:background_service/auth/sign_in_page.dart';
import 'package:background_service/main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController _username = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  DatabaseReference db = FirebaseDatabase.instance.ref('users');
  bool _visible = true;

  createAccount(String username, String email, String password) async {
    DateTime currentDate = DateTime.now();
    int month = currentDate.month;

    String monthName =
        DateFormat.MMMM().format(DateTime(currentDate.year, month));

    try {
      await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      debugPrint('success create account');
      var auth = FirebaseAuth.instance.currentUser!.uid;
      await db.child(auth).update({
        'month': monthName,
        'username': username,
        'maxDailyKwh': 0,
        'thisMonthKwh': 0,
        'totalDailyKwh': 0,
      });

      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (ctx) => HomePage()));
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Password To Weak')));
      } else if (e.code == 'email-already-in-use') {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Email Already in Use')));
      } else {
        debugPrint('something went wrong ${e.message}');
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('your email is not valid')));
      }
      setState(() {
        _visible = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Something went wrong,$e ')));
      setState(() {
        _visible = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('KillowatMate'),
        ),
        body: Visibility(
          visible: _visible,
          replacement: Center(child: CircularProgressIndicator()),
          child: Container(
            margin: EdgeInsets.all(10),
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Create Account',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 27),
                    ),
                    SizedBox(
                      height: 40,
                    ),
                    TextField(
                      controller: _username,
                      decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Username',
                          prefixIcon: Icon(Icons.person)),
                    ),
                    SizedBox(
                      height: 20,
                    ),
                    TextField(
                      controller: _email,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Email',
                        prefixIcon: Icon(Icons.email),
                      ),
                    ),
                    SizedBox(
                      height: 20,
                    ),
                    TextField(
                      controller: _password,
                      obscureText: true,
                      decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Password',
                          prefixIcon: Icon(Icons.lock)),
                    ),
                    SizedBox(
                      height: 20,
                    ),
                    ElevatedButton(
                        onPressed: () {
                          if (_username.text.isEmpty ||
                              _email.text.isEmpty ||
                              _password.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Empty text not allowed')));
                          } else {
                            setState(() {
                              _visible = false;
                            });
                            createAccount(
                                _username.text, _email.text, _password.text);
                          }
                        },
                        child: Text('Create Account')),
                    SizedBox(
                      height: 10,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Already Have Account?'),
                        TextButton(
                            onPressed: () {
                              Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                      builder: (ctx) => SignInPage()));
                            },
                            child: Text('Sign In'))
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        ));
  }
}
