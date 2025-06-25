import 'package:flutter/material.dart';


class TheHomePage extends StatefulWidget {
  const TheHomePage({super.key});


  @override
  State<TheHomePage> createState() => HomePageFunction();

}

class HomePageFunction extends State<TheHomePage> {

@override
  Widget build(BuildContext context) {
    
    return Scaffold(
      appBar: AppBar(
       
        backgroundColor: const Color.fromARGB(255, 182, 149, 49),
        title: Text('title'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),       
          ],
        ),
      ),
      
    );
  }

}

