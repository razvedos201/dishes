import 'package:flutter/material.dart';

// В веб-версии картинки блюд не поддерживаются — image_picker в UI скрыт,
// imagePath в JSON всегда нормализуется к null. Этот хелпер существует только
// для того, чтобы экраны компилировались под web.
bool hasLocalImage(String? path) => false;

Widget buildLocalImage(
  String path, {
  double? width,
  double? height,
  BoxFit? fit,
}) {
  // Никогда не вызывается, так как hasLocalImage всегда false.
  return const SizedBox.shrink();
}

String? localImagePathForShare(String? path) => null;
