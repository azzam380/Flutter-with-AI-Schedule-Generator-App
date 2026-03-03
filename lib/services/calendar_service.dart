import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as cal;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class CalendarEvent {
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;

  CalendarEvent({
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
  });
}

class CalendarService {
  // GANTI dengan Client ID dari Google Cloud Console
  static const String googleClientId =
      "585930392757-bdreeg609hdjqbh1po4sberloojjrom7.apps.googleusercontent.com";

  /// Mendapatkan daftar kalender user
  static Future<List<cal.CalendarListEntry>> getCalendarList() async {
    try {
      final authClient = await _getAuthClient();
      final calendar = cal.CalendarApi(authClient);
      final list = await calendar.calendarList.list();
      return list.items ?? [];
    } catch (e) {
      print('Get Calendar List Error: $e');
      rethrow;
    }
  }

  static Future<http.Client> _getAuthClient() async {
    final googleSignIn = GoogleSignIn(
      clientId: kIsWeb ? googleClientId : null,
      scopes: [
        cal.CalendarApi.calendarEventsScope,
        cal.CalendarApi.calendarReadonlyScope,
      ],
    );

    GoogleSignInAccount? account;
    if (kIsWeb) {
      account = await googleSignIn.signIn();
    } else {
      account = await googleSignIn.signInSilently();
      account ??= await googleSignIn.signIn();
    }

    if (account == null)
      throw Exception("User must be signed in to access Google Calendar");

    final authClient = await googleSignIn.authenticatedClient();
    if (authClient == null)
      throw Exception("Failed to get authenticated client");

    return authClient;
  }

  /// Fungsi utama untuk mengekspor event ke Google Calendar
  static Future<void> exportEventsToCalendar(
    List<CalendarEvent> events, {
    String calendarId = 'primary',
  }) async {
    if (events.isEmpty) {
      throw Exception("Tidak ada jadwal untuk diekspor.");
    }

    try {
      final authClient = await _getAuthClient();
      final calendar = cal.CalendarApi(authClient);

      for (var e in events) {
        final event = cal.Event(
          summary: e.title,
          description: e.description,
          start: cal.EventDateTime(
            dateTime: e.startTime.toUtc(),
            timeZone: 'UTC',
          ),
          end: cal.EventDateTime(dateTime: e.endTime.toUtc(), timeZone: 'UTC'),
        );
        await calendar.events.insert(event, calendarId);
      }
    } catch (e) {
      print('Calendar Export Error: $e');
      rethrow;
    }
  }

  /// Memparse tabel Markdown ke List<CalendarEvent>
  static List<CalendarEvent> parseMarkdown(String markdown) {
    final List<CalendarEvent> events = [];
    
    // Format yang diharapkan (sesuai prompt): | No | Waktu | Nama Tugas | Durasi | Prioritas |
    // Contoh: | 1 | 08:00 - 08:30 | Olahraga | 30 menit | Tinggi |
    final regExp = RegExp(
      r'\|\s*\d+\s*\|\s*(\d{1,2})[:.](\d{2})\s*-\s*(\d{1,2})[:.](\d{2})\s*\|\s*([^|]+)\s*\|\s*([^|]+)\s*\|\s*([^|]+)\s*\|',
    );

    final now = DateTime.now();
    final matches = regExp.allMatches(markdown);

    for (final match in matches) {
      final timeStartHour = match.group(1);
      if (timeStartHour == null) continue;

      try {
        final startHour = int.parse(match.group(1)!);
        final startMin = int.parse(match.group(2)!);
        final endHour = int.parse(match.group(3)!);
        final endMin = int.parse(match.group(4)!);
        final title = match.group(5)!.trim();
        final duration = match.group(6)!.trim();
        final priority = match.group(7)!.trim();

        // Skip header atau baris pemisah
        if (title.toLowerCase() == 'nama tugas' || title.contains('---')) continue;

        final startTime = DateTime(
          now.year,
          now.month,
          now.day,
          startHour,
          startMin,
        );

        final endTime = DateTime(now.year, now.month, now.day, endHour, endMin);

        events.add(
          CalendarEvent(
            title: title,
            description: 'Durasi: $duration, Prioritas: $priority (AI Generated)',
            startTime: startTime,
            endTime: endTime,
          ),
        );
      } catch (e) {
        debugPrint("Parse Error row: $e");
      }
    }
    return events;
  }
}
