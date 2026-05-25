import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

// На мобильных/десктопе: пишем во временную папку и отдаём через системный шаринг.
Future<void> shareOrDownloadJson({
  required String jsonContent,
  required String filename,
  required String subject,
  String? text,
}) async {
  final dir = await getTemporaryDirectory();
  final file = File(p.join(dir.path, filename));
  await file.writeAsString(jsonContent);
  await Share.shareXFiles(
    [XFile(file.path)],
    subject: subject,
    text: text,
  );
}
