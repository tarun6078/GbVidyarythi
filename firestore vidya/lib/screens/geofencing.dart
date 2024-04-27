import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/services.dart';
import 'package:geofence_flutter/geofence_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Geofence Attendance',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyGeofencePage(title: 'Geofence Attendance'),
    );
  }
}

class MyGeofencePage extends StatefulWidget {
  MyGeofencePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _MyGeofencePageState createState() => _MyGeofencePageState();
}

class _MyGeofencePageState extends State<MyGeofencePage> {
  StreamSubscription<GeofenceEvent>? geofenceEventStream;
  String geofenceEvent = '';
  String location = '';
  String address = '';
  TextEditingController radiusController = TextEditingController();
  TextEditingController timerController = TextEditingController();
  bool isAttendanceStopped = false;
  bool isEntryRecorded = false;
  bool isExitRecorded = false;
  bool isGeofenceInitialized = false;
  late String? userId;
  late String? userName;
  late int timerDuration;

  Timer? exitTimer;

  @override
  void initState() {
    super.initState();
    getUserData();
  }

  Future<void> getUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    userId = user?.uid;
    FirebaseFirestore.instance.collection('users').doc(userId).get().then((doc) {
      if (doc.exists) {
        setState(() {
          userName = doc['firstName'];
        });
      } else {
        print('No such document!');
      }
    });
  }

  Future<void> _getCurrentLocation() async {
    Position position = await _getGeoLocationPosition();
    await getAddressFromLatLong(position);
    setState(() {
      location = 'Lat: ${position.latitude} , Long: ${position.longitude}';
    });
  }

  Future<Position> _getGeoLocationPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      throw 'Location services are disabled.';
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw 'Location permissions are denied';
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw 'Location permissions are permanently denied, we cannot request permissions.';
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<void> getAddressFromLatLong(Position position) async {
    List<Placemark> placemarks =
    await placemarkFromCoordinates(position.latitude, position.longitude);
    Placemark place = placemarks[0];
    setState(() {
      address =
      '${place.street}, ${place.subLocality}, ${place.locality}, ${place.postalCode}, ${place.country}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                "Geofence Event: " + geofenceEvent,
              ),
              SizedBox(height: 10),
              userName != null
                  ? Text(
                "Welcome, $userName!",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              )
                  : SizedBox.shrink(),
              SizedBox(height: 10),
              TextField(
                controller: radiusController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Enter radius (meters)',
                ),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 10),
              TextField(
                controller: timerController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Enter timer duration (seconds)',
                ),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 10),
              Text('Current Location: $location'),
              SizedBox(height: 10),
              Text('Current Address: $address'),
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    child: Text("Start"),
                    onPressed: () async {
                      print("start");
                      await startAttendance();
                    },
                  ),
                  SizedBox(
                    width: 10.0,
                  ),
                  ElevatedButton(
                    child: Text("Stop"),
                    onPressed: () async {
                      print("stop");
                      await stopAttendance();
                    },
                  ),
                ],
              ),
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      await _getCurrentLocation();
                    },
                    child: Text('Get Location'),
                  ),
                  ElevatedButton(
                    child: Text("Attendance Records"),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AttendanceRecordPage(userId: userId, userName: userName),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> startAttendance() async {
    await Geofence.startGeofenceService(
      pointedLatitude: location.split(', ')[0].split(': ')[1],
      pointedLongitude: location.split(', ')[1].split(': ')[1],
      radiusMeter: radiusController.text.isEmpty ? '50' : radiusController.text,
      eventPeriodInSeconds: 10,
    );
    if (geofenceEventStream == null) {
      geofenceEventStream = Geofence.getGeofenceStream()?.listen((GeofenceEvent event) async {
        print(event.toString());
        if (!isAttendanceStopped) {
          if (event == GeofenceEvent.enter) {
            if (!isEntryRecorded) {
              await saveAttendance(GeofenceEvent.init, address);
              await saveAttendance(GeofenceEvent.enter, address);
              setState(() {
                isEntryRecorded = true;
              });
              _showEventDialog(GeofenceEvent.init.toString());
              _showEventDialog(event.toString());
              int timer = int.tryParse(timerController.text) ?? 5;
              startExitTimer(timer);
            }
          } else if (event == GeofenceEvent.exit && isEntryRecorded) {
            if (!isExitRecorded) {
              cancelExitTimer(); // Cancel the exit timer if person exits before the time frame
              _showEventDialog(event.toString());
              setState(() {
                isExitRecorded = true;
              });
              await stopAttendance();
            }
          }
        }
      });
    }
  }

  void startExitTimer(int duration) {
    exitTimer = Timer(Duration(seconds: duration), () async {
      await markExit();
    });
  }

  void cancelExitTimer() {
    exitTimer?.cancel();
  }

  Future<void> stopAttendance() async {
    setState(() {
      isAttendanceStopped = true;
    });
    await Geofence.stopGeofenceService();
    geofenceEventStream?.cancel();
    cancelExitTimer(); // Cancel the timer when attendance is stopped
  }

  Future<void> saveAttendance(GeofenceEvent event, String address) async {
    if (!isExitRecorded || event == GeofenceEvent.enter) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String>? attendanceList = prefs.getStringList(userId!) ?? [];
      String formattedDateTime = DateTime.now().toString();
      String eventText = _getEventText(event);
      attendanceList.add('$userName - $formattedDateTime - $eventText - Address: $address');
      await prefs.setStringList(userId!, attendanceList);
    }
  }

  String _getEventText(GeofenceEvent event) {
    switch (event) {
      case GeofenceEvent.enter:
        return 'Entered the location';
      case GeofenceEvent.exit:
        return 'Exited the location';
      case GeofenceEvent.init:
        return 'Initialized geofence';
      default:
        return 'Unknown event';
    }
  }

  void _showEventDialog(String event) {
    String dialogText = '';
    if (event == GeofenceEvent.init.toString()) {
      dialogText = 'Geofence initialized!';
    } else if (event == GeofenceEvent.enter.toString()) {
      dialogText = 'You entered the location!';
    } else if (event == GeofenceEvent.exit.toString()) {
      dialogText = 'You exited the location!';
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Geofence Event"),
          content: Text(dialogText),
          actions: <Widget>[
            TextButton(
              child: Text("Close"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> markExit() async {
    if (!isExitRecorded) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String formattedDateTime = DateTime.now().toString();
      String eventText = _getEventText(GeofenceEvent.exit);
      List<String>? attendanceList = prefs.getStringList(userId!) ?? [];
      attendanceList.add('$userName - $formattedDateTime - $eventText - Address: $address');
      await prefs.setStringList(userId!, attendanceList);
      setState(() {
        isExitRecorded = true;
        geofenceEvent = GeofenceEvent.exit.toString();
      });
    }
  }
}

class AttendanceRecordPage extends StatefulWidget {
  final String? userId;
  final String? userName;

  const AttendanceRecordPage({Key? key, this.userId, this.userName}) : super(key: key);

  @override
  _AttendanceRecordPageState createState() => _AttendanceRecordPageState();
}

class _AttendanceRecordPageState extends State<AttendanceRecordPage> {
  late List<String> _attendanceRecords;

  @override
  void initState() {
    super.initState();
    _loadAttendanceRecords();
  }

  Future<void> _loadAttendanceRecords() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? attendanceList = prefs.getStringList(widget.userId!);
    setState(() {
      _attendanceRecords = attendanceList ?? [];
    });
  }

  Future<void> _deleteAttendanceRecord(int index) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? attendanceList = prefs.getStringList(widget.userId!);
    if (attendanceList != null) {
      attendanceList.removeAt(index);
      await prefs.setStringList(widget.userId!, attendanceList);
      setState(() {
        _attendanceRecords = attendanceList;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance Records'),
      ),
      body: _attendanceRecords.isEmpty
          ? Center(
        child: Text('No attendance records available.'),
      )
          : ListView.builder(
        itemCount: _attendanceRecords.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(_attendanceRecords[index]),
            trailing: IconButton(
              icon: Icon(Icons.delete),
              onPressed: () => _deleteAttendanceRecord(index),
            ),
          );
        },
      ),
    );
  }
}
