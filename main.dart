// ignore_for_file: deprecated_member_use, use_build_context_synchronously, library_private_types_in_public_api, use_key_in_widget_constructors

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:math_expressions/math_expressions.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

// --- Data Model ---
class ExpenseItem {
  final int? id;
  String name;
  double cost;
  final DateTime date;

  ExpenseItem({this.id, required this.name, required this.cost, required this.date});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'cost': cost,
      'date': date.toIso8601String(),
    };
  }
}

// --- Database Helper ---
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = p.join(await getDatabasesPath(), 'expense_database.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE expenses(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, cost REAL, date TEXT)',
        );
      },
    );
  }

  Future<void> insertExpense(ExpenseItem item) async {
    final db = await database;
    await db.insert('expenses', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertExpensesForDate(DateTime date, List<ExpenseItem> items) async {
    final db = await database;
    await db.delete('expenses', where: 'date = ?', whereArgs: [DateUtils.dateOnly(date).toIso8601String()]);
    for (var item in items) {
      await insertExpense(item);
    }
  }

  Future<Map<DateTime, List<ExpenseItem>>> getAllExpenses() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('expenses');
    final Map<DateTime, List<ExpenseItem>> groupedExpenses = {};

    for (var map in maps) {
      final date = DateUtils.dateOnly(DateTime.parse(map['date']));
      final item = ExpenseItem(
        id: map['id'],
        name: map['name'],
        cost: map['cost'],
        date: date,
      );
      if (groupedExpenses[date] == null) {
        groupedExpenses[date] = [];
      }
      groupedExpenses[date]!.add(item);
    }
    return groupedExpenses;
  }
}

// --- PDF API Helper ---
class PdfInvoiceApi {
  static Future<File> generate(DateTime date, List<ExpenseItem> items, double total) async {
    final pdf = pw.Document();
    final formattedDate = DateFormat('dd-MM-yyyy').format(date);

    pdf.addPage(pw.MultiPage(
      build: (pw.Context context) => [
        _buildHeader(date),
        pw.SizedBox(height: 1 * PdfPageFormat.cm),
        _buildTitle(),
        _buildInvoice(items),
        pw.Divider(),
        _buildTotal(total),
      ],
      footer: (pw.Context context) => _buildFooter(),
    ));

    return _saveDocument(name: 'expense-$formattedDate.pdf', pdf: pdf);
  }

  static pw.Widget _buildHeader(DateTime date) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(height: 1 * PdfPageFormat.cm),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('EXPENDRIA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 24, color: PdfColors.blue)),
              pw.SizedBox(width: 50), // Placeholder for removed QR code
            ],
          ),
          pw.SizedBox(height: 1 * PdfPageFormat.cm),
          pw.Text('Date: ${DateFormat('dd MMMM, yyyy').format(date)}'),
          pw.SizedBox(height: 0.5 * PdfPageFormat.cm),
        ],
      );

  static pw.Widget _buildTitle() => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'DAILY EXPENSE REPORT',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 0.8 * PdfPageFormat.cm),
        ],
      );

  static pw.Widget _buildInvoice(List<ExpenseItem> items) {
    final headers = ['Item Name', 'Cost (Rs)'];
    final data = items.map((item) => [item.name, 'Rs ${item.cost.toStringAsFixed(2)}']).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      border: null,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellHeight: 30,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerRight,
      },
    );
  }

  static pw.Widget _buildTotal(double total) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Row(
        children: [
          pw.Spacer(flex: 6),
          pw.Expanded(
            flex: 4,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Divider(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                    pw.Text('Rs ${total.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                  ],
                ),
                pw.Divider(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter() => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Divider(),
          pw.SizedBox(height: 2 * PdfPageFormat.mm),
          pw.Text('Expendria - Your Personal Expense Tracker'),
        ],
      );

  static Future<File> _saveDocument({required String name, required pw.Document pdf}) async {
    final bytes = await pdf.save();
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes);
    return file;
  }

  static Future openFile(File file) async {
    final url = file.path;
    await OpenFilex.open(url);
  }
}


// --- State Management ---
final ValueNotifier<Map<DateTime, List<ExpenseItem>>> allExpensesNotifier = ValueNotifier({});

Future<void> main() async {
  // Ensure that Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();
  // Load all expenses from the database when the app starts
  allExpensesNotifier.value = await DatabaseHelper().getAllExpenses();
  runApp(const ExpenseApp());
}

class ExpenseApp extends StatelessWidget {
  const ExpenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expendria',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 96, 177, 100), // A modern, deep indigo
          primary: const Color.fromARGB(255, 69, 81, 101),
          secondary: const Color(0xFF00E676), // A vibrant green accent
          surface: const Color.fromARGB(255, 198, 219, 231),
          background: const Color.fromARGB(255, 251, 255, 231), // A very light grey background
        ),
        useMaterial3: true,
        textTheme: Theme.of(context).textTheme.apply(
              fontFamily: 'Roboto',
              bodyColor: const Color.fromARGB(255, 35, 45, 66),
              displayColor: const Color.fromARGB(255, 0, 0, 0),
            ),
      ),
      home: const MainScreen(),
    );
  }
}

