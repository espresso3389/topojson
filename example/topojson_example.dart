import 'dart:convert';
import 'dart:io' as io;

import 'package:http/http.dart' as http;
import 'package:topojson/topojson.dart';

void main() async {
  /// Testing topojson to geojson conversion;
  final resp = await http.get(
      Uri.parse('https://geoshape.ex.nii.ac.jp/jma/resource/AreaInformationCity_landslide/20210518/4220201.topojson'));
  final topoJson = jsonDecode(utf8.decode(resp.bodyBytes));

  final f = feature(topoJson, topoJson['objects']['area']);
  final geoJson = jsonEncode(f);

  await io.File('4220201.geojson').writeAsString(geoJson);
}
