import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Structured result from Gemini, parsed out of the JSON response so the
/// caller gets real numbers (not just a text blob) to save into Firebase.
class PurchaseOrderResult {
  final String product;
  final double currentStock;
  final double targetStock;
  final double quantity;
  final String reason;
  final String message;

  PurchaseOrderResult({
    required this.product,
    required this.currentStock,
    required this.targetStock,
    required this.quantity,
    required this.reason,
    required this.message,
  });

  factory PurchaseOrderResult.fromJson(Map<String, dynamic> json) {
    return PurchaseOrderResult(
      product: json['product']?.toString() ?? 'Unknown',
      currentStock: _toDouble(json['current_stock']),
      targetStock: _toDouble(json['target_stock']),
      quantity: _toDouble(json['recommended_quantity']),
      reason: json['reason']?.toString() ?? '',
      message: json['whatsapp_message']?.toString() ?? '',
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}

class GeminiService {
  // TODO: move this out of source code — use --dart-define-from-file
  // or a gitignored .env file loaded via flutter_dotenv instead.
  static String get apiKey =>
      dotenv.env['GEMINI_API_KEY'] ?? '';

  static Future<PurchaseOrderResult> generatePurchaseOrder({
    required String shelf,
    required double weight,
  }) async {
    final url = Uri.parse(
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey",
    );

    final prompt = """
You are an inventory management AI assistant.

Product: Rice
Shelf: $shelf
Current Stock: $weight kg

Stock is below threshold.

Respond with ONLY a valid JSON object — no markdown, no code fences, no
extra commentary — in exactly this shape:

{
  "product": "Rice",
  "current_stock": $weight,
  "target_stock": <recommended full-stock level in kg, a number>,
  "recommended_quantity": <recommended reorder quantity in kg, a number>,
  "reason": "<short one-sentence reason>",
  "whatsapp_message": "<a professional, concise WhatsApp purchase order message>"
}
""";

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {"text": prompt}
            ]
          }
        ],
        "generationConfig": {
          // Asks Gemini to constrain output to valid JSON.
          "response_mime_type": "application/json",
        },
      }),
    );

    if (kDebugMode) {
      print("STATUS CODE: ${response.statusCode}");
      print(response.body);
    }

    if (response.statusCode != 200) {
      throw Exception("API ERROR: ${response.body}");
    }

    final data = jsonDecode(response.body);

    if (data["candidates"] == null) {
      throw Exception("NO CANDIDATES RETURNED\n${response.body}");
    }

    final String rawText =
    data["candidates"][0]["content"]["parts"][0]["text"];

    // Defensive cleanup in case Gemini wraps the JSON in code fences anyway.
    final cleanedText =
    rawText.replaceAll(RegExp(r'```json|```'), '').trim();

    final Map<String, dynamic> parsed =
    jsonDecode(cleanedText) as Map<String, dynamic>;

    return PurchaseOrderResult.fromJson(parsed);
  }
}