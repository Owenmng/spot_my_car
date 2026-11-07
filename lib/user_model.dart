// Fichier: lib/user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String email;
  final String firstName;
  final String lastName;
  final Timestamp dateOfBirth;

  AppUser({
    required this.uid,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
  });
}