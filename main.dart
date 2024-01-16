import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:harita_proje/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
runApp(MyApp());
}
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController mapController;
  final Set<Marker> markerlar = {};
  final Set<Polygon> polygons = {};

  late TextEditingController buildingNameController;
  String binaHasar = 'Hafif';

 
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    buildingNameController = TextEditingController();

    getMarker();
  }

 
 void getMarker() {
  _firestore.collection('binalar').snapshots().listen((QuerySnapshot querySnapshot) {
    setState(() {
      markerlar.clear();
      polygons.clear();
    });

    querySnapshot.docs.forEach((doc) {
      double lat = doc['lat'];
      double lng = doc['lng'];
      LatLng position = LatLng(lat, lng);

      String binaname = doc['binaAdı'];
      String category = doc['hasar'].toLowerCase(); 

      markerEkle(position, binaname, category);
    });
  });
}
  Future<void> mapTiklandi(LatLng position) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Bina Detayları'),
          content: Column(
            children: [
              TextField(
                controller: buildingNameController,
                decoration: InputDecoration(labelText: 'Bina Adı'),
              ),
              DropdownButton<String>(
                value: binaHasar,
                onChanged: (String? value) {
                  setState(() {
                    binaHasar = value!;
                  });
                },
                items: <String>['Hafif', 'Orta', 'Agir']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('İptal'),
            ),
            TextButton(
              onPressed: () {
                saveMarker(position, buildingNameController.text, binaHasar);
                Navigator.pop(context);
              },
              child: Text('Ekle'),
            ),
          ],
        );
      },
    );
  }

  void markerEkle(LatLng position, String binaname, String category) {
    Marker marker = Marker(
      markerId: MarkerId(position.toString()),
      position: position,
      infoWindow: InfoWindow(title: binaname, snippet: category),
      icon: _getMarkerIcon(category),
    );

    setState(() {
      markerlar.add(marker);
    });

    _drawPolygon(category);
  }

 void saveMarker(LatLng position, String binaname, String category) {
  _firestore.collection('binalar').add({
    'lat': position.latitude,
    'lng': position.longitude,
    'binaAdı': binaname,
    'hasar': category, 
  });
}

  BitmapDescriptor _getMarkerIcon(String category) {
    double hue;
    switch (category) {
      case 'hafif':
        hue = 120.0; 
        break;
      case 'orta':
        hue = 30.0; 
        break;
      case 'agir':
        hue = 0.0; 
        break;
      default:
        hue = 240.0; 
    }

    return BitmapDescriptor.defaultMarkerWithHue(hue);
  }

  void _drawPolygon(String category) {
  List<LatLng> polygonPoints = markerlar
      .where((marker) => marker.infoWindow!.snippet!.toLowerCase() == category.toLowerCase())
      .map((marker) => marker.position)
      .toList();

  Color polygonFillColor;
  Color polygonStrokeColor;

  switch (category.toLowerCase()) {
    case 'hafif':
      polygonFillColor = Colors.green.withOpacity(0.5);
      polygonStrokeColor = Colors.green;
      break;
    case 'orta':
      polygonFillColor = Colors.orange.withOpacity(0.5);
      polygonStrokeColor = Colors.orange;
      break;
    case 'agir':
      polygonFillColor = Colors.red.withOpacity(0.5);
      polygonStrokeColor = Colors.red;
      break;
    default:
      polygonFillColor = Colors.blue.withOpacity(0.5);
      polygonStrokeColor = Colors.blue;
  }

  Polygon polygon = Polygon(
    polygonId: PolygonId(category),
    points: polygonPoints,
    fillColor: polygonFillColor,
    strokeColor: polygonStrokeColor,
    strokeWidth: 2,
  );

  setState(() {
    polygons.removeWhere((element) => element.polygonId == PolygonId(category));
    polygons.add(polygon);
  });
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Halil Yuşa Ağca Hasar Haritası'),
      ),
      body: GoogleMap(
        onMapCreated: (GoogleMapController controller) {
          mapController = controller;
        },
        onTap: mapTiklandi,
        markers: markerlar,
        polygons: polygons,
        initialCameraPosition: CameraPosition(
          target: LatLng(38.356869, 38.309669),
          zoom: 12,
        ),
      ),
    );
  }
}
