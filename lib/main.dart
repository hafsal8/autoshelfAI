import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'services/notification_service.dart';
import 'firebase_options.dart';
import 'services/gemini_service.dart';
import 'services/ai_order_service.dart';
import 'ai_orders_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// ─────────────────────────────────────────────
//  APP COLOR PALETTE
// ─────────────────────────────────────────────
class AppColors {
  static const primary = Color(0xFF4F46E5);
  static const primaryDark = Color(0xFF3730A3);
  static const background = Color(0xFFF4F6FB);
  static const surface = Colors.white;
  static const success = Color(0xFF16A34A);
  static const danger = Color(0xFFDC2626);
  static const warning = Color(0xFFD97706);
  static const pending = Color(0xFF6366F1);
  static const textPrimary = Color(0xFF1E293B);
  static const textSecondary = Color(0xFF64748B);
}

// ─────────────────────────────────────────────
//  SHARED HELPERS
// ─────────────────────────────────────────────
String formatTimestamp(int ms) {
  if (ms == 0) return '—';
  final dt = DateTime.fromMillisecondsSinceEpoch(ms);
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final period = dt.hour >= 12 ? 'PM' : 'AM';
  final minute = dt.minute.toString().padLeft(2, '0');
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $hour:$minute $period';
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auto Shelf AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        fontFamily: 'Roboto',
      ),
      home: const DashboardScreen(),
    );
  }
}

