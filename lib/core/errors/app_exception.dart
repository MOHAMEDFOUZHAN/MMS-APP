import 'package:supabase_flutter/supabase_flutter.dart';

class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  AppException(this.message, {this.code, this.originalError});

  @override
  String toString() => message;

  static AppException from(dynamic error) {
    if (error is AppException) return error;

    if (error is PostgrestException) {
      final code = error.code;
      final msg = error.message;

      // Unique constraint violation (e.g. invoice_no or category)
      if (code == '23505') {
        if (msg.contains('invoices_invoice_no_key') || msg.contains('invoice_no')) {
          return AppException(
            'This invoice number already exists. Please use a unique invoice number.',
            code: code,
            originalError: error,
          );
        }
        if (msg.contains('category_locations_category_key') || msg.contains('category')) {
          return AppException(
            'This category already exists in shelf mapping.',
            code: code,
            originalError: error,
          );
        }
        return AppException('A record with these details already exists.', code: code, originalError: error);
      }

      // Foreign key violation
      if (code == '23503') {
        return AppException(
          'Cannot delete or modify this item because it is referenced by other transactions.',
          code: code,
          originalError: error,
        );
      }

      // Check constraint violation
      if (code == '23514') {
        return AppException(
          'Invalid data value entered. Please verify quantities and amounts.',
          code: code,
          originalError: error,
        );
      }

      // User-raised exception from RPC functions
      if (code == 'P0001') {
        return AppException(msg, code: code, originalError: error);
      }

      return AppException(msg, code: code, originalError: error);
    }

    if (error is AuthException) {
      if (error.message.toLowerCase().contains('invalid login credentials')) {
        return AppException('Incorrect email or password. Please try again.', originalError: error);
      }
      return AppException(error.message, originalError: error);
    }

    final str = error.toString();
    if (str.contains('SocketException') || str.contains('Failed host lookup') || str.contains('NetworkException')) {
      return AppException(
        'Unable to connect to server. Please check your internet connection.',
        originalError: error,
      );
    }

    return AppException(str.replaceFirst('Exception: ', ''), originalError: error);
  }
}
