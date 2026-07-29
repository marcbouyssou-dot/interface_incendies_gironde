import 'dart:async';

Stream<R> switchLatest<T, R>(
  Stream<T> source,
  Stream<R> Function(T value) follow,
) {
  return Stream.multi((controller) {
    StreamSubscription<R>? innerSubscription;
    var revision = 0;

    Future<void> switchTo(T value) async {
      final currentRevision = ++revision;
      await innerSubscription?.cancel();
      if (currentRevision != revision) return;
      innerSubscription = follow(
        value,
      ).listen(controller.add, onError: controller.addError);
    }

    Future<void> close() async {
      revision++;
      await innerSubscription?.cancel();
      controller.close();
    }

    final sourceSubscription = source.listen(
      (value) => unawaited(switchTo(value)),
      onError: controller.addError,
      onDone: () => unawaited(close()),
    );
    controller.onCancel = () async {
      revision++;
      await sourceSubscription.cancel();
      await innerSubscription?.cancel();
    };
  });
}
