import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:screenshot/screenshot.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';

// ==================== Model ====================
class TransactionModel {
  final String opNumber;
  final String dateTime;
  final String name;
  final String amount;
  final String toAccount;
  final String fromAccount;

  TransactionModel({
    required this.opNumber,
    required this.dateTime,
    required this.name,
    required this.amount,
    required this.toAccount,
    this.fromAccount = '1003 0815 8561 0001',
  });

  Map<String, dynamic> toMap() {
    return {
      'opNumber': opNumber,
      'dateTime': dateTime,
      'name': name,
      'amount': amount,
      'toAccount': toAccount,
      'fromAccount': fromAccount,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      opNumber: map['opNumber'] ?? '',
      dateTime: map['dateTime'] ?? '',
      name: map['name'] ?? '',
      amount: map['amount'] ?? '',
      toAccount: map['toAccount'] ?? '',
      fromAccount: map['fromAccount'] ?? '1003 0815 8561 0001',
    );
  }
}

// ==================== Main ====================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('transactions');
  runApp(const BankakApp());
}

class BankakApp extends StatelessWidget {
  const BankakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'بنكك',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFFE31C23),
        fontFamily: 'Roboto',
      ),
      home: const TransferScreen(),
      locale: const Locale('ar', 'SA'),
    );
  }
}

// ==================== Helpers ====================
String generateOperationNumber() {
  final random = Random();
  String number = '';
  for (int i = 0; i < 12; i++) {
    number += random.nextInt(10).toString();
  }
  return number;
}

String getCurrentDateTime() {
  final now = DateTime.now();
  return DateFormat('dd-MMM-yyyy HH:mm:ss').format(now);
}

// ==================== Screen 1: Transfer ====================
class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController accountController = TextEditingController();
  final TextEditingController amountController = TextEditingController();

  void submitTransfer() async {
    final name = nameController.text.trim();
    final account = accountController.text.trim();
    final amountText = amountController.text.trim();

    if (name.isEmpty || account.isEmpty || amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال جميع البيانات')),
      );
      return;
    }

    final parsedAmount = double.tryParse(amountText);
    if (parsedAmount == null || parsedAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال مبلغ صحيح')),
      );
      return;
    }

    final transaction = TransactionModel(
      opNumber: generateOperationNumber(),
      dateTime: getCurrentDateTime(),
      name: name,
      amount: parsedAmount.toStringAsFixed(2),
      toAccount: account,
    );

    final box = Hive.box('transactions');
    final list = box.get('list', defaultValue: <Map>[]) as List;
    list.add(transaction.toMap());
    await box.put('list', list);

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SuccessScreen(transaction: transaction),
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    accountController.dispose();
    amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/image1.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 195),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Column(
                    children: [
                      _buildInputField(nameController, 'أدخل اسم المستفيد...'),
                      const SizedBox(height: 14),
                      _buildInputField(accountController, 'أدخل رقم الحساب...', isNumber: true),
                      const SizedBox(height: 14),
                      _buildInputField(amountController, 'أدخل المبلغ...', isNumber: true),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: submitTransfer,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE31C23),
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'إرسال',
                            style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(TextEditingController controller, String hint, {bool isNumber = false}) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        textAlign: TextAlign.right,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

// ==================== Screen 2: Success (Green) ====================
class SuccessScreen extends StatelessWidget {
  final TransactionModel transaction;
  final ScreenshotController screenshotController = ScreenshotController();

  SuccessScreen({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Screenshot(
        controller: screenshotController,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/image2.png',
                fit: BoxFit.cover,
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 210),
                  _buildDataRow(transaction.opNumber),
                  _buildDataRow(transaction.dateTime),
                  _buildDataRow(transaction.fromAccount),
                  _buildDataRow(transaction.toAccount),
                  _buildDataRow(transaction.name),
                  _buildDataRow('N/A'),
                  _buildDataRow('N/A'),
                  _buildDataRow(transaction.amount),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 100),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MenuScreen(transaction: transaction),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF2E7D32),
                        padding: const EdgeInsets.symmetric(horizontal: 55, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'موافق',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow(String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ==================== Screen 3: Menu ====================
class MenuScreen extends StatelessWidget {
  final TransactionModel transaction;

  const MenuScreen({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/image3.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 130),
                _menuItem(
                  title: 'تحويل لحسابات بنك الخرطوم',
                  onTap: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const TransferScreen()),
                      (route) => false,
                    );
                  },
                ),
                _menuItem(
                  title: 'الدفع عبر الموبايل',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HistoryScreen()),
                    );
                  },
                ),
                _menuItem(
                  title: 'تحويل لبنك آخر (باستخدام رقم البطاقة)',
                  onTap: null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuItem({required String title, required VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.arrow_back_ios, size: 16, color: Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== Screen 4: Details ====================
class DetailsScreen extends StatelessWidget {
  final TransactionModel transaction;
  final ScreenshotController screenshotController = ScreenshotController();

  DetailsScreen({super.key, required this.transaction});

  Future<void> _saveToGallery(BuildContext context) async {
    final status = await Permission.photos.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب السماح بالوصول للصور')),
      );
      return;
    }

    final image = await screenshotController.capture();
    if (image != null) {
      await Gal.putImageBytes(image);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم الحفظ في المعرض بنجاح')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Screenshot(
        controller: screenshotController,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/image4.png',
                fit: BoxFit.cover,
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 140),
                  _detailRow(transaction.opNumber),
                  _detailRow(transaction.dateTime),
                  _detailRow('تحويل إلى حساب آخر'),
                  _detailRow(transaction.amount),
                  _detailRow(transaction.fromAccount),
                  _detailRow(transaction.toAccount),
                  _detailRow('نجاح'),
                  _detailRow(transaction.name),
                  _detailRow('N/A'),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 80),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('رجوع'),
                        ),
                        const SizedBox(width: 20),
                        ElevatedButton(
                          onPressed: () => _saveToGallery(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE31C23),
                          ),
                          child: const Text('حفظ في المعرض', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ==================== History Screen ====================
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<TransactionModel> transactions = [];

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  void _loadTransactions() {
    final box = Hive.box('transactions');
    final list = box.get('list', defaultValue: <Map>[]) as List;
    setState(() {
      transactions = list
          .map((e) => TransactionModel.fromMap(Map<String, dynamic>.from(e)))
          .toList()
          .reversed
          .toList();
    });
  }

  void _deleteTransaction(int index) async {
    final box = Hive.box('transactions');
    final list = box.get('list', defaultValue: <Map>[]) as List;
    // لأن القائمة معكوسة في العرض
    final realIndex = list.length - 1 - index;
    list.removeAt(realIndex);
    await box.put('list', list);
    _loadTransactions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('العمليات السابقة'),
        backgroundColor: const Color(0xFFE31C23),
        foregroundColor: Colors.white,
      ),
      body: transactions.isEmpty
          ? const Center(child: Text('لا توجد عمليات سابقة'))
          : ListView.builder(
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final t = transactions[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text(t.name, textAlign: TextAlign.right),
                    subtitle: Text('${t.amount}  |  ${t.dateTime}', textAlign: TextAlign.right),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteTransaction(index),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DetailsScreen(transaction: t),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
