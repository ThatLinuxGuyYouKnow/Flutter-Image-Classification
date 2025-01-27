import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:object_detection_flutter/preProcessImage.dart';
import 'package:onnxruntime/onnxruntime.dart';

Future<List<OrtValue?>?> inferFromImage(PlatformFile imageToBeInferred) async {
  // Step 1: Load the ONNX model
  const assetFileName = 'assets/models/shufflenet-v2-12.onnx';
  final rawAssetFile = await rootBundle.load(assetFileName);
  final bytes = rawAssetFile.buffer.asUint8List();

  // Step 2: Initialize the ONNX runtime session
  final sessionOptions = OrtSessionOptions();
  late OrtSession session;
  try {
    session = OrtSession.fromBuffer(bytes, sessionOptions);
  } catch (e) {
    print('Failed to initialize ONNX session: $e');
    rethrow;
  }

  // Step 3: Preprocess the image
  // TODO: Implement image preprocessing (e.g., resize, normalize, convert to tensor)
  // For now, assume `imageData` is a preprocessed tensor
  final imageData = await preprocessImage(imageToBeInferred);

  // Step 4: Prepare the input tensor
  final inputShape = [
    1,
    3,
    224,
    224
  ]; // Example shape, adjust based on your model
  late OrtValue inputOrt;
  try {
    inputOrt = OrtValueTensor.createTensorWithDataList(imageData, inputShape);
  } catch (e) {
    print('Failed to create input tensor: $e');
    rethrow;
  }

  // Step 5: Run inference
  final inputs = {'input': inputOrt};
  final runOptions = OrtRunOptions();
  List<OrtValue?>? outputs;
  try {
    outputs = await session.runAsync(runOptions, inputs);
  } catch (e) {
    print('Inference failed: $e');
    rethrow;
  } finally {
    // Release resources
    inputOrt.release();
    runOptions.release();
  }

  // Step 6: Return the outputs (caller is responsible for releasing them)
  print(await outputs.toString());
  return outputs;
}