// --- Main Screen with Bottom Navigation ---
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static final List<Widget> _widgetOptions = <Widget>[
    const CalendarScreen(),
    const InsightsScreen(),
    // ignore: prefer_const_constructors
    CalculatorPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EXPENDRIA', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.5)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        centerTitle: true,
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today_outlined), activeIcon: Icon(Icons.calendar_today), label: 'Calendar'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), activeIcon: Icon(Icons.bar_chart), label: 'Insights'),
          BottomNavigationBarItem(icon: Icon(Icons.calculate_outlined), activeIcon: Icon(Icons.calculate), label: 'Calculator'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: const Color.fromARGB(255, 100, 101, 105),
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
      ),
    );
  }
}

// --- Background Widget ---
Widget _buildBackground(BuildContext context, Widget child) {
  return Container(
    decoration: const BoxDecoration(
      image: DecorationImage(
        image: AssetImage("assets/14485905_5475310.jpg"),
        fit: BoxFit.cover,
      ),
    ),
    child: child,
  );
}

// --- Calendar Screen ---
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late String _greeting;
  DateTime _focusedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    _updateGreeting();
    Timer.periodic(const Duration(minutes: 1), (timer) => _updateGreeting());
  }

  void _updateGreeting() {
    final hour = DateTime.now().hour;
    setState(() {
      if (hour < 12) {
        _greeting = 'Good morning';
      } else if (hour < 17) {
        _greeting = 'Good afternoon';
      } else {
        _greeting = 'Good evening';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _buildBackground(
      context,
      ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text(
            _greeting,
            style: const TextStyle(
              fontFamily: 'cursive',
              fontSize: 42,
              color: Colors.black87,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'CALENDAR',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[700], letterSpacing: 1.2),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 4,
            shadowColor: Colors.black.withOpacity(0.1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: Theme.of(context).colorScheme.surface.withOpacity(0.85),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ValueListenableBuilder<Map<DateTime, List<ExpenseItem>>>(
                valueListenable: allExpensesNotifier,
                builder: (context, expenses, child) {
                  return TableCalendar(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      leftChevronIcon: Icon(Icons.chevron_left, color: Colors.black54),
                      rightChevronIcon: Icon(Icons.chevron_right, color: Colors.black54),
                    ),
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (context, date, events) {
                        final dateKey = DateUtils.dateOnly(date);
                        if (expenses.containsKey(dateKey) && expenses[dateKey]!.isNotEmpty) {
                          return Positioned(
                            bottom: 1,
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Color.fromARGB(255, 73, 99, 120),
                                shape: BoxShape.circle,
                              ),
                              width: 7,
                              height: 7,
                            ),
                          );
                        }
                        return null;
                      },
                    ),
                    calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    onDaySelected: (selectedDay, focusedDay) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddExpenseScreen(selectedDate: selectedDay),
                        ),
                      ).then((_) {
                        // This ensures the calendar screen reflects any changes made on the next screen
                        setState(() {});
                      });
                    },
                    onPageChanged: (focusedDay) {
                      setState(() {
                        _focusedDay = focusedDay;
                      });
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Add Expense Screen ---
class AddExpenseScreen extends StatefulWidget {
  final DateTime selectedDate;
  const AddExpenseScreen({super.key, required this.selectedDate});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  List<ExpenseItem> _items = [];
  double _total = 0.0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    DateTime dateKey = DateUtils.dateOnly(widget.selectedDate);
    final currentExpenses = allExpensesNotifier.value;

    if (currentExpenses.containsKey(dateKey) && currentExpenses[dateKey]!.isNotEmpty) {
      _items = List.from(currentExpenses[dateKey]!.map(
        (item) => ExpenseItem(name: item.name, cost: item.cost, date: item.date),
      ));
    } else {
      _items.add(ExpenseItem(name: '', cost: 0, date: dateKey));
    }

    _calculateTotal();
  }

  void _calculateTotal() {
    _total = _items.fold(0.0, (sum, item) => sum + item.cost);
    setState(() {});
  }

  void _addNewItem() {
    setState(() {
      _items.add(ExpenseItem(name: '', cost: 0, date: DateUtils.dateOnly(widget.selectedDate)));
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
      _calculateTotal();
      // Immediately save the change to the database
      _updateDatabase();
    });
  }

  Future<void> _updateDatabase() async {
    DateTime dateKey = DateUtils.dateOnly(widget.selectedDate);
    // When updating, we consider all items currently in the list
    await DatabaseHelper().insertExpensesForDate(dateKey, _items);
    allExpensesNotifier.value = await DatabaseHelper().getAllExpenses();
  }

  Future<void> _generatePdf() async {
    final validItems = _items.where((item) => item.name.trim().isNotEmpty && item.cost > 0).toList();
    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one item to create a PDF.')),
      );
      return;
    }

    final pdfFile = await PdfInvoiceApi.generate(widget.selectedDate, validItems, _total);
    PdfInvoiceApi.openFile(pdfFile);
  }

  Future<void> _saveAndExit() async {
    // Filter out invalid items only when finally saving and exiting
    DateTime dateKey = DateUtils.dateOnly(widget.selectedDate);
    List<ExpenseItem> validItems = _items.where((item) => item.name.trim().isNotEmpty && item.cost > 0).toList();
    await DatabaseHelper().insertExpensesForDate(dateKey, validItems);
    allExpensesNotifier.value = await DatabaseHelper().getAllExpenses();

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Expense")),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // --- Display Selected Date ---
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                DateFormat('MMMM d, yyyy').format(widget.selectedDate),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 55, 59, 87)),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _items.length,
                itemBuilder: (itemBuilderContext, index) {
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              decoration: const InputDecoration(labelText: "Name"),
                              initialValue: _items[index].name,
                              onChanged: (value) {
                                _items[index].name = value;
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 80,
                            child: TextFormField(
                              decoration: const InputDecoration(labelText: "₹"),
                              initialValue: _items[index].cost == 0 ? '' : _items[index].cost.toString(),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (value) {
                                final parsed = double.tryParse(value) ?? 0;
                                _items[index].cost = parsed;
                                _calculateTotal();
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Color.fromARGB(255, 249, 93, 81)),
                            onPressed: () => _removeItem(index),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // PDF Button on the left
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFF3D5AFE)),
                  iconSize: 30,
                  onPressed: _generatePdf,
                  tooltip: 'Save as PDF',
                ),
                const Spacer(),
                Text("Total: ₹${_total.toStringAsFixed(2)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(width: 16),
                // Add Item Button on the right
                ElevatedButton.icon(
                  onPressed: _addNewItem,
                  icon: const Icon(Icons.add),
                  label: const Text("New Item"),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saveAndExit,
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(45)),
              child: const Text("OK", style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}


// --- Insights Screen ---
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  String _chartType = 'Weekly';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBackground(
        context,
        ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            SegmentedButton<String>(
              style: SegmentedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0.8),
                selectedBackgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                selectedForegroundColor: Theme.of(context).colorScheme.primary,
              ),
              segments: const <ButtonSegment<String>>[
                ButtonSegment<String>(value: 'Weekly', label: Text('Weekly')),
                ButtonSegment<String>(value: 'Monthly', label: Text('Monthly')),
                ButtonSegment<String>(value: 'Yearly', label: Text('Yearly')),
              ],
              selected: {_chartType},
              onSelectionChanged: (newSelection) => setState(() => _chartType = newSelection.first),
            ),
            const SizedBox(height: 24),
            ValueListenableBuilder<Map<DateTime, List<ExpenseItem>>>(
              valueListenable: allExpensesNotifier,
              builder: (context, expenses, child) {
                return ExpenseChartContainer(chartType: _chartType, expenses: expenses);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// --- Expense Chart Container Widget (Handles data processing) ---
class ExpenseChartContainer extends StatelessWidget {
  final String chartType;
  final Map<DateTime, List<ExpenseItem>> expenses;

  const ExpenseChartContainer({super.key, required this.chartType, required this.expenses});

  @override
  Widget build(BuildContext context) {
    final List<BarChartGroupData> chartData = _getBarGroups();
    final double totalExpense = chartData.fold(0.0, (sum, group) => sum + group.barRods.first.toY);
    final bool hasData = totalExpense > 0;

    return Card(
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Theme.of(context).colorScheme.surface.withOpacity(0.85),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SizedBox(
              height: 300,
              child: hasData
                  ? ExpenseChart(chartType: chartType, data: chartData)
                  : const Center(child: Text("No data to display for this period.", style: TextStyle(fontSize: 16, color: Color.fromARGB(255, 138, 138, 138)))),
            ),
            const SizedBox(height: 24),
            if (hasData)
              Text(
                '$chartType Total: Rs ${totalExpense.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
          ],
        ),
      ),
    );
  }

  List<BarChartGroupData> _getBarGroups() {
    switch (chartType) {
      case 'Weekly': return _getWeeklyData();
      case 'Monthly': return _getMonthlyData();
      case 'Yearly': return _getYearlyData();
      default: return [];
    }
  }

  List<BarChartGroupData> _getWeeklyData() {
    List<double> dailyTotals = List.filled(7, 0.0);
    DateTime now = DateTime.now();
    DateTime startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    for (int i = 0; i < 7; i++) {
      DateTime day = DateUtils.dateOnly(startOfWeek.add(Duration(days: i)));
      if (expenses.containsKey(day)) {
        dailyTotals[i] = expenses[day]!.fold(0.0, (sum, item) => sum + item.cost);
      }
    }
    return List.generate(7, (i) => BarChartGroupData(x: i, barRods: [BarChartRodData(toY: dailyTotals[i], color: const Color.fromARGB(255, 51, 69, 97), width: 15, borderRadius: BorderRadius.circular(4))]));
  }

  List<BarChartGroupData> _getMonthlyData() {
    List<double> weeklyTotals = List.filled(5, 0.0);
    DateTime now = DateTime.now();
    expenses.forEach((date, items) {
      if (date.month == now.month && date.year == now.year) {
        int weekOfMonth = ((date.day - 1) / 7).floor();
        if (weekOfMonth < 5) {
          weeklyTotals[weekOfMonth] += items.fold(0.0, (sum, item) => sum + item.cost);
        }
      }
    });
    return List.generate(5, (i) => BarChartGroupData(x: i, barRods: [BarChartRodData(toY: weeklyTotals[i], color: const Color.fromARGB(255, 53, 96, 65), width: 15, borderRadius: BorderRadius.circular(4))]));
  }

  List<BarChartGroupData> _getYearlyData() {
    List<double> monthlyTotals = List.filled(12, 0.0);
    DateTime now = DateTime.now();
    expenses.forEach((date, items) {
      if (date.year == now.year) {
        monthlyTotals[date.month - 1] += items.fold(0.0, (sum, item) => sum + item.cost);
      }
    });
    return List.generate(12, (i) => BarChartGroupData(x: i, barRods: [BarChartRodData(toY: monthlyTotals[i], color: const Color.fromARGB(255, 101, 55, 108), width: 15, borderRadius: BorderRadius.circular(4))]));
  }
}

// --- Expense Chart Widget (Handles UI) ---
class ExpenseChart extends StatelessWidget {
  final String chartType;
  final List<BarChartGroupData> data;

  const ExpenseChart({super.key, required this.chartType, required this.data});

  @override
  Widget build(BuildContext context) {
    return BarChart(
      BarChartData(
        titlesData: _getTitlesData(),
        borderData: FlBorderData(show: false),
        barGroups: data,
        gridData: const FlGridData(show: false),
        maxY: _getMaxY(data),
      ),
    );
  }

  FlTitlesData _getTitlesData() => FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: _getBottomTitles)),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      );

  Widget _getBottomTitles(double value, TitleMeta meta) {
    String text;
    switch (chartType) {
      case 'Weekly': text = ['M', 'T', 'W', 'T', 'F', 'S', 'S'][value.toInt()]; break;
      case 'Monthly': text = 'W${value.toInt() + 1}'; break;
      case 'Yearly': text = DateFormat.MMM().format(DateTime(0, value.toInt() + 1)); break;
      default: text = '';
    }
    return SideTitleWidget(axisSide: meta.axisSide, space: 4, child: Text(text, style: const TextStyle(fontSize: 10, color: Colors.grey)));
  }

  double _getMaxY(List<BarChartGroupData> data) {
    if (data.isEmpty) return 100.0;
    double max = data.map((d) => d.barRods.first.toY).reduce((a, b) => a > b ? a : b);
    return max == 0 ? 100.0 : max * 1.2;
  }
}

