import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:path_provider/path_provider.dart';
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
  TextEditingController _subjectController = TextEditingController(); // Controller for the subject text field
  bool isAttendanceStopped = false;
  bool isEntryRecorded = false;
  bool isExitRecorded = false;
  late String? userId;
  String? userName;
  String? useridNumber;
  late int timerDuration;
  bool _isAdmin = false;
  String _searchText = '';


  Timer? exitTimer;

  String _geofenceType = 'outdoor';
  List<String> _subjects = [];
  String? _selectedSubject;
  double? baseLatitude;
  double? baseLongitude;

  List<String> savedAreas = [];
  Map<String, Map<String, dynamic>> areaParameters = {};

  @override
  void initState() {
    super.initState();
    getUserData();
    _loadSavedAreas();
    _loadSavedSubjects();
  }

  Future<void> getUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    userId = user?.uid;

    // Check if the user is in the "users" collection
    DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection(
        'users').doc(userId).get();
    if (userDoc.exists) {
      setState(() {
        userName = userDoc['name']; // Fetch the 'Name' field from Firestore
        useridNumber = userDoc['idNumber'];
        _isAdmin = false;
      });
      return;
    }

    // Check if the user is in the "admins" collection
    DocumentSnapshot adminDoc = await FirebaseFirestore.instance.collection(
        'admins').doc(userId).get();
    if (adminDoc.exists) {
      setState(() {
        userName = adminDoc['name']; // Fetch the 'Name' field from Firestore
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
      '${place.street}, ${place.subLocality}, ${place.locality}, ${place
          .postalCode}, ${place.country}';
    });
  }

  Future<void> _loadSavedAreas() async {
    QuerySnapshot areaSnapshot = await FirebaseFirestore.instance.collection(
        'areas').get();
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
            insideGeofence = _isInsideCircularGeofence(
                position, baseLatitude!, baseLongitude!, radius);
          } else {
            double length = double.tryParse(lengthController.text) ?? 0;
            double breadth = double.tryParse(breadthController.text) ?? 0;
            insideGeofence = _isInsideRectangularGeofence(
                position, baseLatitude!, baseLongitude!, length, breadth);
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

  bool _isInsideCircularGeofence(Position position, double centerLatitude,
      double centerLongitude, double radius) {
    double distance = Geolocator.distanceBetween(
        position.latitude, position.longitude, centerLatitude, centerLongitude);
    return distance <= radius;
  }

  bool _isInsideRectangularGeofence(Position position, double baseLatitude,
      double baseLongitude, double length, double breadth) {
    double halfLength = length / 2;
    double halfBreadth = breadth / 2;

    double northBound = baseLatitude + (halfLength / 111320);
    double southBound = baseLatitude - (halfLength / 111320);
    double eastBound = baseLongitude +
        (halfBreadth / (111320 * cos(baseLatitude * (pi / 180))));
    double westBound = baseLongitude -
        (halfBreadth / (111320 * cos(baseLatitude * (pi / 180))));

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

      attendanceList.add(
          '$formattedDateTime - $eventText - Address: $address - $_selectedSubject - Area: $areaName');
      await prefs.setStringList(userId!, attendanceList);

      await FirebaseFirestore.instance.collection('attendance').add({
        'userId': userId,
        'userName': userName,
        'useridNumber': useridNumber,
        'event': eventText,
        'Subject':_selectedSubject,
        'address': address,
        'areaName': areaName.isNotEmpty ? areaName : 'Unknown',
        // Save the area name in Firestore
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
      attendanceList.add(
          '$formattedDateTime - $eventText - Address- $address - $_selectedSubject - Area: $areaName');
      await prefs.setStringList(userId!, attendanceList);
      await FirebaseFirestore.instance.collection('attendance').add({
        'userId': userId,
        'userName': userName,
        'useridNumber': useridNumber,
        'event': eventText,
        'Subject':_selectedSubject,
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

// Load saved subjects from SharedPreferences

  Future<void> _loadSavedSubjects() async {
    CollectionReference subjectsRef = FirebaseFirestore.instance.collection(
        'subjects');
    QuerySnapshot querySnapshot = await subjectsRef.get();

    setState(() {
      _subjects =
          querySnapshot.docs.map((doc) => doc['name'] as String).toList();
      _selectedSubject = _subjects.isNotEmpty ? _subjects.first : null;
    });
  }

  Future<void> _addSubject(String subject) async {
    if (_subjects.contains(subject)) return;

    CollectionReference subjectsRef = FirebaseFirestore.instance.collection(
        'subjects');
    await subjectsRef.add({'name': subject});

    setState(() {
      _subjects.add(subject);
      if (_selectedSubject == null) {
        _selectedSubject = subject;
      }
    });
  }

  Future<void> _deleteSubject(String subject) async {
    CollectionReference subjectsRef = FirebaseFirestore.instance.collection(
        'subjects');
    QuerySnapshot querySnapshot = await subjectsRef.where(
        'name', isEqualTo: subject).get();
    for (var doc in querySnapshot.docs) {
      await doc.reference.delete();
    }

    setState(() {
      _subjects.remove(subject);
      if (_selectedSubject == subject) {
        _selectedSubject = _subjects.isNotEmpty ? _subjects.first : null;
      }
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
                "Geofence Event: $geofenceEvent",
              ),
              SizedBox(height: 10),
              Text(
                "Welcome, ${_isAdmin ? userName : '${userName} (${useridNumber})'}!",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
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
              DropdownButton<String>(
                value: _selectedSubject,
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedSubject = newValue!;
                  });
                },
                items: _subjects.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Row(
                      children: [
                        if (_isAdmin)
                          GestureDetector(
                            onLongPress: () {
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: Text('Confirm Delete'),
                                    content: Text(
                                        'Are you sure you want to delete $value?'),
                                    actions: <Widget>[
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                        child: Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          _deleteSubject(value);
                                          Navigator.of(context).pop();
                                        },
                                        child: Text('Delete'),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                            child: Icon(Icons.delete, color: Colors.purple),
                          ),
                        SizedBox(width: 10),
                        Text(value),
                      ],
                    ),
                  );
                }).toList(),
              ),
              if (_isAdmin)
                ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: Text('Add Subject'),
                          content: TextField(
                            controller: _subjectController,
                            decoration: InputDecoration(
                              labelText: 'Subject Name',
                            ),
                          ),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                _addSubject(_subjectController.text);
                                Navigator.of(context).pop();
                              },
                              child: Text('Save'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  child: Text('Add Subject'),
                ),
              SizedBox(height: 10),
              if (_geofenceType == 'outdoor') ...[
                TextField(
                  controller: radiusController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Enter radius (meters)',
                  ),
                  keyboardType:
                  TextInputType.numberWithOptions(decimal: true),
                ),
              ] else ...[
                TextField(
                  controller: lengthController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Enter length (meters)',
                  ),
                  keyboardType:
                  TextInputType.numberWithOptions(decimal: true),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: breadthController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Enter breadth (meters)',
                  ),
                  keyboardType:
                  TextInputType.numberWithOptions(decimal: true),
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
                  if (_isAdmin)
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
                      await startAttendance();
                    },
                  ),
                  SizedBox(width: 10.0),
                  ElevatedButton(
                    child: Text("Stop"),
                    onPressed: () async {
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
                          builder: (context) => AttendanceRecordPage(
                            userId: userId,
                            userName: userName,
                            useridNumber: useridNumber,
                          ),
                        ),
                      );
                    },
                  ),
                  if (_isAdmin)
                    ElevatedButton(
                      child: Text("Users Attendance"),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UsersAttendancePage(),
                          ),
                        );
                      },
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    labelText: 'Search saved areas',
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchText = value.toLowerCase();
                    });
                  },
                ),
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
                  if (_searchText.isNotEmpty &&
                      !areaName
                          .toLowerCase()
                          .contains(_searchText)) {
                    return SizedBox.shrink();
                  }
                  return Dismissible(
                    key: UniqueKey(),
                    direction: _isAdmin
                        ? DismissDirection.endToStart
                        : DismissDirection.none,
                    background: Container(
                      alignment: Alignment.centerRight,
                      color: Colors.purple,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10.0),
                        child: Icon(Icons.delete,
                            color: Colors.white),
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
                            _geofenceType =
                            areaParameters[areaName]!['type']!;
                            radiusController.text =
                                areaParameters[areaName]!['radius'] ??
                                    '';
                            lengthController.text =
                                areaParameters[areaName]!['length'] ??
                                    '';
                            breadthController.text =
                                areaParameters[areaName]!['breadth'] ??
                                    '';
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
  final String? useridNumber;

  const AttendanceRecordPage({Key? key, this.userId, this.userName,this.useridNumber}) : super(key: key);

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
                      text: '${widget.useridNumber} - ',
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
  late List<String> _subjects = [];
  String? _selectedSubject;
  String _searchQuery = '';
  int _totalUsers = 0;
  final TextEditingController _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSubjects();
    _attendanceStream = FirebaseFirestore.instance.collection('attendance').snapshots();
    _calculateTotalUsers();
  }

  Future<void> _loadSubjects() async {
    CollectionReference subjectsRef = FirebaseFirestore.instance.collection('subjects');
    QuerySnapshot querySnapshot = await subjectsRef.get();
    setState(() {
      _subjects = querySnapshot.docs.map((doc) => doc['name'] as String).toList();
      _selectedSubject = _subjects.isNotEmpty ? _subjects.first : null;
      _calculateTotalUsers();
    });
  }

  Future<void> _calculateTotalUsers() async {
    if (_selectedSubject == null) {
      setState(() {
        _totalUsers = 0;
      });
      return;
    }

    QuerySnapshot attendanceSnapshot = await FirebaseFirestore.instance
        .collection('attendance')
        .where('Subject', isEqualTo: _selectedSubject)
        .get();

    Set<String> uniqueUsers = Set<String>();
    for (var doc in attendanceSnapshot.docs) {
      uniqueUsers.add(doc['userId']);
    }

    setState(() {
      _totalUsers = uniqueUsers.length;
    });
  }

  Future<void> _deleteRecord(String documentId) async {
    await FirebaseFirestore.instance.collection('attendance').doc(documentId).delete();
  }

  Future<void> _sendEmailWithCsv(String email) async {
    if (_selectedSubject == null) return;

    QuerySnapshot attendanceSnapshot = await FirebaseFirestore.instance
        .collection('attendance')
        .where('Subject', isEqualTo: _selectedSubject)
        .get();

    List<QueryDocumentSnapshot> sortedRecords = attendanceSnapshot.docs;
    sortedRecords.sort((a, b) {
      int nameComparison = a['userName'].toString().compareTo(b['userName'].toString());
      if (nameComparison != 0) {
        return nameComparison;
      }
      String? eventA = a['event'];
      String? eventB = b['event'];
      List<String> eventOrder = ['Initialized geofence', 'Entered the location', 'Exited the location'];
      int indexA = eventOrder.indexOf(eventA!);
      int indexB = eventOrder.indexOf(eventB!);
      return indexA.compareTo(indexB);
    });

    final filteredRecords = sortedRecords.where((record) {
      final userName = record['userName']?.toString().toLowerCase() ?? '';
      return userName.contains(_searchQuery);
    }).toList();

    List<List<String>> csvData = [
      ['UserName', 'UserIdNumber', 'Event', 'AreaName', 'Address', 'Timestamp']
    ];
    for (var doc in filteredRecords) {
      csvData.add([
        doc['userName'] ?? 'Unknown',
        doc['useridNumber'] ?? 'Not user',
        doc['event'] ?? 'Unknown event',
        doc['areaName'] ?? 'Unknown area',
        doc['address'] ?? 'No address',
        doc['timestamp'] ?? 'Unknown time',
      ]);
    }

    String csv = const ListToCsvConverter().convert(csvData);
    final Email emailToSend = Email(
      body: 'User attendance data in CSV format.',
      subject: 'Attendance Data',
      recipients: [email],
      attachmentPaths: [await _writeCsvToFile(csv)],
      isHTML: false,
    );

    try {
      await FlutterEmailSender.send(emailToSend);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Email sent successfully")),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to send email: $error")),
      );
    }
  }

  Future<String> _writeCsvToFile(String csv) async {
    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/${_selectedSubject}_attendance.csv';
    final File file = File(path);
    await file.writeAsString(csv);
    return file.path;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('All Users Attendance'),
        actions: [
          IconButton(
            icon: Icon(Icons.send),
            onPressed: () {
              _sendEmailWithCsv(_emailController.text);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by user name',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: DropdownButton<String>(
              value: _selectedSubject,
              onChanged: (String? newValue) {
                setState(() {
                  _selectedSubject = newValue!;
                  _calculateTotalUsers();
                });
              },
              items: _subjects.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ),
          Text('Total Users: $_totalUsers'),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
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

                List<QueryDocumentSnapshot> sortedRecords = data.docs;
                sortedRecords.sort((a, b) {
                  int nameComparison = a['userName'].toString().compareTo(b['userName'].toString());
                  if (nameComparison != 0) {
                    return nameComparison;
                  }
                  String? eventA = a['event'];
                  String? eventB = b['event'];
                  List<String> eventOrder = ['Initialized geofence', 'Entered the location', 'Exited the location'];
                  int indexA = eventOrder.indexOf(eventA!);
                  int indexB = eventOrder.indexOf(eventB!);
                  return indexA.compareTo(indexB);
                });

                final filteredRecords = sortedRecords.where((record) {
                  final userName = record['userName']?.toString().toLowerCase() ?? '';
                  final subject = record['Subject']?.toString().toLowerCase() ?? '';
                  return userName.contains(_searchQuery) && subject == _selectedSubject?.toLowerCase();
                }).toList();

                if (filteredRecords.isEmpty) {
                  return Center(child: Text('No matching attendance records found.'));
                }

                return ListView.builder(
                  itemCount: filteredRecords.length,
                  itemBuilder: (context, index) {
                    final record = filteredRecords[index];

                    final userName = record['userName'] ?? 'Unknown';
                    final useridNumber = record['useridNumber'] ?? 'Not user';
                    final event = record['event'] ?? 'Unknown event';
                    final areaName = record['areaName'] ?? 'Unknown area';
                    final address = record['address'] ?? 'No address';
                    final timestamp = record['timestamp'] ?? 'Unknown time';

                    return Dismissible(
                      key: Key(record.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        color: Colors.purple,
                        child: Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (DismissDirection direction) async {
                        return await showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: Text("Confirm"),
                              content: Text("Are you sure you want to delete this record?"),
                              actions: <Widget>[
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: Text("Cancel"),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  child: Text("OK"),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      onDismissed: (direction) {
                        if (direction == DismissDirection.endToStart) {
                          _deleteRecord(record.id);
                        }
                      },
                      child: ListTile(
                        title: Text('$userName - $useridNumber'),
                        subtitle: Text('Event: $event\nArea: $areaName\nAddress: $address\nTimestamp: $timestamp'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
