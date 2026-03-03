import 'dart:convert'; // Untuk encode/decode JSON
import 'package:http/http.dart' as http;

class GeminiService {
  // API Key - GANTI dengan milikmu (jangan hardcode di production!)
  static const String apiKey = "AIzaSyC7NlWv9hb0oBNzoI2zowS0JczUmP8wqfY";

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
          "temperature": 0.2, // Lebih rendah untuk konsistensi format
          "topK": 40,
          "topP": 0.95,
          "maxOutputTokens": 2048, // Lebih banyak untuk antisipasi list panjang
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
          "API Error - Status: ${response.statusCode}, Body: ${response.body}",
        );
        if (response.statusCode == 404) {
          throw Exception(
            "Endpoint/model tidak ditemukan (404). Cek apakah model '$model' tersedia untuk API key/proyekmu. Body: ${response.body}",
          );
        }
        if (response.statusCode == 429) {
          throw Exception(
            "Rate limit tercapai (429). Tunggu beberapa menit atau upgrade quota.",
          );
        }
        if (response.statusCode == 401) {
          throw Exception("API key tidak valid (401). Periksa key Anda.");
        }
        if (response.statusCode == 400) {
          throw Exception("Request salah format (400): ${response.body}");
        }
        throw Exception(
          "Gagal memanggil Gemini API (Code: ${response.statusCode}). Body: ${response.body}",
        );
      }
    } catch (e) {
      print("Exception saat generate schedule: $e");
      throw Exception("Error saat generate jadwal: $e");
    }
  }

  static String _buildPrompt(List<Map<String, dynamic>> tasks) {
    final buffer = StringBuffer();
    buffer.writeln(
      "Tolong buatkan jadwal harian berdasarkan daftar tugas berikut:",
    );
    for (var task in tasks) {
      buffer.writeln(
        "- ${task['name']} (Durasi: ${task['duration']} menit, Prioritas: ${task['priority']})",
      );
    }

    buffer.writeln("\n=============");
    buffer.writeln("Instruksi penting:");
    buffer.writeln("1. Jadwalkan tugas mulai dari jam 08:00 pagi.");
    buffer.writeln(
      "2. Tugas dengan prioritas TINGGI harus dijadwalkan lebih awal.",
    );
    buffer.writeln(
      "3. Berikan waktu istirahat singkat (5–15 menit) antar tugas jika diperlukan.",
    );
    buffer.writeln(
      "4. WAJIB memasukkan SEMUA tugas yang ada di daftar di atas ke dalam tabel, jangan ada yang tertinggal.",
    );
    buffer.writeln("");
    buffer.writeln("FORMAT OUTPUT WAJIB (gunakan Markdown):");
    buffer.writeln("");
    buffer.writeln("## Jadwal Harian Optimal");
    buffer.writeln("");
    buffer.writeln(
      "Gunakan tabel Markdown dengan urutan kolom TEPAT seperti ini:",
    );
    buffer.writeln("| No | Waktu | Nama Tugas | Durasi | Prioritas |");
    buffer.writeln("|----|----|----|----|----|");
    buffer.writeln(
      "| Contoh: 1 | 08:00 - 08:30 | Nama Tugas | 30 menit | Tinggi |",
    );
    buffer.writeln("");
    buffer.writeln("Setelah tabel, tambahkan bagian:");
    buffer.writeln("");
    buffer.writeln("## Catatan & Penjelasan");
    buffer.writeln("");
    buffer.writeln("Di bagian ini, jelaskan:");
    buffer.writeln("- Alasan urutan jadwal yang dipilih");
    buffer.writeln("- Tips produktivitas berdasarkan jadwal tersebut");
    buffer.writeln("- Total waktu kegiatan dan estimasi jam selesai");
    buffer.writeln("");
    buffer.writeln("Gunakan bahasa Indonesia yang ramah dan profesional.");

    return buffer.toString();
  }
}
