/// Maps raw exceptions to short, user-friendly Russian messages.
///
/// The app talks to Supabase over the network; when the backend is
/// unreachable (paused project, no internet, DNS failure) the SDK throws
/// AuthRetryableFetchException / ClientException with "Load failed" or
/// "Failed host lookup". Dumping those raw strings at the user is ugly and
/// scary. This helper turns them into one clean sentence.
String friendlyError(Object? e) {
  final s = e?.toString() ?? '';

  // Network / offline / backend-unreachable
  if (s.contains('Load failed') ||
      s.contains('Failed host lookup') ||
      s.contains('SocketException') ||
      s.contains('Network is unreachable') ||
      s.contains('Connection refused') ||
      s.contains('Connection closed') ||
      s.contains('ClientException') ||
      s.contains('AuthRetryableFetchException') ||
      s.contains('TimeoutException') ||
      s.contains('XMLHttpRequest')) {
    return 'Нет связи с сервером. Проверьте интернет и попробуйте ещё раз.';
  }

  // Auth / session expired
  if (s.contains('JWT') ||
      s.contains('not authenticated') ||
      s.contains('Not authenticated') ||
      s.contains('refresh_token') ||
      s.contains('Invalid Refresh Token')) {
    return 'Сессия истекла. Войдите снова.';
  }

  // Permission / RLS
  if (s.contains('permission denied') || s.contains('42501')) {
    return 'Нет доступа к этим данным.';
  }

  // Rate limit
  if (s.contains('rate limit') || s.contains('429')) {
    return 'Слишком много запросов. Подождите немного.';
  }

  // Generic fallback — never expose the raw exception.
  return 'Что-то пошло не так. Попробуйте позже.';
}