// --- Calculator Screen ---
class CalculatorPage extends StatefulWidget {
  const CalculatorPage({super.key});

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  String userInput = '';
  String result = '0';
  bool isOpeningBracket = true;

  final List<String> buttons = [
    'C', '()', '%', '/',
    '7', '8', '9', '*',
    '4', '5', '6', '-',
    '1', '2', '3', '+',
    '.', '0', 'DEL', '='
  ];

  void onButtonPressed(String text) {
    setState(() {
      if (text == 'C') {
        userInput = '';
        result = '0';
      } else if (text == 'DEL') {
        if (userInput.isNotEmpty) {
          userInput = userInput.substring(0, userInput.length - 1);
        }
      } else if (text == '=') {
        try {
          String expression = userInput.replaceAll('×', '*').replaceAll('÷', '/');
          Parser p = Parser();
          Expression exp = p.parse(expression);
          ContextModel cm = ContextModel();
          double eval = exp.evaluate(EvaluationType.REAL, cm);
          result = eval.toString();
        } catch (e) {
          result = 'Invalid';
        }
      } else if (text == '()') {
        userInput += isOpeningBracket ? '(' : ')';
        isOpeningBracket = !isOpeningBracket;
      } else {
        userInput += text;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 198, 219, 231),
      body: Column(
        children: [
          const SizedBox(height: 60),
          Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              userInput,
              style: const TextStyle(fontSize: 30, color: Color.fromARGB(255, 110, 110, 110)),
            ),
          ),
          Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text(
              result,
              style: const TextStyle(fontSize: 48, color: Color.fromARGB(255, 21, 115, 70)),
            ),
          ),
          const Divider(color: Colors.white54),
          Expanded(
            child: GridView.builder(
              itemCount: buttons.length,
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4),
              itemBuilder: (context, index) {
                final buttonText = buttons[index];

                Color getColor(String text) {
                  if (text == 'C') return Colors.red;
                  if (text == 'DEL') return Colors.orange;
                  if (['/', '*', '-', '+', '='].contains(text)) return Colors.green;
                  return Colors.white;
                }

                return GestureDetector(
                  onTap: () => onButtonPressed(buttonText),
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 59, 63, 77),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        buttonText,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: getColor(buttonText),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
