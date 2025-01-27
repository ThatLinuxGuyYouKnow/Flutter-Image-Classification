import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:file_picker/file_picker.dart';

Future<Float32List> preprocessImage(
  PlatformFile imageFile, {
  int targetWidth = 224,
  int targetHeight = 224,
  List<double> meanValues = const [0.485, 0.456, 0.406],
  List<double> stdValues = const [0.229, 0.224, 0.225],
}) async {
  // Validate input file path
  if (imageFile.path == null) {
    throw Exception('Image file path is null');
  }

  // Read the image file
  final bytes = await File(imageFile.path!).readAsBytes();
  var image = img.decodeImage(bytes);

  if (image == null) {
    throw Exception('Failed to decode image');
  }

  // Resize the image to the target size
  image = img.copyResize(image, width: targetWidth, height: targetHeight);

  // Convert to RGB if needed
  if (image.numChannels != 3) {
    image = _convertToRgb(image);
  }

  // Initialize the output tensor
  final tensorSize = 3 * targetWidth * targetHeight;
  final tensor = Float32List(tensorSize);

  // Preprocessing steps:
  // 1. Convert pixel values to float (0-1)
  // 2. Normalize using mean and std
  // 3. Convert to CHW format (channels first)

  for (var y = 0; y < targetHeight; y++) {
    for (var x = 0; x < targetWidth; x++) {
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
      tensor[y * targetWidth + x] = normalizedR;
      // G channel
      tensor[targetWidth * targetHeight + y * targetWidth + x] = normalizedG;
      // B channel
      tensor[2 * targetWidth * targetHeight + y * targetWidth + x] =
          normalizedB;
    }
  }

  return tensor;
}

/// Converts an image to RGB format (3 channels).
img.Image _convertToRgb(img.Image image) {
  final rgbImage =
      img.Image(width: image.width, height: image.height, numChannels: 3);

  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      rgbImage.setPixelRgb(x, y, pixel.r, pixel.g, pixel.b);
    }
  }

  return rgbImage;
}
