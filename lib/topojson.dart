library topojson;

/// The implementation is based on [topojson/topojson-client](https://github.com/topojson/topojson-client).
feature(topology, o) {
  final id = o.id;
  final bbox = o.bbox;
  final properties = o.properties ?? {};
  final geometry = _object(topology, o);
  return id == null && bbox == null
      ? {"type": "Feature", "properties": properties, "geometry": geometry}
      : bbox == null
          ? {"type": "Feature", "id": id, "properties": properties, "geometry": geometry}
          : {"type": "Feature", "id": id, "bbox": bbox, "properties": properties, "geometry": geometry};
}

_object(topology, o) {
  final transformPoint = _transform(topology.transform);
  final arcs = topology.arcs as List;

  void arc(int i, List<List<num>> points) {
    if (points.isNotEmpty) points.removeLast();
    final List a = arcs[i < 0 ? ~i : i];
    for (var k = 0; k < a.length; k++) {
      points.add(transformPoint(a[k], k));
    }
    if (i < 0) _reverse(points, a.length);
  }

  point(p) => transformPoint(p);

  line(List arcs) {
    final points = <List<num>>[];
    for (var i = 0, n = arcs.length; i < n; ++i) {
      arc(arcs[i], points);
    }
    if (points.length < 2) points.add(points[0]); // This should never happen per the specification.
    return points;
  }

  ring(List arcs) {
    final points = line(arcs);
    while (points.length < 4) {
      points.add(points[0]);
    } // This may happen if an arc has only two points.
    return points;
  }

  polygon(List arcs) => arcs.map((a) => ring(a)).toList();

  geometry(o) {
    final type = o.type;
    List coordinates;
    switch (type) {
      case "GeometryCollection":
        return {"type": type, "geometries": (o.geometries as List).map(geometry).toList()};
      case "Point":
        coordinates = point(o.coordinates);
        break;
      case "MultiPoint":
        coordinates = (o.coordinates as List).map(point).toList();
        break;
      case "LineString":
        coordinates = line(o.arcs);
        break;
      case "MultiLineString":
        coordinates = (o.arcs as List<List>).map(line).toList();
        break;
      case "Polygon":
        coordinates = polygon(o.arcs);
        break;
      case "MultiPolygon":
        coordinates = (o.arcs as List<List>).map(polygon).toList();
        break;
      default:
        return null;
    }
    return {"type": type, "coordinates": coordinates};
  }

  return geometry(o);
}

typedef _Transform = List<num> Function(List<num>, [int?]);

List<num> _identity(List<num> x, [int? i]) => x;

_Transform _transform(transform) {
  if (transform == null) return _identity;
  num x0 = 0.0, y0 = 0.0;
  final num kx = transform.scale[0];
  final num ky = transform.scale[1];
  final num dx = transform.translate[0];
  final num dy = transform.translate[1];

  return (List<num> input, [int? i]) {
    if (i == null) x0 = y0 = 0;
    final n = input.length;
    final output = <num>[];
    output.add((x0 += input[0]) * kx + dx);
    output.add((y0 += input[1]) * ky + dy);
    for (int j = 2; j < n; j++) {
      output.add(input[j]);
    }
    return output;
  };
}

void _reverse<T>(List<T> array, int n) {
  var j = array.length;
  var i = j - n;
  while (i < --j) {
    final t = array[i];
    array[i++] = array[j];
    array[j] = t;
  }
}