// ─────────────────────────────────────────────
//  DASHBOARD SCREEN
// ─────────────────────────────────────────────
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Tracks whether the low-stock notification/dialog has already been
  // shown for the current low-stock event. Firebase's stream fires on
  // every update, so without this flag the alert would repeat endlessly
  // while status stays 'low_stock'. It resets only once stock recovers,
  // so a future low-stock event later in the same app session can still
  // notify — remove the reset block below if you want a strict
  // "once per app open, ever" behaviour instead.
  bool _hasNotifiedLowStock = false;

  @override
  Widget build(BuildContext context) {
    final DatabaseReference shelfRef =
    FirebaseDatabase.instance.ref('shelf1');

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Auto Shelf AI',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                letterSpacing: 0.2,
              ),
            ),
            Text(
              'Smart Inventory Management',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white70,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'Order History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const OrderHistoryScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.smart_toy_outlined),
            tooltip: 'AI Orders',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AIOrdersScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: shelfRef.onValue,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading data'));
          }

          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final data = Map<dynamic, dynamic>.from(
              snapshot.data!.snapshot.value as Map);

          final double weight = (data['weight_kg'] ?? 0).toDouble();
          final String status = data['status'] ?? 'Unknown';
          final int timestamp = data['timestamp'] ?? 0;
          final bool isLow = status == 'low_stock';

          if (isLow && !_hasNotifiedLowStock) {
            _hasNotifiedLowStock = true;
            NotificationService.showLowStockNotification();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showLowStockDialog(context, weight);
            });
          } else if (!isLow && _hasNotifiedLowStock) {
            // Stock recovered — allow the next low-stock event to notify again.
            _hasNotifiedLowStock = false;
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _ShelfCard(weight: weight, status: status, isLow: isLow),
              const SizedBox(height: 16),
              _InfoRow(timestamp: timestamp),
            ],
          );
        },
      ),
    );
  }

  void _showLowStockDialog(BuildContext context, double weight) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            SizedBox(width: 10),
            Text('Low Stock Alert'),
          ],
        ),
        content: const Text(
          'Shelf 1 stock is running low.\nWould you like to reorder?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final navigator = Navigator.of(dialogContext);
              final orderRef = FirebaseDatabase.instance.ref("orders").push();
              await orderRef.set({
                "shelf": "Shelf 1",
                "status": "pending",
                "decision": "cancelled",
                "weight": weight,
                "timestamp": ServerValue.timestamp,
              });
              navigator.pop();
            },
            child: const Text('Ignore'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final navigator = Navigator.of(dialogContext);
              final orderRef = FirebaseDatabase.instance.ref("orders").push();
              await orderRef.set({
                "shelf": "Shelf 1",
                "status": "pending",
                "decision": "approved",
                "weight": weight,
                "timestamp": ServerValue.timestamp,
              });
              navigator.pop();
            },
            child: const Text('Order Now'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SHELF STAT CARD
// ─────────────────────────────────────────────
class _ShelfCard extends StatelessWidget {
  final double weight;
  final String status;
  final bool isLow;

  const _ShelfCard({
    required this.weight,
    required this.status,
    required this.isLow,
  });

  @override
  Widget build(BuildContext context) {
    final Color statusColor = isLow ? AppColors.danger : AppColors.success;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.inventory_2_rounded, color: Colors.white, size: 26),
                  SizedBox(width: 10),
                  Text(
                    'Shelf 1',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isLow ? Icons.error_outline : Icons.check_circle,
                      size: 14,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      status.replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const Text(
            'Current Weight',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                weight.toStringAsFixed(3),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'kg',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  LAST UPDATED INFO ROW
// ─────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final int timestamp;
  const _InfoRow({required this.timestamp});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.access_time_rounded,
                color: AppColors.textSecondary, size: 20),
            const SizedBox(width: 10),
            const Text(
              'Last Updated',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              formatTimestamp(timestamp),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  STATUS PILL
// ─────────────────────────────────────────────
class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _Pill({required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  ORDER HISTORY SCREEN
// ─────────────────────────────────────────────
class OrderHistoryScreen extends StatelessWidget {
  const OrderHistoryScreen({super.key});

  Color _decisionColor(String decision) {
    switch (decision) {
      case 'approved':
        return AppColors.success;
      case 'cancelled':
        return AppColors.danger;
      default:
        return AppColors.warning;
    }
  }

  IconData _decisionIcon(String decision) {
    switch (decision) {
      case 'approved':
        return Icons.check_circle_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      default:
        return Icons.hourglass_top_rounded;
    }
  }

  Color _fulfillmentColor(String status) {
    switch (status) {
      case 'rejected':
        return AppColors.danger;
      case 'approved':
        return AppColors.success;
      default:
        return AppColors.pending;
    }
  }

  @override
  Widget build(BuildContext context) {
    final DatabaseReference ordersRef = FirebaseDatabase.instance.ref('orders');

    return Scaffold(
      appBar: AppBar(title: const Text('Order History')),
      body: StreamBuilder<DatabaseEvent>(
        stream: ordersRef.onValue,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading orders'));
          }

          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox_outlined, size: 56, color: AppColors.textSecondary),
                  SizedBox(height: 12),
                  Text(
                    'No orders yet',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          final rawData = Map<dynamic, dynamic>.from(
              snapshot.data!.snapshot.value as Map);

          final orders = rawData.entries.map((e) {
            final map = Map<dynamic, dynamic>.from(e.value as Map);
            return {'key': e.key, ...map};
          }).toList()
            ..sort((a, b) => ((b['timestamp'] ?? 0) as int)
                .compareTo((a['timestamp'] ?? 0) as int));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final String key = order['key'] as String;
              final String shelf = order['shelf'] ?? 'Unknown';
              final String decision = order['decision'] ?? 'pending';
              final String status = order['status'] ?? 'pending';
              final int ts = (order['timestamp'] ?? 0) as int;
              final double orderWeight = (order['weight'] ?? 0).toDouble();

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.shelves,
                                color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  shelf,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  formatTimestamp(ts),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _Pill(
                            label: decision.toUpperCase(),
                            color: _decisionColor(decision),
                            icon: _decisionIcon(decision),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Icon(Icons.scale_rounded,
                              size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            '${orderWeight.toStringAsFixed(3)} kg',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(Icons.flag_rounded,
                              size: 16, color: _fulfillmentColor(status)),
                          const SizedBox(width: 6),
                          Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 13,
                              color: _fulfillmentColor(status),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),

                      // Action buttons — only for pending orders
                      if (status == 'pending') ...[
                        const SizedBox(height: 14),
                        const Divider(height: 1),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.danger,
                                side: const BorderSide(color: AppColors.danger),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.close_rounded, size: 18),
                              label: const Text('Reject'),
                              onPressed: () async {
                                final ref = FirebaseDatabase.instance
                                    .ref("orders/$key");
                                await ref.update({"status": "rejected"});
                              },
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.check_rounded, size: 18),
                              label: const Text('Approve'),
                              onPressed: () =>
                                  _approveOrder(context, key, shelf, orderWeight),
                            ),
                          ],
                        ),
                      ],
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

  // Approves the order and uses Gemini to generate the actual
  // structured purchase order for it.
  Future<void> _approveOrder(
      BuildContext context,
      String key,
      String shelf,
      double orderWeight,
      ) async {
    double weightToUse = orderWeight;

    try {
      if (weightToUse == 0) {
        final shelfSnapshot =
        await FirebaseDatabase.instance.ref('shelf1').get();

        if (shelfSnapshot.exists) {
          final shelfData =
          Map<dynamic, dynamic>.from(shelfSnapshot.value as Map);
          weightToUse = (shelfData['weight_kg'] ?? 0).toDouble();
        }
      }

      final result = await GeminiService.generatePurchaseOrder(
        shelf: shelf,
        weight: weightToUse,
      );

      await AIOrderService.saveOrder(
        product: result.product,
        currentStock: result.currentStock,
        targetStock: result.targetStock,
        quantity: result.quantity,
        message: result.message,
      );

      await FirebaseDatabase.instance
          .ref("orders/$key")
          .update({"status": "approved"});

      if (kDebugMode) {
        print("AI purchase order generated for $shelf");
      }

      if (!context.mounted) return;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.smart_toy_rounded, color: AppColors.primary),
              SizedBox(width: 10),
              Text('AI Purchase Order'),
            ],
          ),
          content: SingleChildScrollView(child: Text(result.message)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print("GEMINI ERROR: $e");
      }

      if (!context.mounted) return;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Error"),
          content: Text(e.toString()),
        ),
      );
    }
  }
}