import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

class PlaquePredictor extends StatefulWidget {
  const PlaquePredictor({super.key});

  @override
  _PlaquePredictorState createState() => _PlaquePredictorState();
}

class _PlaquePredictorState extends State<PlaquePredictor> {
  File? _originalImage;
  Image? _resultImage;
  bool isLoading = false;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _auth = FirebaseAuth.instance;
  String? _lastReturnedBase64;

  Future<String?> _uploadImageToStorage(File imageFile, bool isResult) async {
    if (_auth.currentUser == null) {
      print('No user is currently logged in');
      return null;
    }
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = isResult
          ? 'plaque_result_$timestamp${path.extension(imageFile.path)}'
          : 'plaque_original_$timestamp${path.extension(imageFile.path)}';

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

  Future<void> _saveResultToFirebase(String base64Result) async {
    if (_auth.currentUser == null || _originalImage == null) return;

    try {
      final originalImageUrl =
          await _uploadImageToStorage(_originalImage!, false);

      final bytes = base64Decode(base64Result);
      final tempDir = Directory.systemTemp;
      final resultFile = File('${tempDir.path}/result_image.png');
      await resultFile.writeAsBytes(bytes);

      final resultImageUrl = await _uploadImageToStorage(resultFile, true);

      if (originalImageUrl == null || resultImageUrl == null) {
        throw Exception('Failed to upload images');
      }

      final predictionData = {
        'timestamp': FieldValue.serverTimestamp(),
        'originalImageUrl': originalImageUrl,
        'resultImageUrl': resultImageUrl,
      };

      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('plaque_detection')
          .add(predictionData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Results and images saved successfully'),
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

  Future<void> _askToSaveResults(String base64Result) {
    ScaffoldMessenger.of(context).clearSnackBars();
    return ScaffoldMessenger.of(context)
        .showSnackBar(
          SnackBar(
            content: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text('Would you like to save this result?'),
                ),
                SnackBarAction(
                  label: 'Yes',
                  textColor: Colors.white,
                  onPressed: () async {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    await _saveResultToFirebase(base64Result);
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
    final shouldContinue = await _showUVDeviceReminder();
    if (!shouldContinue) return;
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _originalImage = File(pickedFile.path);
        _resultImage = null;
        isLoading = true;
      });

      await _sendImageToApi(_originalImage!);

      setState(() {
        isLoading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_resultImage != null && mounted) {
          _askToSaveResults(_lastReturnedBase64!);
        }
      });
    }
  }

  Future<void> _sendImageToApi(File imageFile) async {
    try {
      List<int> imageBytes = await imageFile.readAsBytes();
      String base64Image = base64Encode(imageBytes);

      final response = await http.post(
        Uri.parse(
            'https://detect.roboflow.com/infer/workflows/isef-se7fz/custom-workflow'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'api_key': 'qT7vcv1pFkSk3smKEGHS',
          'inputs': {
            'image': {
              'type': 'base64',
              'value': base64Image,
            },
          },
        }),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        print(json);
        final returnedBase64 = json['outputs'][0]['output']['value'];

        _lastReturnedBase64 = returnedBase64;

        setState(() {
          _resultImage = Image.memory(base64Decode(returnedBase64));
        });
      } else {
        throw Exception('Failed to process image');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing image: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  Widget _buildColorLegend() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detection Legend:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Table(
            border: TableBorder.all(
              color: Colors.grey[300]!,
              width: 1,
            ),
            children: [
              TableRow(
                children: [
                  TableCell(
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            color: Color(0xFFE75480),
                          ),
                          SizedBox(width: 8),
                          Text('Plaque'),
                        ],
                      ),
                    ),
                  ),
                  TableCell(
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            color: Color(0xFF74EE15),
                          ),
                          SizedBox(width: 8),
                          Text('Calculus'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
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
        title: Text("Plaque Detection"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _originalImage == null ? _buildEmptyState() : _buildResultView(),
    );
  }

  Widget _buildResultView() {
    return SingleChildScrollView(
      child: Column(
        children: [
          if (isLoading)
            _buildLoadingView()
          else
            Column(
              children: [
                _buildImageContainer(_originalImage!, "Original Image"),
                if (_resultImage != null) ...[
                  _buildImageContainer(_resultImage!, "Detection Result"),
                  _buildColorLegend(),
                ],
                _buildActionButtons(),
                _buildMedicalDisclaimer(),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildImageContainer(dynamic image, String label) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Container(
            constraints: BoxConstraints(maxWidth: 300),
            child: image is File ? Image.file(image) : image,
          ),
        ],
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
            "Analyze Plaque",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),
          Text(
            "Take or select a clear photo of your teeth to detect plaque buildup.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              pickImage(ImageSource.camera);
            },
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

  Widget _buildLoadingView() {
    return SizedBox(
      height: 300,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Processing image...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            onPressed: () => pickImage(ImageSource.camera),
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
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => pickImage(ImageSource.gallery),
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
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _showUVDeviceReminder() async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Important Reminder'),
            content: Text(
              'Please ensure you are using an intraoral or extraoral UV emitting device before taking the photo for accurate plaque detection.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Continue'),
              ),
            ],
          ),
        ) ??
        false;
  }
}
