import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class GingivitisPredictor extends StatefulWidget {
  @override
  _GingivitisPredictorState createState() => _GingivitisPredictorState();
}

class _GingivitisPredictorState extends State<GingivitisPredictor> {
  File? _image;
  Map<String, dynamic>? _result;
  double imageWidth = 1;
  double imageHeight = 1;
  bool isLoading = false;

  Future<void> pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        isLoading = true;
      });

      final decodedImage = await decodeImageFromList(_image!.readAsBytesSync());
      setState(() {
        imageWidth = decodedImage.width.toDouble();
        imageHeight = decodedImage.height.toDouble();
      });

      await _sendImageToApi(_image!);

      setState(() {
        isLoading = false;
      });
    }
  }

  String prettyPrintJson(Map<String, dynamic> json) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(json);
  }

  Future<void> _sendImageToApi(File imageFile) async {
    try {
      List<int> imageBytes = await imageFile.readAsBytes();
      String base64Image = base64Encode(imageBytes);

      var response = await http.post(
        Uri.parse(
            "https://outline.roboflow.com/gingivitis-8izag/1?api_key=qT7vcv1pFkSk3smKEGHS"),
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: base64Image,
      );

      if (response.statusCode == 200) {
        setState(() {
          _result = json.decode(response.body);
          debugPrint(prettyPrintJson(_result!));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text("Gingivitis Detection"),
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
                          ? Container(
                              height: 300, // Match the image container height
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
                                AspectRatio(
                                  aspectRatio: imageWidth / imageHeight,
                                  child: Container(
                                    constraints: BoxConstraints(maxWidth: 300),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.file(
                                          _image!,
                                          fit: BoxFit.contain,
                                        ),
                                        if (_result != null &&
                                            _result!['predictions'] != null)
                                          CustomPaint(
                                            painter: PolygonPainter(
                                              _result!['predictions'],
                                              imageWidth,
                                              imageHeight,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (_result != null &&
                                    _result!['predictions'] != null)
                                  ResultsLegend(
                                      predictions: _result!['predictions']),
                                if (_result != null &&
                                    _result!['error'] != null)
                                  Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Text(
                                      "Error: ${_result!['error']}",
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
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
                              ],
                            ),
                  ],
                ),
              ));
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
            "Analyze Gum Health",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),
          Text(
            "Take or select a clear photo of your teeth to detect signs of gingivitis",
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
}

class PolygonPainter extends CustomPainter {
  final List<dynamic> predictions;
  final double imageWidth;
  final double imageHeight;

  PolygonPainter(this.predictions, this.imageWidth, this.imageHeight);

  Color getClassColor(String classNum) {
    switch (classNum) {
      case "0": // Upper Teeth
        return Colors.blue.withOpacity(0.3);
      case "1": // Lower Teeth
        return Colors.green.withOpacity(0.3);
      case "2": // Very Mild
        return Colors.yellow.withOpacity(0.3);
      case "3": // Mild
        return Colors.orange.withOpacity(0.3);
      case "4": // Moderate
        return Colors.deepOrange.withOpacity(0.3);
      case "5": // Severe
        return Colors.red.withOpacity(0.3);
      case "6": // Very Severe
        return Colors.purple.withOpacity(0.3);
      default:
        return Colors.grey.withOpacity(0.3);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (var prediction in predictions) {
      if (prediction['points'] != null) {
        var points = prediction['points'].map<Offset>((point) {
          return Offset(
            point['x'] * size.width / imageWidth,
            point['y'] * size.height / imageHeight,
          );
        }).toList();

        final paint = Paint()
          ..color = getClassColor(prediction['class'].toString())
          ..strokeWidth = 2
          ..style = PaintingStyle.fill;

        var path = Path();
        path.addPolygon(points.cast<Offset>(), true);
        canvas.drawPath(path, paint);

        // Draw border with more opacity
        paint.style = PaintingStyle.stroke;
        paint.color =
            getClassColor(prediction['class'].toString()).withOpacity(0.8);
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class ResultsLegend extends StatelessWidget {
  final List<dynamic> predictions;

  ResultsLegend({required this.predictions});

  Color getClassColor(String classNum) {
    switch (classNum) {
      case "0":
        return Colors.blue.withOpacity(0.3);
      case "1":
        return Colors.green.withOpacity(0.3);
      case "2":
        return Colors.yellow.withOpacity(0.3);
      case "3":
        return Colors.orange.withOpacity(0.3);
      case "4":
        return Colors.deepOrange.withOpacity(0.3);
      case "5":
        return Colors.red.withOpacity(0.3);
      case "6":
        return Colors.purple.withOpacity(0.3);
      default:
        return Colors.grey.withOpacity(0.3);
    }
  }

  Map<String, List<dynamic>> groupPredictions() {
    Map<String, List<dynamic>> groups = {};
    for (var prediction in predictions) {
      String classNum = prediction['class'].toString();
      groups.putIfAbsent(classNum, () => []);
      groups[classNum]!.add(prediction);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    Map<String, List<dynamic>> groupedPredictions = groupPredictions();
    bool hasGingivitis = groupedPredictions.keys.any((k) => int.parse(k) >= 2);

    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Scanned Regions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            if (groupedPredictions.containsKey("0"))
              _buildRegionIndicator("0", "Upper Teeth Region"),
            if (groupedPredictions.containsKey("1"))
              _buildRegionIndicator("1", "Lower Teeth Region"),
            Divider(height: 24),
            Text(
              'Analysis Results',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            if (!hasGingivitis)
              _buildHealthyMessage()
            else
              ...groupedPredictions.entries
                  .where((e) => int.parse(e.key) >= 2)
                  .map((entry) =>
                      _buildSeverityIndicator(entry.key, entry.value.length)),
          ],
        ),
      ),
    );
  }

  Widget _buildRegionIndicator(String classNum, String label) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: getClassColor(classNum),
              border: Border.all(
                color: getClassColor(classNum).withOpacity(0.8),
              ),
            ),
          ),
          SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildSeverityIndicator(String classNum, int count) {
    String severityLabel = getSeverityLabel(classNum);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: getClassColor(classNum),
              border: Border.all(
                color: getClassColor(classNum).withOpacity(0.8),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              '$severityLabel (${count} ${count == 1 ? 'tooth' : 'teeth'})',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthyMessage() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 24,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'No gingivitis detected. Your gums appear healthy!',
              style: TextStyle(
                fontSize: 16,
                color: Colors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String getSeverityLabel(String classNum) {
    switch (classNum) {
      case "2":
        return "Very Mild Gingivitis";
      case "3":
        return "Mild Gingivitis";
      case "4":
        return "Moderate Gingivitis";
      case "5":
        return "Severe Gingivitis";
      case "6":
        return "Very Severe Gingivitis";
      default:
        return "Unknown";
    }
  }
}
