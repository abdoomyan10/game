enum RequestStatus { init, loading, success, failed }

extension RequestStatusX on RequestStatus {
  bool get isInit => this == RequestStatus.init;
  bool get isLoading => this == RequestStatus.loading;
  bool get isSuccess => this == RequestStatus.success;
  bool get isFailed => this == RequestStatus.failed;
}
