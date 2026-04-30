// API base URL — matches https://api.flux-cal.com/ from web .env
const String kBaseUrl = 'http://192.168.1.17';

// Web Client ID for Google Auth (obtained from Google Cloud Console as Web Application Client ID)
const String kGoogleWebClientId = 'YOUR_GOOGLE_WEB_CLIENT_ID';

// Auth endpoints
const String kLoginEndpoint = '/api/auth/login';
const String kSignupEndpoint = '/api/auth/signup';
const String kMeEndpoint = '/api/auth/me';
const String kResendVerificationEndpoint = '/api/auth/resend-verification';

// User endpoints
String userEmailByIdEndpoint(String userId) => '/users/$userId/email';

// Calendar endpoints
const String kCalendarsEndpoint = '/calendars';
const String kCalendarsByUserEndpoint = '/calendars/user/id';
const String kPrimaryCalendarEndpoint = '/calendars/user/primary';

// Event endpoints
const String kEventsEndpoint = '/events';
const String kEventsByCalendarEndpoint = '/events/calendar';

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

// Storage keys
const String kAccessTokenKey = 'access_token';
const String kTokenTypeKey = 'token_type';
const String kCachedUserKey = 'cached_user';
const String kMenuOpenKey = 'isMenuOpen';
const String kCalendarListVisibleKey = 'isCalendarListVisible';
