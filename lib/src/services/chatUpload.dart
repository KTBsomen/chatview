// upload_service.dart

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:mime/mime.dart';

class UploadResponse {
  final String publicUrl;
  final String key;

  UploadResponse({required this.publicUrl, required this.key});
}

class UploadService {
  String baseUrl = 'https://chitzchat.com/api/storage/api/v1/upload-url';
  String APIKEY = 'test-api-key';
  UploadService({String? baseUrl, String? apiKey}) {
    if (apiKey != null) {
      APIKEY = apiKey;
    }
    if (baseUrl != null) {
      this.baseUrl = baseUrl;
    }
  }
  final Dio _dio = Dio();
  static final Map<String, CancelToken> _cancelTokens = {};
  static final Map<String, dynamic> _retryParams = {};

  Future<UploadResponse> uploadFile({
    required File file,
    required String path,
    required ValueNotifier<double> progressNotifier,
  }) async {
    final String fileName = file.path.split('/').last;
    final String contentType = _getContentType(file.path);
    final cancelToken = CancelToken();
    _cancelTokens[file.path] = cancelToken;

    // Step 1: Get presigned URL
    final res = await _dio.post(
      baseUrl,
      data: {
        'filename': fileName,
        'contentType': contentType,
        'path': path,
      },
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Authorization': ' Bearer $APIKEY'
        },
      ),
    );
    print('Response: ${res.data}');
    final uploadUrl = res.data['data']['uploadUrl'];
    final publicUrl = res.data['data']['publicUrl'];
    _retryParams[file.path] = {
      'fileName': fileName,
      'contentType': contentType,
      'path': path,
      'progressNotifier': progressNotifier,
      'file': file,
      'key': res.data['data']['key'],
      'uploadUrl': uploadUrl,
      'publicUrl': publicUrl,
    };
    // Step 2: Upload to presigned URL
    await _dio.put(
      uploadUrl,
      data: file.openRead(),
      options: Options(headers: {
        'Content-Type': contentType,
        'Content-Length': file.lengthSync().toString(),
      }),
      cancelToken: cancelToken,
      onSendProgress: (sent, total) {
        if (total > 0) {
          progressNotifier.value = sent / total;
        }
      },
    ).catchError((error) {
      if (error is DioException && error.type == DioExceptionType.cancel) {
        throw Exception('Upload cancelled');
      } else {
        throw Exception('Failed to upload file: ${error.toString()}');
      }
    });

    progressNotifier.value = 1.0;

    return UploadResponse(publicUrl: publicUrl, key: res.data['data']['key']);
  }

  static void cancelUpload(String filePath) {
    _cancelTokens[filePath]?.cancel('Upload cancelled');
    _cancelTokens.remove(filePath);
  }

  static bool isUploadCancelled(String filePath) {
    return _cancelTokens[filePath]?.isCancelled ?? false;
  }

  static Future<UploadResponse> retryUpload(String filePath,
      {ValueNotifier<double>? progressNotifier}) async {
    final cancelToken = CancelToken();
    _cancelTokens[filePath] = cancelToken;
    final file = File(filePath);
    final uploadService = UploadService();
    final retryParams = _retryParams[filePath];
    if (retryParams != null) {
      await uploadService._dio.put(
        retryParams['uploadUrl'],
        data: file.openRead(),
        options: Options(headers: {
          'Content-Type': retryParams['contentType'],
          'Content-Length': file.lengthSync().toString(),
        }),
        cancelToken: cancelToken,
        onSendProgress: (sent, total) {
          if (total > 0) {
            final progressNotifier0 =
                retryParams['progressNotifier'] as ValueNotifier<double>;
            if (progressNotifier0 == null && progressNotifier == null) {
              throw Exception('Progress notifier is null');
            } else if (progressNotifier != null) {
              progressNotifier.value = sent / total;
            } else {
              progressNotifier0.value = sent / total;
            }
          }
        },
      ).catchError((error) {
        if (error is DioException && error.type == DioExceptionType.cancel) {
          throw Exception('Upload cancelled');
        } else {
          throw Exception('Failed to retry upload: ${error.toString()}');
        }
      });
      progressNotifier?.value = 1.0;

      final publicUrl = retryParams['publicUrl'] as String;
      final key = retryParams['key'] as String;
      print('Upload successful: $publicUrl, Key: $key');

      _retryParams.remove(filePath);
      return UploadResponse(
        publicUrl: publicUrl,
        key: key,
      );
    }

    throw Exception('No retry parameters found for $filePath');
  }

  String _getContentType(String path) {
    final mimeType = lookupMimeType(path);
    return mimeType ?? 'application/octet-stream';
  }
}
