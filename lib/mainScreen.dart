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

  Future<void> _pickFile() async {
    if (isProcessing) {
      _showError('Please wait for the current processing to complete.');
      return;
    }

    setState(() {
      isProcessing = true;
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'bmp'],
      );

      if (result == null || result.files.isEmpty) {
        _showError('No file was selected.');
        return;
      }

      final file = result.files.first;

      if (!_isValidImageFile(file.name)) {
        _showError('Please select a valid image file (JPG, PNG, or BMP).');
        return;
      }

      if (!_isValidFileSize(file.size)) {
        _showError('File size exceeds 10MB limit.');
        return;
      }

      setState(() {
        imageToBeInferred = file;
        predictedClass = null;
        probabilities = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Processing: ${file.name}'),
          duration: const Duration(seconds: 2),
        ),
      );

      final outputs = await inferFromImage(file);

      if (outputs == null || outputs.isEmpty) {
        _showError('Failed to process image. No output generated.');
        return;
      }

      final outputTensor = outputs[0];
      if (outputTensor == null || outputTensor is! OrtValueTensor) {
        _showError('Invalid model output format.');
        return;
      }

      try {
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

        String labelText = await getPredictedLabel(predictedIndex) ?? '';
        setState(() {
          predictedClass = labelText;
          probabilities = probs;
        });
      } catch (e) {
        print('Debug - Error details: $e');
        _showError('Error processing model output: ${e.toString()}');
      }
    } finally {
      setState(() {
        isProcessing = false;
      });
    }
  }

  void _reset() {
    setState(() {
      imageToBeInferred = null;
      predictedClass = null;
      probabilities = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        backgroundColor: Colors.greenAccent,
        title: Text('Image Classification',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 30,
              fontWeight: FontWeight.bold,
            )),
        titleSpacing: 20,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              if (imageToBeInferred != null && imageToBeInferred!.bytes != null)
                Image.memory(
                  imageToBeInferred!.bytes!,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              const SizedBox(height: 20),
              if (predictedClass != null)
                SizedBox(
                  width: double.infinity,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Predicted Class: $predictedClass',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _reset,
                        child: const Text('Try Another Image'),
                      ),
                    ],
                  ),
                ),
              if (predictedClass == null)
                GestureDetector(
                  onTap: _pickFile,
                  child: Container(
                    width: double.infinity,
                    height: 60,
                    decoration: BoxDecoration(
                      color: isProcessing ? Colors.grey : Colors.greenAccent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isProcessing
                                  ? 'Processing...'
                                  : 'Upload Image for Inference',
                              style:
                                  TextStyle(fontSize: 15, color: Colors.white),
                            ),
                            Icon(
                                isProcessing
                                    ? Icons.hourglass_empty
                                    : Icons.upload,
                                color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (imageToBeInferred != null)
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text('Selected file: ${imageToBeInferred!.name}'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
