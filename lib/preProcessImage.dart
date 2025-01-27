import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:file_picker/file_picker.dart';

Future<List<double>> _preprocessImage(PlatformFile imageFile) async {
  // Read the image file
  final bytes = await File(imageFile.path!).readAsBytes();
  var image = img.decodeImage(bytes);

  if (image == null) {
    throw Exception('Failed to decode image');
  }

  // Resize the image to 224x224
  image = img.copyResize(image, width: 224, height: 224);

  // Convert to RGB if needed
  if (image.numChannels != 3) {
    image = img.colorConvert(image, img.ColorSpace.rgb);
  }

  // Initialize the output tensor
  final tensorSize = 3 * 224 * 224;
  final tensor = List<double>.filled(tensorSize, 0.0);

  // ShuffleNet preprocessing:
  // 1. Convert to float (0-1)
  // 2. Normalize using ImageNet mean and std
  // 3. Convert to CHW format (channels first)

  final meanValues = [0.485, 0.456, 0.406]; // ImageNet mean
  final stdValues = [0.229, 0.224, 0.225]; // ImageNet std

  for (var y = 0; y < 224; y++) {
    for (var x = 0; x < 224; x++) {
      final pixel = image.getPixel(x, y);

      // Extract RGB values (0-255)
      final r = pixel.r.toDouble();
      final g = pixel.g.toDouble();
      final b = pixel.b.toDouble();

      // Convert to float and normalize
      final normalizedR = ((r / 255.0) - meanValues[0]) / stdValues[0];
      final normalizedG = ((g / 255.0) - meanValues[1]) / stdValues[1];
      final normalizedB = ((b / 255.0) - meanValues[2]) / stdValues[2];

      // Store in CHW format
      // R channel
      tensor[y * 224 + x] = normalizedR;
      // G channel
      tensor[224 * 224 + y * 224 + x] = normalizedG;
      // B channel
      tensor[2 * 224 * 224 + y * 224 + x] = normalizedB;
    }
  }

  return tensor;
}
