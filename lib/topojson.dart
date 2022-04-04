enum TopoJsonObjectType {
  topology,
  point,
  multiPoint,
  lineString,
  multiLineString,
  polygon,
  multiPolygon,
  geometryCollection,
}

abstract class TopoJsonObject {
  TopoJsonObjectType get type;
  Map<String, dynamic>? get properties;

  const TopoJsonObject();

  static Map<String, dynamic>? _propFromJson(dynamic json) {
    final props = json['properties'];
    return props != null ? Map.castFrom(props) : null;
  }

  static TopoJsonObject fromJson(dynamic json, {required TopoJson topology}) {
    final String type = json['type'];
    switch (type) {
      case 'Topology':
        return TopoJson.fromJson(json);
      case 'Point':
        return TopoJsonPoint.fromJson(json);
      case 'MultiPoint':
        return TopoJsonMultiPoint.fromJson(json);
      case 'LineString':
        return TopoJsonLineString.fromJson(json, topology: topology);
      case 'MultiLineString':
        return TopoJsonMultiLineString.fromJson(json, topology: topology);
      case 'Polygon':
        return TopoJsonPolygon.fromJson(json, topology: topology);
      case 'MultiPolygon':
        return TopoJsonMultiPolygon.fromJson(json, topology: topology);
      case 'GeometryCollection':
        return TopoJsonGeometryCollection.fromJson(json, topology: topology);
      default:
        throw FormatException('Unknown object type: $type');
    }
  }

  Iterable<TopoJsonObject> iterateChildObjects();

  /// [determineObject] determines whether the iteration does continue or not by returning one of [GoSkipStopDecision] values.
  Iterable<TopoJsonObject> visitAllObjects({
    GoSkipStopDecision Function(TopoJsonObject object)? determineObject,
    bool recursive = true,
  }) =>
      _visitAllObjects(_GoSkipStopDeterminator(determineObject ?? (object) => GoSkipStopDecision.go),
          recursive: recursive);

  Iterable<TopoJsonObject> _visitAllObjects(
    _GoSkipStopDeterminator visitor, {
    bool recursive = true,
  }) sync* {
    for (final obj in iterateChildObjects()) {
      if (visitor.stop) break;
      final result = visitor.determineObject(obj);
      if (result == GoSkipStopDecision.stop) {
        visitor.stop = true;
        break;
      }
      if (result == GoSkipStopDecision.skip) continue;
      yield obj;
      if (result == GoSkipStopDecision.skipChildren || !recursive) continue;
      yield* obj._visitAllObjects(visitor, recursive: recursive);
    }
  }
}

class _GoSkipStopDeterminator {
  bool stop = false;
  final GoSkipStopDecision Function(TopoJsonObject object) determineObject;
  _GoSkipStopDeterminator(this.determineObject);
}

/// Determine iteration continuation.
enum GoSkipStopDecision {
  /// Continue iteration.
  go,

  /// Skip the object and it's children
  skip,

  /// Skip it's children. The object itself is processed (iterated).
  skipChildren,

  /// Stop the iteration process now.
  stop,
}

class TopoJson extends TopoJsonObject {
  @override
  TopoJsonObjectType get type => TopoJsonObjectType.topology;
  @override
  final Map<String, dynamic>? properties;

  final Map<String, TopoJsonObject> objects;
  final List arcs;
  final Transform transform;
  final List<num> bbox;

  const TopoJson({
    required this.objects,
    required this.arcs,
    required this.transform,
    required this.bbox,
    this.properties,
  });

  factory TopoJson.fromJson(dynamic json) {
    if (json['type'] != 'Topology') throw const FormatException('TopoJSON should have "Topology" type.');
    final tj = TopoJson(
      objects: <String, TopoJsonObject>{},
      arcs: _val(json, 'arcs'),
      transform: _transform(json),
      bbox: _val<List>(json, 'bbox').cast<num>(),
      properties: TopoJsonObject._propFromJson(json),
    );

    tj.objects.addEntries((json['objects'] as Map)
        .entries
        .map((kv) => MapEntry(kv.key, TopoJsonObject.fromJson(kv.value, topology: tj))));

    return tj;
  }

