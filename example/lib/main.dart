import 'dart:convert';
import 'dart:ui';

import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

import 'package:topojson/topojson.dart';

void main() async {
  final resp = await http.get(Uri.parse(
      'https://geoshape.ex.nii.ac.jp/jma/resource/AreaInformationCity_landslide/20210518/4220201.topojson'));
  final json = jsonDecode(utf8.decode(resp.bodyBytes));
  final tj = TopoJson.fromJson(json);

  runApp(MyApp(
    topojson: tj,
  ));
}

class MyApp extends StatelessWidget {
  final TopoJson topojson;
  const MyApp({Key? key, required this.topojson}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    final bbox = topojson.bbox.map((n) => n.toDouble()).toList();
    final rect = Rect.fromLTRB(bbox[0], bbox[1], bbox[2], bbox[3]);
    return MaterialApp(
      title: 'Flutter Demo',
      home: Scaffold(
        body: LayoutBuilder(builder: (context, constraints) {
          return Container(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            //color: Colors.blue,
            child: CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: TopoJsonPainter(topojson, rect),
            ),
          );
        }),
      ),
    );
  }
}

class TopoJsonPainter extends CustomPainter {
  final TopoJson topojson;
  final Rect rect;
  const TopoJsonPainter(this.topojson, this.rect);

  /// NOTE: This sample draws the geometry data without any coordinate conversion/correction; testing purpose only.
  @override
  void paint(Canvas canvas, Size size) {
    for (final object in topojson.visitAllObjects()) {
      if (object.type == TopoJsonObjectType.polygon) {
        final paint = Paint()
          ..color = Colors.redAccent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5;
        // Draw as if lat/lng values were in cartesian coordinate system
        for (final ring in (object as TopoJsonPolygon).rings) {
          canvas.drawPoints(
              PointMode.polygon,
              ring.points
                  .map((p) => Offset(
                        (p[0].toDouble() - rect.left) / rect.width * size.width,
                        (p[1].toDouble() - rect.top) /
                            rect.height *
                            size.height,
                      ))
                  .toList(),
              paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
