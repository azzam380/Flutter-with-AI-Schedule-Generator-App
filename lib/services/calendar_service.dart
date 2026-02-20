import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart';
// ignore: unused_import
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';

class CalendarService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  static const String _clientId =
      '585930392757-bdreeg609hdjqbh1po4sberloojjrom7.apps.googleusercontent.com';

  static Future<void> addTaskToCalendar({
    required String title,
    required String description,
    required DateTime startTime,
    required int durationMinutes,
  }) async {
    try {
      // Inisialisasi GoogleSignIn (Wajib untuk versi 7.0.0+)
      await _googleSignIn.initialize(clientId: _clientId);

      // Coba login secara silent (menggantikan signInSilently)
      GoogleSignInAccount? account = await _googleSignIn
          .attemptLightweightAuthentication();

      // Jika tidak bisa silent, lakukan login interaktif (menggantikan signIn)
      // Catatan: authenticate() di versi 7.x mengembalikan non-nullable GoogleSignInAccount
      // atau melempar exception jika gagal/batal.
      account ??= await _googleSignIn.authenticate();

      // Meminta otorisasi untuk scope Calendar (Wajib di versi 7.0.0+)
      final authorization = await _googleSignIn.authorizationClient
          .authorizeScopes(<String>[CalendarApi.calendarEventsScope]);

      // Mendapatkan auth client menggunakan extension method 'authClient' dari
      // package extension_google_sign_in_as_googleapis_auth (versi 3.0.0+)
      final authClient = authorization.authClient(
        scopes: <String>[CalendarApi.calendarEventsScope],
      );

      var calendar = CalendarApi(authClient);

      final event = Event(
        summary: title,
        description: description,
        start: EventDateTime(dateTime: startTime.toUtc(), timeZone: 'UTC'),
        end: EventDateTime(
          dateTime: startTime.add(Duration(minutes: durationMinutes)).toUtc(),
          timeZone: 'UTC',
        ),
      );

      await calendar.events.insert(event, 'primary');
    } catch (e) {
      print('Calendar Error: $e');
      rethrow;
    }
  }

  static Future<void> signOut() => _googleSignIn.signOut();
}
