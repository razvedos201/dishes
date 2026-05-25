import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

// На веб-версии: скачиваем JSON как файл через Blob + <a download>. Web Share API
// для файлов поддерживается не везде (особенно iOS Safari), поэтому надёжнее
// просто положить файл пользователю в Загрузки — он сам отправит куда нужно.
Future<void> shareOrDownloadJson({
  required String jsonContent,
  required String filename,
  required String subject,
  String? text,
}) async {
  final bytes = utf8.encode(jsonContent);
  final blob = html.Blob([bytes], 'application/json');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
