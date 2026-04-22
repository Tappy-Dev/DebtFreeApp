import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final bytes = File('assets/images/app_icon.png').readAsBytesSync();
  final image = img.decodePng(bytes)!;
  final resized = img.copyResize(image, width: 256, height: 256);
  final ico = img.encodeIco(resized);
  File('windows/runner/resources/app_icon.ico').writeAsBytesSync(ico);
  print('Windows icon updated.');
}
