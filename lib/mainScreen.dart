import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:object_detection_flutter/inferImage.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  PlatformFile? imageToBeInferred;

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          imageToBeInferred = result.files.first;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File picked: ${imageToBeInferred!.name}')),
        );
        inferFromImage(imageToBeInferred!);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No file picked.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Classification'),
      ),
      body: Column(
        children: [
          const SizedBox(height: 100),
          GestureDetector(
            onTap: _pickFile,
            child: Container(
              width: double.infinity, // Responsive width
              height: 60,
              margin: const EdgeInsets.symmetric(
                  horizontal: 20), // Add margin for better spacing
              decoration: BoxDecoration(
                color: Colors.amberAccent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 30.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Upload Image for Inference'),
                      Icon(Icons.upload),
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
    );
  }
}
