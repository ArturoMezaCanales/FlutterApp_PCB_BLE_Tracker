// Copyright 2018 The Flutter team. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import "package:flutter/material.dart";
import "package:flutter_map/flutter_map.dart";
import 'package:latlong2/latlong.dart';
import "package:http/http.dart" as http;
import "dart:convert" as convert;




class MyMap extends StatefulWidget {
    const MyMap({super.key});


  @override
  State<MyMap> createState() => MyMapPage();

}
class MyMapPage extends State<MyMap> {
  final String apiKey = "YOUR_API_KEY";
  @override
  Widget build(BuildContext context) {
    final tomtomHQ = new LatLng(52.376372, 4.908066);
    return MaterialApp(
      title: "TomTom Map",
      home: Scaffold(
        body: Center(
            child: Stack(
              children: <Widget>[
                FlutterMap(
                  options: MapOptions(
                    initialCenter: tomtomHQ,
                    initialZoom: 13.0
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: "https://api.tomtom.com/map/1/tile/basic/main/{z}/{x}/{y}.png?key=WFLOoq3UtrJgFrvbCmLlBhXpPAQCaII4",
                      additionalOptions: {
                        "apiKey": apiKey,
                      },
                    ),
                  ],
                )
              ],
            )),
      ),
    );
  }
}