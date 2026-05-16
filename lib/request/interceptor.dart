import 'package:dio/dio.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/request/core/network_error_mapper.dart';

class ApiInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final customError = err.requestOptions.extra['customError'];
    if (customError is String && customError.isNotEmpty) {
      KazumiDialog.showToast(message: customError);
    }
    handler.next(err);
  }

  static Future<String> dioError(DioException error) async {
    final mapped = await NetworkErrorMapper.mapException(error);
    return mapped.message;
  }
}
