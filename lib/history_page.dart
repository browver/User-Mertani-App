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
  String searchQuery = '';

  String formatCurrency(num value) {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);
    return 'Rp ${formatter.format(value)}';
  }

// Weekly or Monthly Options 
  DateTime? getFilterDate() {
    final now = DateTime.now();
    if (filter == 'weekly') return now.subtract(const Duration(days: 7));
    if (filter == 'monthly') return now.subtract(const Duration(days: 30));
    return null;
  }

// Delete alert UI
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

// Delete All History Button
  @override
  Widget build(BuildContext context) {
    final filterDate = getFilterDate();

    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: Colors.orange[500],
        centerTitle: true,
        title: Text('Transaction History', style: GoogleFonts.alexandria()),
        actions: [
          IconButton(
            icon: Icon(Icons.delete, color: Colors.red[600]),
            tooltip: "Delete all history",
            onPressed: _confirmAndDeleteHistory,
          ),
        ],
      ),

      // Search Products History
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column( 
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Product name..',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), 
                  ),
                  onChanged: (value) { 
                    setState(() {
                      searchQuery = value.toLowerCase();
                    });
                  },
                ),
                const SizedBox(height: 12), 
                Row(
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
                // Search Filter change
                final allDocs = snapshot.data!.docs;
                final filteredDocs = allDocs.where((doc) {
                        final data = doc.data();
                        final ts = (doc['timestamp'] as Timestamp).toDate();
                        final productName = (data['items'] ?? '').toString().toLowerCase();

                        final matchesSearch = productName.contains(searchQuery);
                        final matchesFilter = filterDate == null || ts.isAfter(filterDate);
                        return matchesSearch && matchesFilter;
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
                          final product = data['items'] ?? '';
                          final action = data['action'] ?? '';
                          final quantity = data['quantity'] ?? 0;
                          final totalPrice = data['total_price'];
                          final timestamp = (data['timestamp'] as Timestamp).toDate();

                          String actionText = action == 'delete'
                              ? 'Deleted'
                              : action == 'add'
                                  ? 'Added'
                                  : 'Updated';

                          // Total Price
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            child: ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              tileColor: Colors.white,
                              title: Text(product, style: GoogleFonts.alexandria(fontSize: 18, fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                "${quantity == 0 && actionText == 'updated' ? 'Produk habis (update)' : '$actionText - $quantity unit'}\n"
                                "Total: ${totalPrice != null ? formatCurrency(totalPrice) : "-"}\n"
                                "${DateFormat('dd MMM yyyy – HH:mm').format(timestamp)}",
                                style: GoogleFonts.alexandria(fontSize: 14),
                              ),
                              leading: Icon(
                                action == 'add'
                                    ? Icons.arrow_downward
                                    : action == 'delete'
                                        ? Icons.delete
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
