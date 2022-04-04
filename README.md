# topojson

A Topojson parser.

```dart
final resp = await http.get(
    Uri.parse('https://geoshape.ex.nii.ac.jp/jma/resource/AreaInformationCity_landslide/20210518/4220201.topojson'));

final TopoJson.fromJson(jsonDecode(utf8.decode(resp.bodyBytes)));
```
