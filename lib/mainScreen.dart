import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
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

  // Custom error handling method
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

  // Validate file type
  bool _isValidImageFile(String fileName) {
    final validExtensions = ['.jpg', '.jpeg', '.png', '.bmp'];
    return validExtensions.any((ext) => fileName.toLowerCase().endsWith(ext));
  }

  // File size validation (max 10MB)
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
      // Configure file picker for images only
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'bmp'],
      );

      if (result == null || result.files.isEmpty) {
        _showError('No file was selected.');
        return;
      }

      final file = result.files.first;

      // Validate file
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

      // Run inference
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

        // Handle 2D output tensor (shape [1, num_classes])
        List<double> outputList;
        if (rawOutput is List<List<double>>) {
          // Take first row since shape is [1, num_classes]
          outputList = rawOutput[0];
        } else if (rawOutput is List<List>) {
          // Convert nested list elements to double
          outputList = rawOutput[0]
              .map((e) => e is double ? e : double.parse(e.toString()))
              .toList();
        } else if (rawOutput is List) {
          // Handle case where output might be flattened
          outputList = rawOutput
              .map((e) => e is double ? e : double.parse(e.toString()))
              .toList();
        } else {
          throw FormatException(
              'Unexpected output format: ${rawOutput.runtimeType}');
        }

        // Add debug prints
        print('Raw output type: ${rawOutput.runtimeType}');
        print('Processed output type: ${outputList.runtimeType}');
        print('Output shape: ${outputList.length}');

        // Apply softmax and get predictions
        final probs = softmax(outputList);
        final predictedIndex = argmax(probs);
        getPredictedLabel(predictedIndex);
        setState(() {
          predictedClass = 'Class $predictedIndex';
          probabilities = probs;
        });
      } catch (e) {
        print('Debug - Error details: $e');
        print('Debug - Raw output type: ${outputTensor.value.runtimeType}');
        print('Debug - Raw output: ${outputTensor.value}');
        _showError('Error processing model output: ${e.toString()}');
      }
    } finally {
      setState(() {
        isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Classification'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 100),
            imageToBeInferred != null
                ? Image(
                    image: AssetImage(imageToBeInferred.toString()),
                  )
                : SizedBox.shrink(),
            const SizedBox(height: 100),
            GestureDetector(
              onTap: _pickFile,
              child: Container(
                width: double.infinity,
                height: 60,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: isProcessing ? Colors.grey : Colors.amberAccent,
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
                          style: TextStyle(
                            color: isProcessing ? Colors.white : Colors.black,
                          ),
                        ),
                        Icon(
                          isProcessing ? Icons.hourglass_empty : Icons.upload,
                          color: isProcessing ? Colors.white : Colors.black,
                        ),
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
            if (predictedClass != null)
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text('Predicted class: $predictedClass'),
              ),
            if (probabilities != null)
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text('Probabilities: $probabilities'),
              ),
          ],
        ),
      ),
    );
  }
}
