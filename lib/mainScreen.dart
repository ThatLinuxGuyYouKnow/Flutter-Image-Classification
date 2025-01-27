import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:object_detection_flutter/inferImage.dart';
import 'package:object_detection_flutter/loadLabel.dart';
import 'package:object_detection_flutter/postProcessLogits.dart';
import 'package:object_detection_flutter/preProcessImage.dart';
import 'package:onnxruntime/onnxruntime.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  PlatformFile? imageToBeInferred;
  String? predictedClass;
  List<double>? probabilities;
  bool isProcessing = false;
  Future<String?>? predictionFuture;
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  bool _isValidImageFile(String fileName) {
    final validExtensions = ['.jpg', '.jpeg', '.png', '.bmp'];
    return validExtensions.any((ext) => fileName.toLowerCase().endsWith(ext));
  }

  bool _isValidFileSize(int fileSize) {
    const maxSize = 10 * 1024 * 1024; // 10MB in bytes
    return fileSize <= maxSize;
  }

  Future<String?> processImage(PlatformFile file) async {
    try {
      final outputs = await inferFromImage(file);

      if (outputs == null || outputs.isEmpty) {
        throw Exception('Failed to process image. No output generated.');
      }

      final outputTensor = outputs[0];
      if (outputTensor == null || outputTensor is! OrtValueTensor) {
        throw Exception('Invalid model output format.');
      }

      final rawOutput = outputTensor.value;
      List<double> outputList;

      if (rawOutput is List<List<double>>) {
        outputList = rawOutput[0];
      } else if (rawOutput is List<List>) {
        outputList = rawOutput[0]
            .map((e) => e is double ? e : double.parse(e.toString()))
            .toList();
      } else if (rawOutput is List) {
        outputList = rawOutput
            .map((e) => e is double ? e : double.parse(e.toString()))
            .toList();
      } else {
        throw FormatException(
            'Unexpected output format: ${rawOutput.runtimeType}');
      }

      final probs = softmax(outputList);
      final predictedIndex = argmax(probs);
      return await getPredictedLabel(predictedIndex);
    } catch (e) {
      _showError(e.toString());
      return null;
    }
  }

  Future<void> _pickFile() async {
    if (isProcessing) {
      _showError('Please wait for the current processing to complete.');
      return;
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['jpg', 'jpeg', 'png', 'bmp'],
          withData: true);

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;

      if (!_isValidImageFile(file.name) || !_isValidFileSize(file.size)) return;

      setState(() {
        imageToBeInferred = file;
        predictionFuture = processImage(file);
        isProcessing = true;
      });
    } finally {
      setState(() {
        isProcessing = false;
      });
    }
  }

  void _reset() {
    setState(() {
      imageToBeInferred = null;
      predictionFuture = null;
    });
  }

  @override
  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    // Calculate responsive dimensions
    double cardWidth = screenWidth < 600
        ? screenWidth * 0.9
        : screenWidth < 1200
            ? screenWidth / 2.5
            : screenWidth / 3;

    double cardHeight = screenHeight < 800 ? screenHeight * 0.6 : 400;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: 40,
        backgroundColor: Colors.white,
        title: Text('Image Classifier',
            style: GoogleFonts.plusJakartaSans(
              fontSize: screenWidth < 600 ? 24 : 30,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            )),
        bottom: PreferredSize(
          child: Divider(
            color: Colors.grey,
          ),
          preferredSize: Size.fromHeight(40),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth < 600 ? 16.0 : 20.0,
              vertical: 20.0,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: imageToBeInferred == null
                  ? _buildInitialUploadCard(cardWidth, cardHeight)
                  : _buildResultCard(cardWidth, cardHeight),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInitialUploadCard(double cardWidth, double cardHeight) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        height: cardHeight,
        width: cardWidth,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_upload_outlined,
                size: 60,
                color: Colors.greenAccent,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Upload an Image',
              style: GoogleFonts.plusJakartaSans(
                fontSize: cardWidth < 400 ? 20 : 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Select a photo to classify',
              style: GoogleFonts.plusJakartaSans(
                fontSize: cardWidth < 400 ? 14 : 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 30),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: ElevatedButton(
                onPressed: _pickFile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  padding: EdgeInsets.symmetric(
                    horizontal: cardWidth < 400 ? 30 : 40,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 2,
                ),
                child: Text(
                  'Choose File',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: cardWidth < 400 ? 14 : 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(double cardWidth, double cardHeight) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        height: cardHeight,
        width: cardWidth,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (imageToBeInferred?.bytes != null)
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.memory(
                    imageToBeInferred!.bytes!,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            const SizedBox(height: 20),
            FutureBuilder<String?>(
              future: predictionFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Column(
                    children: [
                      const CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Processing image...',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: cardWidth < 400 ? 14 : 16,
                        ),
                      ),
                    ],
                  );
                }

                if (snapshot.hasError) {
                  return Text(
                    'Error: ${snapshot.error}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: cardWidth < 400 ? 14 : 16,
                      color: Colors.red,
                    ),
                  );
                }

                if (snapshot.hasData && snapshot.data != null) {
                  return Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Prediction Result',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: cardWidth < 400 ? 16 : 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          snapshot.data!,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: cardWidth < 400 ? 20 : 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return const SizedBox.shrink();
              },
            ),
            const SizedBox(height: 20),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: ElevatedButton.icon(
                onPressed: _reset,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 2,
                ),
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: Text(
                  'Try Another Image',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: cardWidth < 400 ? 14 : 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
