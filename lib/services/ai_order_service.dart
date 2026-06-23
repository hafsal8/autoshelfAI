import 'package:firebase_database/firebase_database.dart';

class AIOrderService {
  static Future<void> saveOrder({
    required String product,
    required double currentStock,
    required double targetStock,
    required double quantity,
    required String message,
    List<String>? dealers,
  }) async {
    DatabaseReference ref =
    FirebaseDatabase.instance.ref("ai_orders").push();

    await ref.set({
      "product": product,
      "current_stock": currentStock,
      "target_stock": targetStock,
      "quantity": quantity,
      "message": message,
      "status": "generated",
      "timestamp": ServerValue.timestamp,
      "dealers": dealers ?? ["918590084515@s.whatsapp.net"],
    });
  }
}