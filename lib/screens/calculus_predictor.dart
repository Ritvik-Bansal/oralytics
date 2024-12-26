import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

class CalculusPredictor extends StatefulWidget {
  @override
  _CalculusPredictorState createState() => _CalculusPredictorState();
}

class _CalculusPredictorState extends State<CalculusPredictor> {
  File? _image;
  Map<String, dynamic>? _result;
  bool isLoading = false;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _auth = FirebaseAuth.instance;

  Future<String?> _uploadImageToStorage(File imageFile) async {
    if (_auth.currentUser == null) {
      print('No user is currently logged in');
      return null;
    }
    try {
      print(
          'Current user ID: ${_auth.currentUser?.uid}'); // Add this debug line

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName =
          'plaque_detection_$timestamp${path.extension(imageFile.path)}';

      final storageRef = _storage
          .ref()
          .child('users')
          .child(_auth.currentUser!.uid)
          .child('plaque_detection_images')
          .child(fileName);

      await storageRef.putFile(imageFile);

      final downloadUrl = await storageRef.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _saveResultToFirebase() async {
    if (_result == null || _auth.currentUser == null || _image == null) return;

    try {
      final imageUrl = await _uploadImageToStorage(_image!);

      if (imageUrl == null) {
        throw Exception('Failed to upload image');
      }

      final predictionData = {
        'timestamp': FieldValue.serverTimestamp(),
        'topPrediction': _result!['top'],
        'confidence': _result!['confidence'],
        'allPredictions': _result!['predictions'],
        'imageMetadata': {
          'width': _result!['image']['width'],
          'height': _result!['image']['height'],
        },
        'imageUrl': imageUrl,
      };

      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('plaque_detection')
          .add(predictionData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Results and image saved successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving results: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        isLoading = true;
      });

      await _sendImageToApi(_image!);

      if (_result != null && !_result!.containsKey('error')) {
        await _saveResultToFirebase();
      }

      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _sendImageToApi(File imageFile) async {
    try {
      List<int> imageBytes = await imageFile.readAsBytes();
      String base64Image = base64Encode(imageBytes);

      var response = await http.post(
        Uri.parse(
            "https://detect.roboflow.com/calculus-jhbxq/3?api_key=qT7vcv1pFkSk3smKEGHS"),
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: base64Image,
      );

      if (response.statusCode == 200) {
        setState(() {
          _result = json.decode(response.body);
        });
      } else {
        setState(() {
          _result = {"error": "Error: ${response.body}"};
        });
      }
    } catch (e) {
      setState(() {
        _result = {"error": "Error: $e"};
      });
    }
  }

  Widget _buildPredictionCard(Map<String, dynamic> topPrediction) {
    final confidence = topPrediction['confidence'] * 100;
    final prediction = topPrediction['class'].toString().toLowerCase();

    final bool hasCalculus =
        prediction.contains('heavy') || prediction.contains('light');
    final Widget severityIndicator = hasCalculus
        ? Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red,
                  size: 20,
                ),
                SizedBox(width: 4),
                Text(
                  'Calculus Detected',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          )
        : Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 20,
                ),
                SizedBox(width: 4),
                Text(
                  'No Calculus',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );

    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detection Result',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      topPrediction['class'].toString().toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                severityIndicator,
              ],
            ),
            SizedBox(height: 20),
            Text(
              'Model Confidence',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: topPrediction['confidence'],
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    minHeight: 20,
                  ),
                ),
                Positioned.fill(
                  child: Center(
                    child: Text(
                      '${confidence.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            offset: Offset(1, 1),
                            blurRadius: 2,
                            color: Colors.black38,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Text(
              'Recommendation',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            Text(
              hasCalculus
                  ? 'Schedule a dental cleaning to remove calculus buildup'
                  : 'Continue maintaining good oral hygiene',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Dental Calculus Classification"),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_image != null)
                Container(
                  height: 300,
                  width: double.infinity,
                  child: isLoading
                      ? Center(child: CircularProgressIndicator())
                      : Image.file(
                          _image!,
                          fit: BoxFit.contain,
                        ),
                )
              else
                Container(
                  height: 300,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                  ),
                  child: Center(
                    child: ElevatedButton.icon(
                      onPressed: pickImage,
                      icon: Icon(Icons.add_a_photo),
                      label: Text("Pick an Image"),
                    ),
                  ),
                ),
              if (!isLoading &&
                  _result != null &&
                  _result!['predictions'] != null &&
                  (_result!['predictions'] as List).isNotEmpty)
                _buildPredictionCard((_result!['predictions'] as List).first),
              if (_result != null && _result!['error'] != null)
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    _result!['error'],
                    style: TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
