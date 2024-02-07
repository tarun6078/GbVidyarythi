class UserModel {
  String? uid;
  String? email;
  String? Name;
  String? phoneNumber;
  UserModel({this.uid, this.email, this.Name,this.phoneNumber});

  // receiving data from server
  factory UserModel.fromMap(map) {
    return UserModel(
      uid: map['uid'],
      email: map['email'],
      Name: map['Name'],
      phoneNumber: map['phoneNumber'],
    );
  }

  // sending data to our server
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'firstName': Name,
      'phoneNumber': phoneNumber, // Add this line
    };
  }
}
