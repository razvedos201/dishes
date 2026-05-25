import 'dart:io';
import 'package:flutter/material.dart';

// На мобильных/десктопе картинки лежат файлами на диске — проверяем существование
// и показываем через Image.file.
bool hasLocalImage(String? path) {
  if (path == null) return false;
  try {
    return File(path).existsSync();
  } catch (_) {
    return false;
  }
}

Widget buildLocalImage(
  String path, {
  double? width,
  double? height,
  BoxFit? fit,
}) {
  return Image.file(
    File(path),
    width: width,
    height: height,
    fit: fit,
  );
}

// Возвращает что-то совместимое с XFile-путём для шаринга картинки через share_plus.
// На мобильных это просто путь к файлу.
String? localImagePathForShare(String? path) {
  return hasLocalImage(path) ? path : null;
}
