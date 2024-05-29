import 'package:flutter/material.dart';
import 'package:Vidyarthi/screens/feature.dart';
import 'package:Vidyarthi/screens/registration_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:Vidyarthi/screens/forgotten.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // form key
  final _formKey = GlobalKey<FormState>();

  // editing controller
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  // firebase
  final _auth = FirebaseAuth.instance;

  // string for displaying the error Message
  String? errorMessage;

  // loading indicator flag
  bool _isLoading = false;

  // UserType
  UserType _selectedUserType = UserType.User;

  // Function to show loading indicator
  Widget buildLoadingIndicator() {
    return _isLoading
        ? Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.5),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      ),
    )
        : SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background Image
          Image.asset(
            "assets/back.gif",
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),

          // Your existing UI
          Center(
            child: SingleChildScrollView(
              child: Container(
                color: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.all(36.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        SizedBox(
                          height: 200,
                          child: Image.asset(
                            "assets/logo.png",
                            fit: BoxFit.contain,
                          ),
                        ),
                        SizedBox(height: 45),
                        // Email field
                        TextFormField(
                          autofocus: false,
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value!.isEmpty) {
                              return ("Please Enter Your Email");
                            }
                            // reg expression for email validation
                            if (!RegExp(
                                "^[a-zA-Z0-9+_.-]+@[a-zA-Z0-9.-]+.[a-z]")
                                .hasMatch(value)) {
                              return ("Please Enter a valid email");
                            }
                            return null;
                          },
                          onSaved: (value) {
                            emailController.text = value!;
                          },
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.mail),
                            contentPadding:
                            EdgeInsets.fromLTRB(20, 15, 20, 15),
                            hintText: "Email",
                            enabledBorder: OutlineInputBorder(
                              borderSide:
                              BorderSide(color: Colors.black, width: 2.0),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide:
                              BorderSide(color: Colors.purple, width: 2.0),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        SizedBox(height: 25),
                        // Password field
                        TextFormField(
                          autofocus: false,
                          controller: passwordController,
                          obscureText: true,
                          validator: (value) {
                            RegExp regex = new RegExp(r'^.{6,}$');
                            if (value!.isEmpty) {
                              return ("Password is required for login");
                            }
                            if (!regex.hasMatch(value)) {
                              return (
                                  "Enter Valid Password(Min. 6 Character)");
                            }
                            return null;
                          },
                          onSaved: (value) {
                            passwordController.text = value!;
                          },
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.vpn_key),
                            contentPadding:
                            EdgeInsets.fromLTRB(20, 15, 20, 15),
                            hintText: "Password",
                            enabledBorder: OutlineInputBorder(
                              borderSide:
                              BorderSide(color: Colors.black, width: 2.0),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide:
                              BorderSide(color: Colors.purple, width: 2.0),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        SizedBox(height: 25),
                        // UserType dropdown
                        DropdownButtonFormField<UserType>(
                          value: _selectedUserType,
                          onChanged: (value) {
                            setState(() {
                              _selectedUserType = value!;
                            });
                          },
                          items: UserType.values.map((type) {
                            return DropdownMenuItem<UserType>(
                              value: type,
                              child: Text(
                                  type == UserType.User ? "User" : "Admin"),
                            );
                          }).toList(),
                        ),
                        SizedBox(height: 35),
                        // Login button
                        Stack(
                          children: [
                            Material(
                              elevation: 5,
                              borderRadius: BorderRadius.circular(30),
                              color: Colors.black,
                              child: MaterialButton(
                                padding:
                                EdgeInsets.fromLTRB(20, 15, 20, 15),
                                minWidth:
                                MediaQuery.of(context).size.width,
                                onPressed: () {
                                  signIn(
                                    emailController.text,
                                    passwordController.text,
                                  );
                                },
                                child: Text(
                                  "Login",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 20,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            buildLoadingIndicator(),
                          ],
                        ),
                        SizedBox(height: 15),
                        // Forgot Password text
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ForgotPasswordScreen(),
                              ),
                            );
                          },
                          child: Text(
                            "Forgot Password?",
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        SizedBox(height: 15),
                        // Sign Up text
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text("Don't have an account? "),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        RegistrationScreen(),
                                  ),
                                );
                              },
                              child: Text(
                                "SignUp",
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            )
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // login function
  void signIn(String email, String password) async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        await _auth
            .signInWithEmailAndPassword(
          email: email,
          password: password,
        )
            .then((userCredential) async {
          if (_selectedUserType == UserType.Admin) {
            // Check if user is admin in admins collection
            final adminSnapshot = await FirebaseFirestore.instance
                .collection('admins')
                .doc(userCredential.user!.uid)
                .get();

            if (adminSnapshot.exists) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => HomePage()),
                    (route) => false,
              );
            } else {
              throw FirebaseAuthException(
                code: 'unauthorized',
                message: 'You are not authorized as an admin',
              );
            }
          } else {
            // Check if user is present in users collection
            final userSnapshot = await FirebaseFirestore.instance
                .collection('users')
                .doc(userCredential.user!.uid)
                .get();

            if (userSnapshot.exists) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => HomePage()),
                    (route) => false,
              );
            } else {
              throw FirebaseAuthException(
                code: 'unauthorized',
                message: 'User not found in database',
              );
            }
          }
        });
      } on FirebaseAuthException catch (error) {
        switch (error.code) {
          case "invalid-email":
            errorMessage = "Your email address appears to be malformed.";
            break;
          case "wrong-password":
            errorMessage = "Your password is wrong.";
            break;
          case "user-not-found":
            errorMessage = "User with this email doesn't exist.";
            break;
          case "user-disabled":
            errorMessage = "User with this email has been disabled.";
            break;
          case "too-many-requests":
            errorMessage = "Too many requests";
            break;
          case "operation-not-allowed":
            errorMessage =
            "Signing in with Email and Password is not enabled.";
            break;
          case "unauthorized":
            errorMessage = error.message;
            break;
          default:
            errorMessage = "An undefined Error happened.";
        }
        Fluttertoast.showToast(msg: errorMessage!);
        print(error.code);
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

enum UserType {
  User,
  Admin,
}
