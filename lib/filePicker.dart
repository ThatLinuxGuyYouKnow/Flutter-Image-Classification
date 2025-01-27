import 'package:file_picker/file_picker.dart';

Future<PlatformFile?> pickFile() async {
  try {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    // Check if the user canceled the file picker
    if (result == null) {
      return null;
    }

    // Check if the files list is not empty
    if (result.files.isNotEmpty) {
      PlatformFile file = result.files.first;
      return file;
    } else {
      // Handle the case where no file was selected
      return null;
    }
  } catch (e) {
    // Handle any errors that occur during the file picking process
    print("Error picking file: $e");
    return null;
  }
}
