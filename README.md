# topojson

A Dart port of [topojson/topojson-client](https://github.com/topojson/topojson-client).

It only implements `feature` function that can be used to convert TopoJSON to GeoJSON.

```dart
/// topojson to geojson conversion
final resp = await http.get(
    Uri.parse('https://geoshape.ex.nii.ac.jp/jma/resource/AreaInformationCity_landslide/20210518/4220201.topojson'));
final topoJson = jsonDecode(utf8.decode(resp.bodyBytes));

final f = feature(topoJson, topoJson['objects']['area']);
final geoJson = jsonEncode(f);

await io.File('4220201.geojson').writeAsString(geoJson);
```
