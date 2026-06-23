import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AIOrdersScreen extends StatelessWidget {
  const AIOrdersScreen({super.key});

  Future<void> sendWhatsApp(String message) async {
    String dealerNumber = "919876543210";

    final Uri url = Uri.parse(
      "https://wa.me/$dealerNumber?text=${Uri.encodeComponent(message)}",
    );

    await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final DatabaseReference aiOrdersRef =
    FirebaseDatabase.instance.ref("ai_orders");

    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Orders"),
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: aiOrdersRef.onValue,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return const Center(
              child: Text("No AI Orders"),
            );
          }

          final Map<dynamic, dynamic> orders = Map<dynamic, dynamic>.from(
              snapshot.data!.snapshot.value as Map);

          final orderList = orders.entries.toList().reversed.toList();

          return ListView.builder(
            itemCount: orderList.length,
            itemBuilder: (context, index) {
              final order =
              Map<dynamic, dynamic>.from(orderList[index].value);

              return Card(
                margin: const EdgeInsets.all(10),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order["product"] ?? "",
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text("Current Stock: ${order["current_stock"]} kg"),
                      Text("Target Stock: ${order["target_stock"]} kg"),
                      Text("Order Quantity: ${order["quantity"]} kg"),

                      const SizedBox(height: 10),

                      Chip(
                        label: Text(
                          order["status"].toString().toUpperCase(),
                        ),
                      ),

                      const SizedBox(height: 10),

                      ElevatedButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text("Purchase Order"),
                              content: SingleChildScrollView(
                                child: Text(order["message"] ?? ""),
                              ),
                            ),
                          );
                        },
                        child: const Text("View PO"),
                      ),

                      const SizedBox(height: 10),

                      ElevatedButton.icon(
                        onPressed: () {
                          sendWhatsApp(order["message"].toString());
                        },
                        icon: const Icon(Icons.message),
                        label: const Text("Send WhatsApp"),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}