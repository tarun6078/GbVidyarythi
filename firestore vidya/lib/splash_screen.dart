import 'package:flutter/material.dart';
import 'dart:async';

import 'main.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(
      Duration(seconds: 5), // Adjust the duration as needed
          () {
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (context) => MyApp(),
        ));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Replace this Image.asset with your student logo
            Image.asset(
              'assets/logo.png', // Update the image path
              width: 100.0, // Adjust the size as needed
              height: 100.0,
            ),
            SizedBox(height: 20.0),
            Text(
              'Welcome To Vidyarthi App',
              style: TextStyle(fontSize: 24),
            ),
          ],
        ),
      ),
    );
  }
}
