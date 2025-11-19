enum AsyncStatus { initial, loading, data, empty, error }

class AsyncState<T> {
  AsyncState._({
    required this.status,
    this.data,
    this.error,
    this.message,
  });

  factory AsyncState.initial() => AsyncState._(status: AsyncStatus.initial);

  factory AsyncState.loading({String? message}) =>
      AsyncState._(status: AsyncStatus.loading, message: message);

  factory AsyncState.data(T data, {String? message}) =>
      AsyncState._(status: AsyncStatus.data, data: data, message: message);

  factory AsyncState.empty({String? message}) =>
      AsyncState._(status: AsyncStatus.empty, message: message);

  factory AsyncState.error({Object? error, String? message}) =>
      AsyncState._(status: AsyncStatus.error, error: error, message: message);

  final AsyncStatus status;
  final T? data;
  final Object? error;
  final String? message;

  bool get isLoading => status == AsyncStatus.loading;
  bool get hasData => status == AsyncStatus.data && data != null;
  bool get isEmpty => status == AsyncStatus.empty;
  bool get hasError => status == AsyncStatus.error;
}
