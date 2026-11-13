import 'package:flutter/material.dart';

// Shared helper dialog to Add or Edit Income / Expense records
void showRecordDialog(
  BuildContext context, {
  required String eventName,
  required bool isIncome,
  LedgerEntry? existingEntry,
}) {
  final isEditing = existingEntry != null;
  final descController = TextEditingController(
    text: existingEntry?.description ?? '',
  );
  final amountController = TextEditingController(
    text: existingEntry != null ? existingEntry.amount.toStringAsFixed(2) : '',
  );
  final categoryController = TextEditingController(
    text: existingEntry?.category ?? '',
  );
  DateTime? transactionDate = existingEntry?.transactionDate ?? DateTime.now();
  final transactionDateController = TextEditingController(
    text: transactionDate.toString().split(' ')[0],
  );

  final themeColor = isIncome ? Colors.green.shade700 : Colors.red.shade700;

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            isIncome ? Icons.trending_up : Icons.trending_down,
            color: themeColor,
          ),
          const SizedBox(width: 8),
          Text(
            isEditing
                ? (isIncome ? 'Edit Income' : 'Edit Expense')
                : (isIncome ? 'Add Income' : 'Add Expense'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: descController,
              decoration: InputDecoration(
                labelText: 'Description',
                hintText: 'Description (e.g. Sales)',
                prefixIcon: const Icon(Icons.description_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              decoration: InputDecoration(
                labelText: 'Amount (RM)',
                hintText: '0.00',
                prefixIcon: const Icon(Icons.attach_money),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: categoryController,
              decoration: InputDecoration(
                labelText: 'Category',
                hintText: 'e.g. Food, Booth Rent',
                prefixIcon: const Icon(Icons.category_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: transactionDateController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Transaction Date',
                hintText: 'Select date',
                prefixIcon: const Icon(Icons.calendar_today),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onTap: () async {
                DateTime? pickedDate = await showDatePicker(
                  context: context,
                  initialDate: transactionDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );

                if (pickedDate != null) {
                  transactionDateController.text = pickedDate.toString().split(
                    ' ',
                  )[0];
                  transactionDate = pickedDate;
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: Colors.grey.shade700)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: themeColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () {
            final description = descController.text.trim();
            final amount = double.tryParse(amountController.text.trim()) ?? 0;
            final category = categoryController.text.trim();

            if (description.isNotEmpty && amount > 0 && category.isNotEmpty) {
              final entry = LedgerEntry(
                id:
                    existingEntry?.id ??
                    DateTime.now().millisecondsSinceEpoch.toString(),
                eventName: eventName,
                description: description,
                amount: amount,
                isIncome: isIncome,
                category: category,
                transactionDate: transactionDate,
              );

              if (isEditing) {
                LocalDataStore.instance.updateLedgerEntry(entry);
              } else {
                LocalDataStore.instance.addLedgerEntry(entry);
              }
              Navigator.pop(context);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Please fill in all fields with a valid amount greater than 0.',
                  ),
                ),
              );
            }
          },
          child: Text(isEditing ? 'Update' : 'Save'),
        ),
      ],
    ),
  );
}

class FinancialDashboardPage extends StatefulWidget {
  final Event event;
  const FinancialDashboardPage({super.key, required this.event});

  @override
  State<FinancialDashboardPage> createState() => _FinancialDashboardPageState();
}

