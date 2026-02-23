import 'dart:convert'; // Untuk encode/decode JSON
import 'package:http/http.dart' as http;

class GeminiService {
  // API Key - GANTI dengan milikmu (jangan hardcode di production!)
  static const String apiKey = "AIzaSyDCdFD6fWLGmVrffStHp02nYkxTdeu2luo";

  // Gunakan model stabil terbaru (per 2026: gemini-1.5-flash atau gemini-1.5-flash-latest)
  static const String model = "gemini-2.5-flash";

  // Endpoint resmi Gemini generateContent
  static const String baseUrl =
      "https://generativelanguage.googleapis.com/v1/models/$model:generateContent";

  static Future<String> generateSchedule(
    List<Map<String, dynamic>> tasks,
  ) async {
    try {
      final prompt = _buildPrompt(tasks);
      final url = Uri.parse('$baseUrl?key=$apiKey');

      final requestBody = {
        "contents": [
          {
            "parts": [
              {"text": prompt},
            ],
          },
        ],
        "generationConfig": {
          "temperature": 0.7,
          "topK": 40,
          "topP": 0.95,
          "maxOutputTokens": 1024,
        },
      };

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map &&
            data["candidates"] != null &&
            data["candidates"] is List &&
            (data["candidates"] as List).isNotEmpty) {
          final candidate0 = (data["candidates"] as List).first;
          if (candidate0 is Map &&
              candidate0["content"] is Map &&
              (candidate0["content"] as Map)["parts"] is List &&
              ((candidate0["content"] as Map)["parts"] as List).isNotEmpty) {
            final part0 =
                ((candidate0["content"] as Map)["parts"] as List).first;
            if (part0 is Map && part0["text"] is String) {
              return part0["text"] as String;
            }
          }
        }
        return "Tidak ada jadwal yang dihasilkan dari AI.";
      } else {
        print(
            "API Error - Status: ${response.statusCode}, Body: ${response.body}");
        if (response.statusCode == 404) {
          throw Exception(
              "Endpoint/model tidak ditemukan (404). Cek apakah model '$model' tersedia untuk API key/proyekmu. Body: ${response.body}");
        }
        if (response.statusCode == 429) {
          throw Exception(
              "Rate limit tercapai (429). Tunggu beberapa menit atau upgrade quota.");
        }
        if (response.statusCode == 401) {
          throw Exception("API key tidak valid (401). Periksa key Anda.");
        }
        if (response.statusCode == 400) {
          throw Exception("Request salah format (400): ${response.body}");
        }
        throw Exception(
            "Gagal memanggil Gemini API (Code: ${response.statusCode}). Body: ${response.body}");
      }
    } catch (e) {
      print("Exception saat generate schedule: $e");
      throw Exception("Error saat generate jadwal: $e");
    }
  }

  static String _buildPrompt(List<Map<String, dynamic>> tasks) {
    final buffer = StringBuffer();
    buffer.writeln(
        "Kamu adalah asisten penjadwalan. Buat jadwal yang BENAR-BENAR konkret dan bisa langsung diikuti.\n"
        "Aturan:\n"
        "- Urutkan berdasarkan prioritas: Tinggi > Sedang > Rendah.\n"
        "- Untuk prioritas yang sama, dahulukan durasi lebih pendek.\n"
        "- Jadwal dimulai dari 08:00.\n"
        "- Setiap tugas harus punya jam mulai dan jam selesai (format HH:mm).\n"
        "- Tidak boleh ada tugas yang hilang.\n"
        "- Output WAJIB hanya 1 tabel Markdown, tanpa paragraf pembuka/penutup.\n"
        "Kolom tabel: | No | Tugas | Prioritas | Durasi (menit) | Mulai | Selesai |\n"
        "\nDaftar tugas:\n");

    for (final task in tasks) {
      final name = (task["name"] ?? "").toString();
      final prio = (task["priority"] ?? "").toString();
      final duration = task["duration"];
      buffer.writeln("- Tugas: $name | Prioritas: $prio | Durasi: $duration menit");
    }
    return buffer.toString();
  }
}