import 'package:file_picker/file_picker.dart';

pickFile() async {
  FilePickerResult? result = await FilePicker.platform.pickFiles();

  if (result != null) {
    PlatformFile file = result.files.first;
    return file;
  } else {
    // User canceled the picker
  }
}