  @override
  Iterable<TopoJsonObject> iterateChildObjects() => objects.values;

  Iterable<List<num>> _getCoordsFromArcs(List arcs) {
    Iterable<List<num>>? it;
    for (final e in arcs) {
      if (it == null) {
        it = _getCoordsFromIndex(e);
      } else {
        it = it.followedBy(_getCoordsFromIndex(e).skip(1));
      }
    }
    return it ?? [];
  }

  /// Enumerate all the coordinates defined by `arcs`.
  Iterable<List<num>> _getCoordsFromIndex(int index) sync* {
    final isReversed = index < 0;
    final data = List.castFrom<dynamic, List>(arcs[isReversed ? ~index : index]);

    if (isReversed) {
      // First coord is the total of all the arcs entries
      final coord = data.fold<List<num>>(List.generate(data[0].length, (index) => 0, growable: false), _add);
      yield transform(coord);
      for (int i = data.length - 1; i > 0; i--) {
        yield transform(_subtract(coord, data[i]));
      }
    } else {
      final coord = data[0].cast<num>();
      yield transform(coord);
      for (int i = 1; i < data.length; i++) {
        yield transform(_add(coord, data[i]));
      }
    }
  }

  static Transform _transform(dynamic json) {
    final t = json['transform'];
    if (t == null) {
      return (coords) => coords; // identity transform
    }
    final scale = _val<List>(t, 'scale', context: 'transform').cast<num>();
    final translate = _val<List>(t, 'translate', context: 'transform').cast<num>();
    return (coords) =>
        List.generate(coords.length, (index) => coords[index] * scale[index] + translate[index], growable: false);
  }

  static T _val<T>(dynamic json, String name, {String? context}) {
    final v = json[name];
    if (v is T) return v;
    if (context != null) {
      throw FormatException('$context does not have field named "$name" of $T.');
    }
    throw FormatException('No field named "$name" of $T.');
  }

  static List<num> _add(List<num> accum, List delta) {
    final d = delta.cast<num>();
    for (int i = 0; i < accum.length; i++) {
      accum[i] += d[i];
    }
    return accum;
  }

  static List<num> _subtract(List<num> accum, List delta) {
    final d = delta.cast<num>();
    for (int i = 0; i < accum.length; i++) {
      accum[i] -= d[i];
    }
    return accum;
  }
}

typedef Transform = List<num> Function(List<num> coords);

class TopoJsonGeometryCollection extends TopoJsonObject {
  @override
  TopoJsonObjectType get type => TopoJsonObjectType.geometryCollection;
  @override
  final Map<String, dynamic>? properties;

  final List<TopoJsonObject> geometries;

  TopoJsonGeometryCollection({
    required this.geometries,
    required this.properties,
  });

  factory TopoJsonGeometryCollection.fromJson(
    dynamic json, {
    required TopoJson topology,
  }) =>
      TopoJsonGeometryCollection(
        geometries: (json['geometries'] as List)
            .map(
              (g) => TopoJsonObject.fromJson(
                g,
                topology: topology,
              ),
            )
            .toList(),
        properties: TopoJsonObject._propFromJson(json),
      );

  @override
  Iterable<TopoJsonObject> iterateChildObjects() => geometries;
}

class TopoJsonPoint extends TopoJsonObject {
  @override
  TopoJsonObjectType get type => TopoJsonObjectType.point;
  @override
  final Map<String, dynamic>? properties;

  final List<num> coordinates;

  TopoJsonPoint({
    required this.coordinates,
    this.properties,
  });

  factory TopoJsonPoint.fromJson(dynamic json) {
    return TopoJsonPoint(
      coordinates: ((json['coordinates'] as List).first as List).cast<num>(),
      properties: json['properties'],
    );
  }

  /// Do nothing for [TopoJsonPoint].
  @override
  Iterable<TopoJsonObject> iterateChildObjects() => const [];
}

class TopoJsonMultiPoint extends TopoJsonObject {
  @override
  TopoJsonObjectType get type => TopoJsonObjectType.multiPoint;
  @override
  final Map<String, dynamic>? properties;

  final List<TopoJsonPoint> points;

  TopoJsonMultiPoint({
    required this.points,
    this.properties,
  });

