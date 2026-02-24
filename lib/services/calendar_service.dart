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
      "809885834954-j6u776unsh6e6re2g3p2v943k9b4o1v0.apps.googleusercontent.com";

  static Future<void> _initialize() async {
    final googleSignIn = GoogleSignIn.instance;
    await googleSignIn.initialize(
      clientId: googleClientId.contains("YOUR_CLIENT_ID")
          ? null
          : googleClientId,
    );
  }

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
    final googleSignIn = GoogleSignIn.instance;

    if (kIsWeb) {
      // Pada web, gunakan signIn() karena authenticate() tidak didukung
      await (googleSignIn as dynamic).signIn();
    } else {
      await _initialize();
      // On mobile, use authenticate() or signIn()
      await (googleSignIn as dynamic).signIn();
    }

    final scopes = <String>[
      cal.CalendarApi.calendarEventsScope,
      cal.CalendarApi.calendarReadonlyScope,
    ];

    // 2. Gunakan authorizationClient untuk meminta izin
    final auth = await googleSignIn.authorizationClient.authorizeScopes(scopes);

    // 3. Mendapatkan authClient
    final authClient = auth.authClient(scopes: scopes);
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

        events.add(
          CalendarEvent(
            title: title,
            description: 'Prioritas: $priority (AI Generated)',
            startTime: startTime,
            endTime: endTime,
          ),
        );
      } catch (_) {}
    }
    return events;
  }
}
