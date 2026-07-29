class CreateEngagementErrorDetails {
  const CreateEngagementErrorDetails({
    required this.summary,
    required this.boxedStack,
    required this.diagnostics,
  });

  final String summary;
  final String? boxedStack;
  final List<String> diagnostics;
}

CreateEngagementErrorDetails unpackCreateEngagementError(
  Object error,
  StackTrace stackTrace,
) {
  return CreateEngagementErrorDetails(
    summary:
        'CREATE_ENGAGEMENT_ERROR '
        'type=${error.runtimeType} '
        'boxedError=$error '
        'code=unavailable '
        'message=$error',
    boxedStack: null,
    diagnostics: const [],
  );
}
