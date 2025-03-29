import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ImagePickerDemo extends StatefulWidget {
  @override
  _ImagePickerDemoState createState() => _ImagePickerDemoState();
}

class _ImagePickerDemoState extends State<ImagePickerDemo> {
  File? _image;
  Map<String, dynamic>? _result;
  double imageWidth = 1;
  double imageHeight = 1;
  bool isLoading = false;

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

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
            "https://outline.roboflow.com/bone-loss-in-xrays/2?api_key=EuoS0h1LGP4kF72nbcfC"),
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
      appBar: AppBar(title: Text("Image Picker Demo")),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_image != null)
                isLoading
                    ? CircularProgressIndicator()
                    : AspectRatio(
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
                      )
              else
                Text("No image selected."),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: pickImage,
                child: Text("Pick an Image"),
              ),
              SizedBox(height: 20),
              if (_result != null && _result!['error'] != null)
                Text("Error: ${_result!['error']}")
              else if (!isLoading && _result == null)
                Text("No result available."),
            ],
          ),
        ),
      ),
    );
  }
}

class PolygonPainter extends CustomPainter {
  final List<dynamic> predictions;
  final double imageWidth;
  final double imageHeight;

  PolygonPainter(this.predictions, this.imageWidth, this.imageHeight);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (var prediction in predictions) {
      if (prediction['points'] != null) {
        var points = prediction['points'].map<Offset>((point) {
          return Offset(
            point['x'] * size.width / imageWidth,
            point['y'] * size.height / imageHeight,
          );
        }).toList();

        var path = Path();
        path.addPolygon(points.cast<Offset>(), true);
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
