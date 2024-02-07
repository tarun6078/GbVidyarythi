import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebaselog/screens/login_screen.dart';
import 'package:firebaselog/screens/notification.dart';
class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late String userEmail; // Email of the logged-in user

  @override
  void initState() {
    super.initState();
    fetchUserEmail(); // Fetch the user's email on screen initialization
  }

  // Function to fetch the user's email from Firebase authentication
  void fetchUserEmail() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        userEmail = user.email!;
      });
    }
  }

  // Function to handle logout
  void _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) =>LoginScreen()),
          (route) => false, // Clear the navigation stack
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.purple,
              ),
              child: Text(
                'Welcome, $userEmail!', // Display user's email here
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
            ListTile(
              title: Text('Logout'),
              leading: Icon(Icons.exit_to_app),
              onTap: _logout, // Call logout function on tap
            ),
          ],
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image
          Image.asset(
            'assets/back.gif', // Replace with your image path
            fit: BoxFit.cover,
          ),
          // Content on top of the background image
          Container(
            color: Colors.transparent, // Make container transparent
            padding: EdgeInsets.all(20),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Implement chat functionality
                    },
                    icon: Icon(Icons.chat, size: 32),
                    label: Text(
                      'Chat',
                      style: TextStyle(fontSize: 20),
                    ),
                    style: ElevatedButton.styleFrom(
                      primary: Colors.transparent,
                      onPrimary: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50.0),
                      ),
                      elevation: 5,
                      padding: EdgeInsets.symmetric(vertical: 15, horizontal: 40),
                      minimumSize: Size(double.infinity, 40),
                    ),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Implement geofencing attendance functionality
                    },
                    icon: Icon(Icons.location_on, size: 32),
                    label: Text(
                      'Geofencing Attendance',
                      style: TextStyle(fontSize: 20),
                    ),
                    style: ElevatedButton.styleFrom(
                      primary: Colors.transparent,
                      onPrimary: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50.0),
                      ),
                      elevation: 5,
                      padding: EdgeInsets.symmetric(vertical: 15, horizontal: 40),
                      minimumSize: Size(double.infinity, 40),
                    ),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Implement sharing functionality
                    },
                    icon: Icon(Icons.share, size: 32),
                    label: Text(
                      'Material Share',
                      style: TextStyle(fontSize: 20),
                    ),
                    style: ElevatedButton.styleFrom(
                      primary: Colors.transparent,
                      onPrimary: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50.0),
                      ),
                      elevation: 5,
                      padding: EdgeInsets.symmetric(vertical: 15, horizontal: 40),
                      minimumSize: Size(double.infinity, 40),
                    ),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) =>AddTaskReminder()),
                    );
                      // TODO: Implement notification functionality
                    },
                    icon: Icon(Icons.notifications, size: 32),
                    label: Text(
                      'Notifications',
                      style: TextStyle(fontSize: 20),
                    ),
                    style: ElevatedButton.styleFrom(
                      primary: Colors.transparent,
                      onPrimary: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50.0),
                      ),
                      elevation: 5,
                      padding: EdgeInsets.symmetric(vertical: 15, horizontal: 40),
                      minimumSize: Size(double.infinity, 40),
                    ),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Implement AI assistant functionality
                    },
                    icon: Icon(Icons.chat_bubble_outline, size: 32),
                    label: Text(
                      'AI Assistant',
                      style: TextStyle(fontSize: 20),
                    ),
                    style: ElevatedButton.styleFrom(
                      primary: Colors.transparent,
                      onPrimary: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50.0),
                      ),
                      elevation: 5,
                      padding: EdgeInsets.symmetric(vertical: 15, horizontal: 40),
                      minimumSize: Size(double.infinity, 40),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
