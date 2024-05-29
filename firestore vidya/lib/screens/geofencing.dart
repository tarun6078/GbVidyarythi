import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
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
  StreamSubscription<Position>? positionStream;
  String geofenceEvent = '';
  String location = '';
  String address = '';
  TextEditingController radiusController = TextEditingController();
  TextEditingController lengthController = TextEditingController();
  TextEditingController breadthController = TextEditingController();
  TextEditingController timerController = TextEditingController();
  TextEditingController areaNameController = TextEditingController();
  bool isAttendanceStopped = false;
  bool isEntryRecorded = false;
  bool isExitRecorded = false;
  late String? userId;
  String? userName;
  late int timerDuration;
  bool _isAdmin = false;


  Timer? exitTimer;

  String _geofenceType = 'outdoor';

  double? baseLatitude;
  double? baseLongitude;

  List<String> savedAreas = [];
  Map<String, Map<String, dynamic>> areaParameters = {};

  @override
  void initState() {
    super.initState();
    getUserData();
    _loadSavedAreas();
  }

  Future<void> getUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    userId = user?.uid;

    // Check if the user is in the "users" collection
    DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (userDoc.exists) {
      setState(() {
        userName = userDoc['name'];// Fetch the 'Name' field from Firestore
        _isAdmin = false;
      });
      return;
    }

    // Check if the user is in the "admins" collection
    DocumentSnapshot adminDoc = await FirebaseFirestore.instance.collection('admins').doc(userId).get();
    if (adminDoc.exists) {
      setState(() {
        userName = adminDoc['name'];// Fetch the 'Name' field from Firestore
        _isAdmin = true;
      });
      return;
    }

    // If the user is not found in both collections, handle accordingly
    print('User not found!');
  }

  Future<void> _getCurrentLocation() async {
    Position position = await _getGeoLocationPosition();
    await getAddressFromLatLong(position);
    setState(() {
      location = 'Lat: ${position.latitude} , Long: ${position.longitude}';
      baseLatitude = position.latitude;
      baseLongitude = position.longitude;
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

  Future<void> _loadSavedAreas() async {
    QuerySnapshot areaSnapshot = await FirebaseFirestore.instance.collection('areas').get();
    List<String> areaList = [];
    Map<String, Map<String, dynamic>> parameters = {};

    for (var doc in areaSnapshot.docs) {
      String areaName = doc.id;
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      areaList.add(areaName);
      parameters[areaName] = {
        'type': data['type'],
        'radius': data['radius'],
        'length': data['length'],
        'breadth': data['breadth'],
      };
    }

    setState(() {
      savedAreas = areaList;
      areaParameters = parameters;
    });
  }

  Future<void> _saveAreaParameters() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String areaName = areaNameController.text.trim();

    // Check if the area name already exists
    if (savedAreas.contains(areaName)) {
      // Display an error message or handle the duplicate name scenario
      // For example, you can show a snackbar or dialog
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Error"),
            content: Text("Area with the same name already exists."),
            actions: <Widget>[
              TextButton(
                child: Text("OK"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
      return;
    }

    // If the area name is unique, proceed with saving
    setState(() {
      savedAreas.add(areaName);
      areaParameters[areaName] = {
        'type': _geofenceType,
        'radius': radiusController.text,
        'length': lengthController.text,
        'breadth': breadthController.text,
      };
    });
    await FirebaseFirestore.instance.collection('areas').doc(areaName).set({
      'type': _geofenceType,
      'radius': radiusController.text,
      'length': lengthController.text,
      'breadth': breadthController.text,
    });
    await prefs.setStringList('savedAreas', savedAreas);
    await prefs.setString('$areaName-type', _geofenceType);
    await prefs.setString('$areaName-radius', radiusController.text);
    await prefs.setString('$areaName-length', lengthController.text);
    await prefs.setString('$areaName-breadth', breadthController.text);
    areaNameController.clear();
    radiusController.clear();
    lengthController.clear();
    breadthController.clear();
  }


  Future<void> _deleteAreaParameters(String areaName) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      savedAreas.remove(areaName);
      areaParameters.remove(areaName);
    });
    await prefs.setStringList('savedAreas', savedAreas);
    await prefs.remove('$areaName-type');
    await prefs.remove('$areaName-radius');
    await prefs.remove('$areaName-length');
    await prefs.remove('$areaName-breadth');
    await FirebaseFirestore.instance.collection('areas').doc(areaName).delete();
  }

  Future<void> startAttendance() async {
    await _getCurrentLocation();

    if (positionStream == null) {
      positionStream = Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 1,
        ),
      ).listen((Position position) async {
        if (!isAttendanceStopped) {
          bool insideGeofence;
          if (_geofenceType == 'outdoor') {
            double radius = double.tryParse(radiusController.text) ?? 0;
            insideGeofence = _isInsideCircularGeofence(position, baseLatitude!, baseLongitude!, radius);
          } else {
            double length = double.tryParse(lengthController.text) ?? 0;
            double breadth = double.tryParse(breadthController.text) ?? 0;
            insideGeofence = _isInsideRectangularGeofence(position, baseLatitude!, baseLongitude!, length, breadth);
          }

          if (insideGeofence) {
            if (!isEntryRecorded) {
              await saveAttendance(GeofenceEvent.init, address);
              await saveAttendance(GeofenceEvent.enter, address);
              setState(() {
                isEntryRecorded = true;
              });
              _showEventDialog(GeofenceEvent.init.toString());
              _showEventDialog(GeofenceEvent.enter.toString());
              int timer = int.tryParse(timerController.text) ?? 5;
              startExitTimer(timer);
            }
          } else if (isEntryRecorded) {
            if (!isExitRecorded) {
              cancelExitTimer(); // Cancel the exit timer if person exits before the time frame
              _showEventDialog(GeofenceEvent.exit.toString());
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

  bool _isInsideCircularGeofence(Position position, double centerLatitude, double centerLongitude, double radius) {
    double distance = Geolocator.distanceBetween(position.latitude, position.longitude, centerLatitude, centerLongitude);
    return distance <= radius;
  }

  bool _isInsideRectangularGeofence(Position position, double baseLatitude, double baseLongitude, double length, double breadth) {
    double halfLength = length / 2;
    double halfBreadth = breadth / 2;

    double northBound = baseLatitude + (halfLength / 111320);
    double southBound = baseLatitude - (halfLength / 111320);
    double eastBound = baseLongitude + (halfBreadth / (111320 * cos(baseLatitude * (pi / 180))));
    double westBound = baseLongitude - (halfBreadth / (111320 * cos(baseLatitude * (pi / 180))));

    return position.latitude <= northBound &&
        position.latitude >= southBound &&
        position.longitude <= eastBound &&
        position.longitude >= westBound;
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
    positionStream?.cancel();
    cancelExitTimer(); // Cancel the timer when attendance is stopped
  }
  Future<void> saveAttendance(GeofenceEvent event, String address) async {
    if (!isExitRecorded || event == GeofenceEvent.enter) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String>? attendanceList = prefs.getStringList(userId!) ?? [];
      String formattedDateTime = DateTime.now().toString();
      String eventText = _getEventText(event);
      String areaName = areaNameController.text.trim(); // Get the area name

      attendanceList.add('$formattedDateTime - $eventText - Address: $address - Area: $areaName');
      await prefs.setStringList(userId!, attendanceList);

      await FirebaseFirestore.instance.collection('attendance').add({
        'userId': userId,
        'userName': userName,
        'event': eventText,
        'address': address,
        'areaName': areaName.isNotEmpty ? areaName : 'Unknown',  // Save the area name in Firestore
        'timestamp': formattedDateTime,
      });
    }
  }


  String _getEventText(GeofenceEvent event) {
    switch (event) {
      case GeofenceEvent.init:
        return 'Initialized geofence';
      case GeofenceEvent.enter:
        return 'Entered the location';
      case GeofenceEvent.exit:
        return 'Exited the location';
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
      String areaName = areaNameController.text.trim();
      List<String>? attendanceList = prefs.getStringList(userId!) ?? [];
      attendanceList.add('$formattedDateTime - $eventText - Address: $address Area: $areaName');
      await prefs.setStringList(userId!, attendanceList);
      await FirebaseFirestore.instance.collection('attendance').add({
        'userId': userId,
        'userName': userName,
        'event': eventText,
        'areaName': areaName.isNotEmpty ? areaName : 'Unknown',
        'address': address,
        'timestamp': formattedDateTime,
      });
      setState(() {
        isExitRecorded = true;
        geofenceEvent = GeofenceEvent.exit.toString();
      });

    }
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
              DropdownButton<String>(
                value: _geofenceType,
                onChanged: (String? newValue) {
                  setState(() {
                    _geofenceType = newValue!;
                  });
                },
                items: <String>['indoor', 'outdoor']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
              SizedBox(height: 10),
              if (_geofenceType == 'outdoor') ...[
                TextField(
                  controller: radiusController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Enter radius (meters)',
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
              ] else ...[
                TextField(
                  controller: lengthController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Enter length (meters)',
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: breadthController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Enter breadth (meters)',
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
              ],
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
              TextField(
                controller: areaNameController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Enter area name',
                ),
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
                  if(_isAdmin)
                  ElevatedButton(
                    onPressed: () async {
                      await _saveAreaParameters();
                    },
                    child: Text('Save Area'),
                  ),
                ],
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
                    child: Text("Attendance Records"),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AttendanceRecordPage(userId: userId, userName: userName),
                        ),
                      );
                    },
                  ),
                  if (_isAdmin)
                    ElevatedButton(
                    child: Text("Users Attendance"),
                    onPressed: () { Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UsersAttendancePage(),
                      ),
                    );
                      // Navigate to Users Attendance page
                    },
                  ),
                ],
              ),
              SizedBox(height: 10),
              Text('Saved Areas:'),
              savedAreas.isEmpty
                  ? Text('No saved areas.')
                  : ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: savedAreas.length,
                itemBuilder: (context, index) {
                  String areaName = savedAreas[index];
                  return Dismissible(
                    key: Key(areaName),
                    direction: _isAdmin
                        ? DismissDirection.endToStart
                        : DismissDirection.none,
                    background: Container(
                      alignment: Alignment.centerRight,
                      color: Colors.purple,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10.0),
                        child: Icon(Icons.delete, color: Colors.white),
                      ),
                    ),
                    onDismissed: (direction) async {
                      await _deleteAreaParameters(areaName);
                    },
                    child: Card(
                      child: ListTile(
                        title: Text(areaName),
                        subtitle: Text(
                            'Type: ${areaParameters[areaName]!['type']}, Radius: ${areaParameters[areaName]!['radius']}, Length: ${areaParameters[areaName]!['length']}, Breadth: ${areaParameters[areaName]!['breadth']}'),
                        onTap: () {
                          setState(() {
                            _geofenceType = areaParameters[areaName]!['type'];
                            radiusController.text = areaParameters[areaName]!['radius'] ?? '';
                            lengthController.text = areaParameters[areaName]!['length'] ?? '';
                            breadthController.text = areaParameters[areaName]!['breadth'] ?? '';
                            areaNameController.text = areaName;
                          });
                        },
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
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
          return Dismissible(
            key: Key(_attendanceRecords[index]),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              color: Colors.purple,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.0),
                child: Icon(Icons.delete, color: Colors.white),
              ),
            ),
            onDismissed: (direction) {
              _deleteAttendanceRecord(index);
            },
            child: ListTile(
              title: RichText(
                text: TextSpan(
                  style: DefaultTextStyle.of(context).style,
                  children: <TextSpan>[
                    TextSpan(
                      text: '${widget.userName} - ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: _attendanceRecords[index],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

enum GeofenceEvent { enter, exit, init }

class AreaParameters {
  final String type;
  final String? radius;
  final String? length;
  final String? breadth;

  AreaParameters({
    required this.type,
    this.radius,
    this.length,
    this.breadth,
  });

  Map<String, String?> toMap() {
    return {
      'type': type,
      'radius': radius,
      'length': length,
      'breadth': breadth,

    };
  }

  factory AreaParameters.fromMap(Map<String, String?> map) {
    return AreaParameters(
      type: map['type']!,
      radius: map['radius'],
      length: map['length'],
      breadth: map['breadth'],
    );
  }
}
class UsersAttendancePage extends StatefulWidget {
  @override
  _UsersAttendancePageState createState() => _UsersAttendancePageState();
}

class _UsersAttendancePageState extends State<UsersAttendancePage> {
  late Stream<QuerySnapshot> _attendanceStream;

  @override
  void initState() {
    super.initState();
    _attendanceStream = FirebaseFirestore.instance.collection('attendance').snapshots();
  }

  Future<void> _deleteRecord(String documentId) async {
    await FirebaseFirestore.instance.collection('attendance').doc(documentId).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('All Users Attendance'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _attendanceStream,
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final data = snapshot.requireData;

          if (data.docs.isEmpty) {
            return Center(child: Text('No attendance records available.'));
          }

          return ListView.builder(
            itemCount: data.size,
            itemBuilder: (context, index) {
              final record = data.docs[index];

              // Safely accessing fields with null checks
              final userName = record['userName'] ?? 'Unknown';
              final event = record['event'] ?? 'Unknown event';
              final areaName = record['areaName'] ?? 'Unknown area';
              final address = record['address'] ?? 'No address';
              final timestamp = record['timestamp'] ?? 'Unknown time';

              return Dismissible(
                key: Key(record.id),
                background: Container(color: Colors.purple, child: Icon(Icons.delete, color: Colors.white)),
                onDismissed: (direction) {
                  _deleteRecord(record.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Record deleted")),
                  );
                },
                child: ListTile(
                  title: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: userName,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text: ' - $event - $areaName',
                        ),
                      ],
                    ),
                  ),
                  subtitle: Text('Address: $address\nTime: $timestamp'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

