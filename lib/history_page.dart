import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  String filter = 'all'; // 'all', 'weekly', 'monthly'

  String formatCurrency(num value) {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
    return formatter.format(value);
  }

  DateTime? getFilterDate() {
    final now = DateTime.now();
    if (filter == 'weekly') return now.subtract(const Duration(days: 7));
    if (filter == 'monthly') return now.subtract(const Duration(days: 30));
    return null;
  }

  Future<void> _confirmAndDeleteHistory() async {
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hapus Semua Riwayat?"),
        content: const Text("Ini akan menghapus semua history transaksi."),
        actions: [
          TextButton(
            child: const Text("Batal"),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          TextButton(
            child: const Text("Hapus", style: TextStyle(color: Colors.red)),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    final historyCollection = FirebaseFirestore.instance.collection('history');
    final snapshots = await historyCollection.get();

    if (!mounted) return;

    for (var doc in snapshots.docs) {
      await doc.reference.delete();
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Semua history berhasil dihapus")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filterDate = getFilterDate();

    return Scaffold(
      backgroundColor: Colors.purple[50],
      appBar: AppBar(
        backgroundColor: Colors.purple[100],
        centerTitle: true,
        title: Text('Transaction History', style: GoogleFonts.alexandria()),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            tooltip: "Delete all history",
            onPressed: _confirmAndDeleteHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Text("Filter:  "),
                DropdownButton<String>(
                  value: filter,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text("All")),
                    DropdownMenuItem(value: 'weekly', child: Text("Weekly")),
                    DropdownMenuItem(value: 'monthly', child: Text("Monthly")),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => filter = value);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance
                  .collection('history')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final allDocs = snapshot.data!.docs;
                final filteredDocs = filterDate == null
                    ? allDocs
                    : allDocs.where((doc) {
                        final ts = (doc['timestamp'] as Timestamp).toDate();
                        return ts.isAfter(filterDate);
                      }).toList();

                if (filteredDocs.isEmpty) {
                  return const Center(child: Text("Tidak ada transaksi."));
                }

                final total = filteredDocs
                    .where((doc) => doc['action'] == 'delete')
                    .fold<num>(0, (accumulator, doc) => accumulator + (doc['total_price'] ?? 0));

                return Column(
                  children: [
                    if (filter != 'all')
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          "Total Sales: ${formatCurrency(total)}",
                          style: GoogleFonts.alexandria(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredDocs.length,
                        itemBuilder: (context, index) {
                          final data = filteredDocs[index].data();
                          final product = data['product'] ?? '';
                          final action = data['action'] ?? '';
                          final quantity = data['quantity'] ?? 0;
                          final totalPrice = data['total_price'];
                          final timestamp = (data['timestamp'] as Timestamp).toDate();

                          String actionText = action == 'delete'
                              ? 'sold'
                              : action == 'add'
                                  ? 'added'
                                  : 'updated';

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            child: ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              tileColor: Colors.purple[100],
                              title: Text(product, style: GoogleFonts.alexandria(fontSize: 18, fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                "$actionText - $quantity unit\n"
                                "Total: ${totalPrice != null ? formatCurrency(totalPrice) : "-"}\n"
                                "${DateFormat('dd MMM yyyy – HH:mm').format(timestamp)}",
                                style: GoogleFonts.alexandria(fontSize: 14),
                              ),
                              leading: Icon(
                                action == 'add'
                                    ? Icons.arrow_downward
                                    : action == 'delete'
                                        ? Icons.sell
                                        : Icons.edit,
                                color: action == 'add'
                                    ? Colors.green
                                    : action == 'delete'
                                        ? Colors.red
                                        : Colors.orange,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
