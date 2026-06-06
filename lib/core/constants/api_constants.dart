// API base URL. Override for local runs with:
// --dart-define=API_BASE_URL=https://api.flux-cal.com
const String kBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://10.55.65.215',
);

// Web Client ID for Google Auth (obtained from Google Cloud Console as Web Application Client ID)
const String kGoogleWebClientId = '916357634266-l9qe40n10k4e5vanvp0n3n70edi51khp.apps.googleusercontent.com';

// Auth endpoints
const String kLoginEndpoint = '/api/auth/login';
const String kSignupEndpoint = '/api/auth/signup';
const String kMeEndpoint = '/api/auth/me';
const String kResendVerificationEndpoint = '/api/auth/resend-verification';
const String kForgotPasswordEndpoint = '/api/auth/forgot-password';
const String kValidateResetTokenEndpoint = '/api/auth/validate-reset-token';
const String kResetPasswordEndpoint = '/api/auth/reset-password';

// User endpoints
String userEmailByIdEndpoint(String userId) => '/users/$userId/email';

// Calendar endpoints
const String kCalendarsEndpoint = '/calendars';
const String kCalendarsByUserEndpoint = '/calendars/user/id';
const String kPrimaryCalendarEndpoint = '/calendars/user/primary';

// Event endpoints
const String kEventsEndpoint = '/events';
const String kEventsByCalendarEndpoint = '/events/calendar';
const String kGoogleCalendarSyncEndpoint = '/events/sync/google';

// Task endpoints
const String kTasksEndpoint = '/tasks';

// Members endpoints
const String kMembersEndpoint = '/members';
const String kShareEventEndpoint = '/members/share/event';

// Conference endpoints
const String kConferenceEndpoint = '/conference';

// Location endpoints
const String kLocationEndpoint = '/event/location';

// Reminder endpoints
const String kRemindersEndpoint = '/api/reminders';
const String kDeviceTokenEndpoint = '/api/devices/token';

// Storage keys
const String kAccessTokenKey = 'access_token';
const String kTokenTypeKey = 'token_type';
const String kCachedUserKey = 'cached_user';
const String kMenuOpenKey = 'isMenuOpen';
const String kCalendarListVisibleKey = 'isCalendarListVisible';
