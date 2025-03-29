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
  const CalculusPredictor({super.key});

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
      print('Current user ID: ${_auth.currentUser?.uid}');

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName =
          'calculus_detection_$timestamp${path.extension(imageFile.path)}';

      final storageRef = _storage
          .ref()
          .child('users')
          .child(_auth.currentUser!.uid)
          .child('calculus_detection_images')
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
          .collection('calculus_detection')
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

  Future<void> _askToSaveResults() {
    ScaffoldMessenger.of(context).clearSnackBars();
    return ScaffoldMessenger.of(context)
        .showSnackBar(
          SnackBar(
            content: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                      'Would you like to save this result for personalized insights?'),
                ),
                SnackBarAction(
                  label: 'Yes',
                  textColor: Colors.white,
                  onPressed: () async {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    await _saveResultToFirebase();
                  },
                ),
                SnackBarAction(
                  label: 'No',
                  textColor: Colors.white70,
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  },
                ),
              ],
            ),
            backgroundColor: Colors.blue,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16),
            duration: Duration(days: 1),
          ),
        )
        .closed;
  }

  Future<void> pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        isLoading = true;
      });

      await _sendImageToApi(_image!);

      setState(() {
        isLoading = false;
      });

      if (_result != null && !_result!.containsKey('error')) {
        await _askToSaveResults();
      }
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
              color: Colors.red.withValues(alpha: 0.2),
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
              color: Colors.green.withValues(alpha: 0.2),
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

  Widget _buildMedicalDisclaimer() {
    return Container(
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Medical Disclaimer',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'This app is for informational purposes only and should not be used as a substitute for professional medical advice. Please consult your dentist or healthcare provider before making any medical decisions based on the results from this app.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Dental Calculus Classification"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _image == null
          ? _buildEmptyState()
          : SingleChildScrollView(
              child: Column(
                children: [
                  if (_image != null)
                    isLoading
                        ? SizedBox(
                            height: 300,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text(
                                    'Analyzing image...',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Column(
                            children: [
                              SizedBox(
                                height: 300,
                                width: double.infinity,
                                child: Image.file(
                                  _image!,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              if (!isLoading &&
                                  _result != null &&
                                  _result!['predictions'] != null &&
                                  (_result!['predictions'] as List).isNotEmpty)
                                _buildPredictionCard(
                                    (_result!['predictions'] as List).first),
                              Padding(
                                padding: EdgeInsets.all(16),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () =>
                                          pickImage(ImageSource.camera),
                                      icon: Icon(
                                        Icons.camera_alt,
                                        color: Colors.white,
                                      ),
                                      label: Text("New Photo"),
                                      style: ElevatedButton.styleFrom(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () =>
                                          pickImage(ImageSource.gallery),
                                      icon: Icon(
                                        Icons.photo_library,
                                        color: Colors.white,
                                      ),
                                      label: Text("New Image"),
                                      style: ElevatedButton.styleFrom(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _buildMedicalDisclaimer(),
                            ],
                          ),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.all(24),
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.add_a_photo_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
          ),
          SizedBox(height: 24),
          Text(
            "Analyze Dental Calculus",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),
          Text(
            "Take or select a clear photo of your teeth to detect signs of calculus",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => pickImage(ImageSource.camera),
            icon: Icon(
              Icons.camera_alt,
              color: Colors.white,
            ),
            label: Text("Take Photo"),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => pickImage(ImageSource.gallery),
            icon: Icon(Icons.photo_library),
            label: Text("Choose from Gallery"),
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}
