const accountPasswordRecoverySuccessMessage =
    'Si un compte correspond à cette adresse, un e-mail de récupération a été envoyé.';
const accountPasswordRecoveryFailureMessage =
    'Récupération temporairement indisponible. Réessayez.';
const accountPasswordRecoveryInvalidEmailMessage =
    'Saisissez une adresse e-mail valide.';

bool isValidAccountRecoveryEmail(String email) =>
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.trim());
