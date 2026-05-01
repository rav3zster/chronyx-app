import 'package:chronyx/core/constants/app_strings.dart';
import 'package:chronyx/core/errors/app_exception.dart';

class ErrorMessageMapper {
  const ErrorMessageMapper._();

  static String fromError(Object error) {
    if (error is NetworkException) {
      return AppStrings.networkError;
    }
    if (error is ServerException) {
      return AppStrings.serverError;
    }
    if (error is AppException) {
      return error.message;
    }
    return AppStrings.genericError;
  }
}
