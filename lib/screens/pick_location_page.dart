// -------------------------------------------------------------
// PICK LOCATION PAGE — FIXED VERSION (NO google_place PLUGIN)
// -------------------------------------------------------------
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'address_type_page.dart';

const _placesApiKey = 'AIzaSyADsxWf0_pAhv8BOQ1oXWefCuj-PJP7qCY';

class PickLocationPage extends StatefulWidget {
  const PickLocationPage({super.key});

  @override
  State<PickLocationPage> createState() => _PickLocationPageState();
}

class _PickLocationPageState extends State<PickLocationPage> {
  final _mapController = Completer<GoogleMapController>();
  final TextEditingController _searchController = TextEditingController();

  // Larnaca bounds
  final LatLng _larnacaCenter = const LatLng(34.9167, 33.6333);
  static const _larnacaRadiusMeters = 30000;

  LatLng _picked = const LatLng(34.9167, 33.6333);
  LatLng _lastValid = const LatLng(34.9167, 33.6333);

  String _address = '';
  bool _loading = false;

  List<Map<String, dynamic>> _predictions = [];
  Placemark? _lastPlacemark;

  bool _isInsideLarnaca(LatLng p) {
    final d = Geolocator.distanceBetween(
      _larnacaCenter.latitude,
      _larnacaCenter.longitude,
      p.latitude,
      p.longitude,
    );
    return d <= _larnacaRadiusMeters;
  }

