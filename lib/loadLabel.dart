import 'dart:io'; // For file handling

Future<List<String>> loadLabels(String filePath) async {
  final file = File(filePath);
  final lines = await file.readAsLines();
  return lines; // Each line corresponds to a class label
}

Future<void> getPredictedLabel(int predictedIndex) async {
  // Load labels
  List<String> labels = await loadLabels('assets/labels.txt');

  // Check if the predicted index is valid
  if (predictedIndex < 0 || predictedIndex >= labels.length) {
    print('Invalid class index: $predictedIndex');
    return;
  }

  // Get the corresponding label
  String label = labels[predictedIndex];
  print('Predicted Label: $label');
}