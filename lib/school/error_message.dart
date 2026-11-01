import '../core/error_message.dart';
import 'errors.dart';

String schoolErrorMessage(Object error) => switch (error) {
  SchoolConnectionError() => schoolErrorMessage(error.cause),
  SessionExpired() => error.toString(),
  SchoolCredentialsRequired() => error.message,
  SchoolRequestError(:final message) ||
  SchoolStorageError(:final message) => message,
  _ => errorMessage(error),
};
