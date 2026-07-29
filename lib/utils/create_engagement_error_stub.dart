class CreateEngagementErrorDetails {
  const CreateEngagementErrorDetails({
    required this.summary,
    required this.boxedStack,
  });

  final String summary;
  final String? boxedStack;
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
  );
}
