import 'dart:async';

/// Attend la réponse de l'écriture, puis réconcilie son résultat si le client
/// a cessé de l'attendre avant que Firestore ne confirme le commit.
///
/// L'écriture n'est lancée qu'une fois. Après [writeTimeout], un succès tardif
/// de cette même écriture ou une confirmation distante explicite suffit. Sans
/// l'un de ces deux signaux, l'erreur reste visible pour l'appelant.
Future<void> awaitMissionCancellationCompletion({
  required Future<void> Function() write,
  required Stream<bool> remoteConfirmations,
  Duration writeTimeout = const Duration(seconds: 15),
  Duration confirmationTimeout = const Duration(seconds: 15),
}) async {
  final writeFuture = write();
  try {
    await writeFuture.timeout(writeTimeout);
    return;
  } on TimeoutException {
    final remoteConfirmation = _firstConfirmed(remoteConfirmations);
    await Future.any<void>([
      writeFuture,
      remoteConfirmation,
    ]).timeout(confirmationTimeout);
  }
}

Future<void> _firstConfirmed(Stream<bool> confirmations) async {
  try {
    await confirmations.firstWhere((confirmed) => confirmed);
  } catch (_) {
    // Une lecture de confirmation indisponible ne transforme jamais une
    // issue inconnue en succès. L'écriture source peut encore confirmer ;
    // sinon la deadline de réconciliation produira l'erreur attendue.
    await Completer<void>().future;
  }
}
