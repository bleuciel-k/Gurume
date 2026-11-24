import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

@JS('oreguruShare.shareOrDownloadPng')
external JSPromise<JSString?> _jsShareOrDownloadPng(
  String base64Png,
  String fileName,
  String shareText,
);

/// 웹 브라우저에서 Web Share API(지원 시) 또는 PNG 다운로드 트리거
Future<String?> exportClayPosterPng(
  Uint8List pngBytes, {
  required String fileName,
  required String shareText,
}) async {
  try {
    final encoded = base64Encode(pngBytes);
    final res = await _jsShareOrDownloadPng(encoded, fileName, shareText).toDart;
    return res?.toDart ?? fileName;
  } catch (_) {
    return null;
  }
}