  factory TopoJsonMultiPoint.fromJson(dynamic json) {
    return TopoJsonMultiPoint(
      points: (json['coordinates'] as List).map((c) => TopoJsonPoint(coordinates: (c as List).cast<num>())).toList(),
      properties: json['properties'],
    );
  }

  @override
  Iterable<TopoJsonObject> iterateChildObjects() => points;
}

class TopoJsonLineString extends TopoJsonObject {
  @override
  TopoJsonObjectType get type => TopoJsonObjectType.lineString;
  @override
  final Map<String, dynamic>? properties;

  final List<List<num>> points;

  TopoJsonLineString({
    required this.points,
    this.properties,
  });

  factory TopoJsonLineString.fromJson(dynamic json, {required TopoJson topology}) {
    return TopoJsonLineString(
      points: topology._getCoordsFromArcs(json['arcs']).toList(),
      properties: json['properties'],
    );
  }

  /// Do noting for [TopoJsonLineString].
  @override
  Iterable<TopoJsonObject> iterateChildObjects() => const [];
}

class TopoJsonMultiLineString extends TopoJsonObject {
  @override
  TopoJsonObjectType get type => TopoJsonObjectType.multiLineString;
  @override
  final Map<String, dynamic>? properties;

  final List<TopoJsonLineString> lineStrings;

  TopoJsonMultiLineString({
    required this.lineStrings,
    this.properties,
  });

  factory TopoJsonMultiLineString.fromJson(dynamic json, {required TopoJson topology}) {
    return TopoJsonMultiLineString.fromArcs(
      json['arcs'],
      topology: topology,
      properties: json['properties'],
    );
  }

  factory TopoJsonMultiLineString.fromArcs(List arcs, {required TopoJson topology, Map<String, dynamic>? properties}) {
    return TopoJsonMultiLineString(
      lineStrings: arcs.map((a) => TopoJsonLineString(points: topology._getCoordsFromArcs(a).toList())).toList(),
      properties: properties,
    );
  }

  @override
  Iterable<TopoJsonObject> iterateChildObjects() => lineStrings;
}

class TopoJsonRing {
  final List<List<num>> points;
  const TopoJsonRing({required this.points});
  factory TopoJsonRing.fromJson(dynamic json, {required TopoJson topology}) {
    return TopoJsonRing(
      points: topology._getCoordsFromArcs(json['arcs']).toList(),
    );
  }
}

class TopoJsonPolygon extends TopoJsonObject {
  @override
  TopoJsonObjectType get type => TopoJsonObjectType.polygon;
  @override
  final Map<String, dynamic>? properties;

  final List<TopoJsonRing> rings;

  TopoJsonPolygon({
    required this.rings,
    this.properties,
  });

  factory TopoJsonPolygon.fromJson(dynamic json, {required TopoJson topology}) {
    return TopoJsonPolygon.fromArcs(
      json['arcs'],
      topology: topology,
      properties: json['properties'],
    );
  }

  factory TopoJsonPolygon.fromArcs(List arcs, {required TopoJson topology, Map<String, dynamic>? properties}) {
    return TopoJsonPolygon(
      rings: arcs.map((a) => TopoJsonRing(points: topology._getCoordsFromArcs(a).toList())).toList(),
      properties: properties,
    );
  }

  /// Do nothing for [TopoJsonPolygon].
  @override
  Iterable<TopoJsonObject> iterateChildObjects() => const [];
}

class TopoJsonMultiPolygon extends TopoJsonObject {
  @override
  TopoJsonObjectType get type => TopoJsonObjectType.multiPolygon;
  @override
  final Map<String, dynamic>? properties;

  final List<TopoJsonPolygon> polygons;

  TopoJsonMultiPolygon({
    required this.polygons,
    this.properties,
  });

  factory TopoJsonMultiPolygon.fromJson(dynamic json, {required TopoJson topology}) {
    return TopoJsonMultiPolygon(
      polygons: (json['arcs'] as List).map((a) => TopoJsonPolygon.fromArcs(a, topology: topology)).toList(),
      properties: json['properties'],
    );
  }

  @override
  Iterable<TopoJsonObject> iterateChildObjects() => polygons;
}