class _FinancialDashboardPageState extends State<FinancialDashboardPage> {
  void _showAddRecordDialog(bool isIncome) {
    showRecordDialog(context, eventName: widget.event.name, isIncome: isIncome);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Dashboard: ${widget.event.name}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.blueGrey.shade800,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListenableBuilder(
        listenable: LocalDataStore.instance,
        builder: (context, _) {
          final eventLedger = LocalDataStore.instance.ledger
              .where((e) => e.eventName == widget.event.name)
              .toList();

          double totalIncome = 0;
          double totalExpense = 0;
          for (var entry in eventLedger) {
            if (entry.isIncome) {
              totalIncome += entry.amount;
            } else {
              totalExpense += entry.amount;
            }
          }
          final netProfit = totalIncome - totalExpense;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Summary Card
                Card(
                  elevation: 3,
                  shadowColor: Colors.black12,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        const Text(
                          'NET PROFIT',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                            color: Colors.blueGrey,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'RM ${netProfit.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 28,
                            color: netProfit >= 0
                                ? Colors.blueGrey.shade900
                                : Colors.red.shade700,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          child: Divider(height: 1),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.arrow_downward_rounded,
                                        size: 16,
                                        color: Colors.green.shade700,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Total Income',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'RM ${totalIncome.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              height: 36,
                              width: 1,
                              color: Colors.grey.shade300,
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.arrow_upward_rounded,
                                        size: 16,
                                        color: Colors.red.shade700,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Total Expenses',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'RM ${totalExpense.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Add Records Section
                const Text(
                  '📝 Record Actions',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade50,
                          foregroundColor: Colors.green.shade800,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.green.shade200),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _showAddRecordDialog(true),
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text(
                          'Add Income',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade50,
                          foregroundColor: Colors.red.shade800,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.red.shade200),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _showAddRecordDialog(false),
                        icon: const Icon(Icons.remove_circle_outline),
                        label: const Text(
                          'Add Expense',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // View Details Section
                const Text(
                  '📂 View Details',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                    foregroundColor: Colors.green.shade800,
                    side: BorderSide(color: Colors.green.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.centerLeft,
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RecordsListPage(
                        event: widget.event,
                        showIncome: true,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.trending_up),
                  label: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'View Income Records',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, size: 14),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                    foregroundColor: Colors.red.shade800,
                    side: BorderSide(color: Colors.red.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.centerLeft,
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RecordsListPage(
                        event: widget.event,
                        showIncome: false,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.trending_down),
                  label: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'View Expense Records',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, size: 14),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class RecordsListPage extends StatelessWidget {
  final Event event;
  final bool showIncome;

  const RecordsListPage({
    super.key,
    required this.event,
    required this.showIncome,
  });

  void _confirmDeleteRecord(BuildContext context, LedgerEntry entry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Record'),
        content: Text(
          'Are you sure you want to delete "${entry.description}" (RM ${entry.amount.toStringAsFixed(2)})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              LocalDataStore.instance.deleteLedgerEntry(entry.id);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = showIncome ? Colors.green.shade700 : Colors.red.shade700;
    final softBgColor = showIncome ? Colors.green.shade50 : Colors.red.shade50;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          showIncome ? 'Incomes: ${event.name}' : 'Expenses: ${event.name}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListenableBuilder(
        listenable: LocalDataStore.instance,
        builder: (context, _) {
          final records = LocalDataStore.instance.ledger
              .where(
                (e) => e.eventName == event.name && e.isIncome == showIncome,
              )
              .toList();

          if (records.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    showIncome
                        ? 'No income records found.'
                        : 'No expense records found.',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: records.length,
            itemBuilder: (context, index) {
              final entry = records[index];
              final dateStr = entry.transactionDate != null
                  ? entry.transactionDate.toString().split(' ')[0]
                  : null;

              return Card(
                elevation: 2,
                shadowColor: Colors.black12,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: softBgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      showIncome ? Icons.arrow_downward : Icons.arrow_upward,
                      color: themeColor,
                    ),
                  ),
                  title: Text(
                    entry.description,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      dateStr != null
                          ? 'Category: ${entry.category} • $dateStr'
                          : 'Category: ${entry.category}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'RM ${entry.amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: themeColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'Edit Record',
                        icon: Icon(
                          Icons.edit_outlined,
                          size: 20,
                          color: Colors.blueGrey.shade600,
                        ),
                        onPressed: () => showRecordDialog(
                          context,
                          eventName: event.name,
                          isIncome: showIncome,
                          existingEntry: entry,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Delete Record',
                        icon: Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: Colors.red.shade400,
                        ),
                        onPressed: () => _confirmDeleteRecord(context, entry),
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
