import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import 'failure.dart';

class ErrorHandler {
  static Failure handle(Object error) {
    if (error is DioException) {
      return _handleDioError(error);
    }
    return ServerFailure(message: error.toString());
  }

  static Failure _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const NetworkFailure(message: 'Connection timeout');
      case DioExceptionType.connectionError:
        return const NetworkFailure(message: 'No internet connection');
      case DioExceptionType.cancel:
        return const ServerFailure(message: 'Request cancelled');
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final message = _extractMessage(error.response?.data) ?? 'Server error';
        return ServerFailure(message: message, statusCode: statusCode);
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return ServerFailure(message: error.message ?? 'Unknown error');
    }
  }

  static String? _extractMessage(Object? data) {
    if (data is Map<String, dynamic>) {
      final message = data['message'] ?? data['error'];
      if (message is String) return message;
    }
    return null;
  }
}

mixin HandlingMixin {
  Future<Either<Failure, T>> wrapHandling<T>({
    required Future<T> Function() tryCall,
  }) async {
    try {
      final result = await tryCall();
      return Right(result);
    } catch (error) {
      return Left(ErrorHandler.handle(error));
    }
  }
}
