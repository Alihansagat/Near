import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:near/api.dart';
import 'dart:typed_data';

void main() {
  test(
      'Photo upload reads bytes, including browser blob files without a filesystem path',
      () async {
    final api = Api();
    List<int>? received;
    api.dio.interceptors
        .add(InterceptorsWrapper(onRequest: (request, handler) async {
      final body = request.data as FormData;
      received = await body.files.single.value
          .finalize()
          .fold<List<int>>([], (all, chunk) => all..addAll(chunk));
      handler.resolve(Response(requestOptions: request, statusCode: 201));
    }));
    await api.upload(XFile.fromData(Uint8List.fromList([1, 2, 3]),
        name: 'photo.png', mimeType: 'image/png'));
    expect(received, [1, 2, 3]);
  });
}