  void _rejectOutside() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('We currently deliver only within Larnaca.')),
    );
  }

  // -------------------------------------------------------------------------
  // AUTOCOMPLETE — REST CALL
  // -------------------------------------------------------------------------
  Future<void> _searchPlaces(String input) async {
    final url =
        "https://maps.googleapis.com/maps/api/place/autocomplete/json"
        "?input=$input"
        "&key=$_placesApiKey"
        "&components=country:cy"
        "&location=${_larnacaCenter.latitude},${_larnacaCenter.longitude}"
        "&radius=$_larnacaRadiusMeters";

    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) return;

    final data = jsonDecode(response.body);
    final preds = data["predictions"] ?? [];

    setState(() {
      _predictions = List<Map<String, dynamic>>.from(preds);
    });
  }

  // -------------------------------------------------------------------------
  // PLACE DETAILS — REST CALL
  // -------------------------------------------------------------------------
  Future<void> _selectPrediction(Map<String, dynamic> p) async {
    final placeId = p["place_id"];
    final url =
        "https://maps.googleapis.com/maps/api/place/details/json"
        "?place_id=$placeId"
        "&key=$_placesApiKey";

    final response = await http.get(Uri.parse(url));
    final data = jsonDecode(response.body);

    final loc = data["result"]["geometry"]["location"];
    final lat = loc["lat"] * 1.0;
    final lng = loc["lng"] * 1.0;

    final pos = LatLng(lat, lng);

    if (!_isInsideLarnaca(pos)) {
      _rejectOutside();
      return;
    }

    final controller = await _mapController.future;
    controller.animateCamera(CameraUpdate.newLatLngZoom(pos, 16));

    setState(() {
      _picked = pos;
      _lastValid = pos;
      _predictions = [];
      _searchController.text = p["description"];
      _address = data["result"]["formatted_address"] ?? "Selected location";
    });
  }

  // -------------------------------------------------------------------------
  // REVERSE GEOCODING
  // -------------------------------------------------------------------------
  Future<void> _reverseGeocode(LatLng pos) async {
    setState(() => _loading = true);

    try {
      final list = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (list.isNotEmpty) {
        _lastPlacemark = list.first;
        setState(() {
          _address =
          "${list.first.street}, ${list.first.locality}, ${list.first.administrativeArea}";
        });
      }
    } catch (_) {
      setState(() => _address = "Unable to get address");
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _reverseGeocode(_picked);
    _searchController.addListener(() {
      final t = _searchController.text.trim();
      if (t.isEmpty) {
        setState(() => _predictions = []);
        return;
      }
      _searchPlaces(t);
    });
  }

  // -------------------------------------------------------------------------
  // USE MY LOCATION
  // -------------------------------------------------------------------------
  Future<void> _useMyLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (!serviceEnabled || permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Location not available")),
      );
      return;
    }

    final pos = await Geolocator.getCurrentPosition();
    final p = LatLng(pos.latitude, pos.longitude);

    if (!_isInsideLarnaca(p)) {
      _rejectOutside();
      return;
    }

    final controller = await _mapController.future;
    controller.animateCamera(CameraUpdate.newLatLngZoom(p, 16));

    setState(() => _picked = p);
    _reverseGeocode(p);
  }

  // -------------------------------------------------------------------------
  // SAVE TO FIRESTORE
  // -------------------------------------------------------------------------
  Future<Map<String, dynamic>> _saveAddressToFirestore({
    required String label,
    required String line1,
    required String city,
    required String country,
    required double lat,
    required double lng,
    required String type,
    required Map<String, dynamic> details,
    bool setAsDefault = true,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Not signed in");

    final col = FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("addresses");

    final doc = col.doc();

    final data = {
      "id": doc.id,
      "label": label,
      "line1": line1,
      "city": city,
      "country": country,
      "lat": lat,
      "lng": lng,
      "geo": GeoPoint(lat, lng),
      "type": type,
      "details": details,
      "isDefault": false,
      "timestamp": FieldValue.serverTimestamp(),
    };

    if (setAsDefault) {
      final batch = FirebaseFirestore.instance.batch();
      final all = await col.get();
      for (var d in all.docs) {
        batch.update(d.reference, {"isDefault": false});
      }
      batch.set(doc, {...data, "isDefault": true});
      await batch.commit();
    } else {
      await doc.set(data);
    }

    return {...data, "isDefault": setAsDefault};
  }

  // -------------------------------------------------------------------------
  // UI
  // -------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Pick Location",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/background/fade_base.jpg',
              fit: BoxFit.cover,
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 8),

                // SEARCH
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: "Search address in Larnaca...",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

                if (_predictions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      itemCount: _predictions.length,
                      itemBuilder: (_, i) {
                        final p = _predictions[i];
                        return ListTile(
                          title: Text(
                            p["description"],
                            style: const TextStyle(color: Colors.black),
                          ),
                          onTap: () => _selectPrediction(p),
                        );
                      },
                    ),
                  ),

                // MAP
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            GoogleMap(
                              initialCameraPosition: CameraPosition(
                                target: _picked,
                                zoom: 14,
                              ),
                              onMapCreated: (c) => _mapController.complete(c),
                              onTap: (p) {
                                if (!_isInsideLarnaca(p)) {
                                  _rejectOutside();
                                  return;
                                }
                                setState(() => _picked = p);
                                _reverseGeocode(p);
                              },
                              onCameraMove: (p) => _picked = p.target,
                              onCameraIdle: () async {
                                if (!_isInsideLarnaca(_picked)) {
                                  _rejectOutside();
                                  final c = await _mapController.future;
                                  c.animateCamera(CameraUpdate.newLatLng(_lastValid));
                                  return;
                                }
                                _lastValid = _picked;
                                _reverseGeocode(_picked);
                              },
                            ),
                            const Icon(Icons.location_on, size: 40, color: Color(0xFFC70418)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ADDRESS
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : Text(
                      _address,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // CONFIRM BUTTON
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: ElevatedButton(
                    onPressed: () async {
                      if (!_isInsideLarnaca(_picked)) {
                        _rejectOutside();
                        return;
                      }

                      final structured = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddressTypePage(
                            lat: _picked.latitude,
                            lng: _picked.longitude,
                            formatted: _address,
                            city: _lastPlacemark?.locality ?? "Larnaca",
                            country: _lastPlacemark?.isoCountryCode ?? "CY",
                          ),
                        ),
                      );

                      if (structured == null) return;

                      final saved = await _saveAddressToFirestore(
                        label: structured["formatted"],
                        line1: structured["formatted"],
                        city: structured["city"],
                        country: structured["country"],
                        lat: structured["lat"],
                        lng: structured["lng"],
                        type: structured["type"],
                        details: structured["details"],
                      );

                      if (mounted) Navigator.pop(context, saved);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF254573),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text(
                      "Confirm Location",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
