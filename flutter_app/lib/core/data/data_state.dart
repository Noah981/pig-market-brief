enum DataStatus { loading, success, stale, empty, error }

class DataMeta {
  const DataMeta({required this.source,required this.sourceTimestamp,required this.fetchedAt,required this.lastSuccessfulUpdate,required this.isStale});
  final String source;
  final DateTime? sourceTimestamp;
  final DateTime fetchedAt;
  final DateTime? lastSuccessfulUpdate;
  final bool isStale;
}

class DataState<T> {
  const DataState._(this.status,{this.data,this.meta,this.error});
  final DataStatus status;final T? data;final DataMeta? meta;final Object? error;
  const DataState.loading():this._(DataStatus.loading);
  const DataState.empty({DataMeta? meta}):this._(DataStatus.empty,meta:meta);
  const DataState.error(Object error,{T? lastGood,DataMeta? meta}):this._(DataStatus.error,error:error,data:lastGood,meta:meta);
  const DataState.success(T data,DataMeta meta):this._(DataStatus.success,data:data,meta:meta);
  const DataState.stale(T data,DataMeta meta):this._(DataStatus.stale,data:data,meta:meta);
  bool get hasUsableData=>data!=null&&(status==DataStatus.success||status==DataStatus.stale||status==DataStatus.error);
}
