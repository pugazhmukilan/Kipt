import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Picks an image from [source] so the user can attach a photo to an item.
///
/// Returns the file path of the picked image, or `null` if the user cancels.
class ImagePickerHelper {
  /// True while an OS-native picker (camera / gallery / file) is covering
  /// the app.
  ///
  /// Those pickers are separate activities, so the Flutter app is backgrounded
  /// while they are open. Without this flag, returning from the camera would
  /// be mistaken for the user "leaving the app" and the app-lock screen would
  /// re-trigger right after a photo is taken.
  static bool isPickerActive = false;

  /// Schedules clearing [isPickerActive] shortly after a picker closes.
  ///
  /// The app-lifecycle `resumed` callback can arrive just after the picker
  /// future completes, so we keep the flag set a little longer to cover it.
  static void endPickerSession() {
    Future.delayed(const Duration(seconds: 3), () {
      isPickerActive = false;
    });
  }

  static Future<String?> pick(
    BuildContext context,
    ImageSource source,
  ) async {
    isPickerActive = true;
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        // Always open the rear camera first — some devices ignore the package
        // default and launch the front lens.
        preferredCameraDevice: CameraDevice.rear,
        // Downscale camera captures to keep stored attachments reasonably sized
        // (avoids giant multi-megapixel originals), and re-encode to JPEG so
        // HEIC files are handled on all platforms.
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );
      return picked?.path;
    } finally {
      endPickerSession();
    }
  }
}