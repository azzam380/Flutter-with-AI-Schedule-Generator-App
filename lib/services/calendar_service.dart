import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as cal;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';

class CalendarService {
  // GANTI dengan Client ID dari Google Cloud Console (wajib untuk Web)
  // https://console.cloud.google.com/apis/credentials
  static const String googleClientId =
      "809885834954-j6u776unsh6e6re2g3p2v943k9b4o1v0.apps.googleusercontent.com"; // Ganti dengan milikmu

  /// Fungsi utama untuk memparse Markdown dan mengekspor ke Google Calendar
  static Future<void> exportMarkdownToCalendar(String markdown) async {
    final events = parseMarkdown(markdown);
    if (events.isEmpty) {
      throw Exception("Format jadwal tidak ditemukan dalam teks.");
    }

    // Inisialisasi GoogleSignIn menggunakan singleton (API v7.0+)
    final googleSignIn = GoogleSignIn.instance;
    await googleSignIn.initialize(
      clientId: googleClientId.contains("YOUR_CLIENT_ID")
          ? null
          : googleClientId,
    );

    try {
      // 1. Autentikasi user (Sign In)
      // Pada versi ini, authenticate() mengembalikan objek non-nullable atau throw Error jika gagal
      await googleSignIn.authenticate();

      final scopes = <String>[cal.CalendarApi.calendarEventsScope];

      // 2. Gunakan authorizationClient untuk meminta izin (scopes) secara eksplisit (Pola baru GIS 7.x)
      final auth = await googleSignIn.authorizationClient.authorizeScopes(
        scopes,
      );

      // 3. Mendapatkan authClient menggunakan extension pada GoogleSignInClientAuthorization
      // Di versi 3.0.0+, method authClient() dipanggil pada objek hasil otorisasi dengan menyertakan scopes
      final authClient = auth.authClient(scopes: scopes);

      final calendar = cal.CalendarApi(authClient);

      for (var e in events) {
        final event = cal.Event(
          summary: e['title'],
          description: e['description'],
          start: cal.EventDateTime(
            dateTime: (e['startTime'] as DateTime).toUtc(),
            timeZone: 'UTC',
          ),
          end: cal.EventDateTime(
            dateTime: (e['endTime'] as DateTime).toUtc(),
            timeZone: 'UTC',
          ),
        );
        await calendar.events.insert(event, 'primary');
      }
    } catch (e) {
      print('Calendar Error: $e');
      rethrow;
    }
  }

  /// Memparse tabel Markdown
  static List<Map<String, dynamic>> parseMarkdown(String markdown) {
    final List<Map<String, dynamic>> events = [];
    final regExp = RegExp(
      r'\|\s*\d+\s*\|\s*([^|]+)\s*\|\s*([^|]+)\s*\|\s*(\d+)\s*\|\s*(\d{2}:\d{2})\s*\|\s*(\d{2}:\d{2})\s*\|',
    );

    final now = DateTime.now();
    final matches = regExp.allMatches(markdown);

    for (final match in matches) {
      final title = match.group(1)!.trim();
      if (title.toLowerCase() == 'tugas' || title.contains('---')) continue;

      try {
        final priority = match.group(2)!.trim();
        final startTimeStr = match.group(4)!.trim();
        final endTimeStr = match.group(5)!.trim();

        final startParts = startTimeStr.split(':');
        final endParts = endTimeStr.split(':');

        final startTime = DateTime(
          now.year,
          now.month,
          now.day,
          int.parse(startParts[0]),
          int.parse(startParts[1]),
        );

        final endTime = DateTime(
          now.year,
          now.month,
          now.day,
          int.parse(endParts[0]),
          int.parse(endParts[1]),
        );

        events.add({
          'title': title,
          'description': 'Prioritas: $priority (AI Generated)',
          'startTime': startTime,
          'endTime': endTime,
        });
      } catch (_) {}
    }
    return events;
  }
}
