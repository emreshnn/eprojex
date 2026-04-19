import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:math' as math;


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EProjexApp());
}

// ══════════════════════════════════════════════════════════════
//  YARDIMCI FONKSİYONLAR
// ══════════════════════════════════════════════════════════════

double parseTrMoney(String input) {
  String text = input.trim().replaceAll('₺', '').replaceAll(' ', '').replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(text) ?? 0;
}

String formatMoney(num value) {
  final negative = value < 0;
  final fixed = value.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  final chars = parts[0].split('').reversed.toList();
  final buffer = StringBuffer();
  for (int i = 0; i < chars.length; i++) {
    if (i > 0 && i % 3 == 0) buffer.write('.');
    buffer.write(chars[i]);
  }
  final result = '${buffer.toString().split('').reversed.join()},${parts[1]}';
  return negative ? '-$result' : result;
}

String formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

String monthNameTr(int month) => [
  'Ocak','Şubat','Mart','Nisan','Mayıs','Haziran',
  'Temmuz','Ağustos','Eylül','Ekim','Kasım','Aralık'
][month - 1];

// ══════════════════════════════════════════════════════════════
//  TEMA & RENKLER
// ══════════════════════════════════════════════════════════════

class AppColors {
  static const primary    = Color(0xFF1E40AF);
  static const primaryLight = Color(0xFF3B82F6);
  static const accent     = Color(0xFF06B6D4);
  static const success    = Color(0xFF10B981);
  static const warning    = Color(0xFFF59E0B);
  static const danger     = Color(0xFFEF4444);
  static const bg         = Color(0xFFF0F4FF);
  static const surface    = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF8FAFF);
  static const border     = Color(0xFFE2E8F0);
  static const textDark   = Color(0xFF0F172A);
  static const textMid    = Color(0xFF475569);
  static const textLight  = Color(0xFF94A3B8);
  static const exitedBg   = Color(0xFFFFF1F2);
  static const exitedText = Color(0xFFBE123C);

  // Karanlık mod renkleri
  static const darkSurface    = Color(0xFF1E293B);
  static const darkSurfaceAlt = Color(0xFF0F172A);
  static const darkBorder     = Color(0xFF334155);
  static const darkBg         = Color(0xFF0F172A);

  static Color surfaceOf(BuildContext ctx) =>
    Theme.of(ctx).brightness == Brightness.dark ? darkSurface : surface;
  static Color surfaceAltOf(BuildContext ctx) =>
    Theme.of(ctx).brightness == Brightness.dark ? const Color(0xFF1A2540) : surfaceAlt;
  static Color borderOf(BuildContext ctx) =>
    Theme.of(ctx).brightness == Brightness.dark ? darkBorder : border;
  static Color bgOf(BuildContext ctx) =>
    Theme.of(ctx).brightness == Brightness.dark ? darkBg : bg;
  static Color textDarkOf(BuildContext ctx) =>
    Theme.of(ctx).brightness == Brightness.dark ? Colors.white : textDark;
  static Color textMidOf(BuildContext ctx) =>
    Theme.of(ctx).brightness == Brightness.dark ? const Color(0xFFCBD5E1) : textMid;
  static Color textLightOf(BuildContext ctx) =>
    Theme.of(ctx).brightness == Brightness.dark ? const Color(0xFF94A3B8) : textLight;
}

// ══════════════════════════════════════════════════════════════
//  VERİ MODELLERİ
// ══════════════════════════════════════════════════════════════

// Aylık gün sayısı (Şubat dahil)
int daysInMonth(int month, int year) {
  return 30; // Sabit 30 gün üzerinden hesaplanır
}

class MonthlyPayment {
  int month; int year;
  double salary;        // Tam aylık maaş
  double minimumWage;   // Asgari ücret
  double advance;       // Avans
  double sgk;           // SGK
  double deduction;     // Kesinti
  String deductionNote;
  int? startDay;        // O ay işe giriş günü
  int leaveDays;        // İzin günü sayısı
  bool salaryPaid;
  bool minimumWagePaid;
  bool advancePaid;
  bool cashPaid;
  bool sgkPaid;

  MonthlyPayment({
    required this.month, required this.year,
    required this.salary,
    required this.minimumWage,
    required this.advance,
    required this.sgk,
    this.deduction = 0, this.deductionNote = '',
    this.startDay,
    this.leaveDays = 0,
    this.salaryPaid = false,
    this.minimumWagePaid = false,
    this.advancePaid = false,
    this.cashPaid = false,
    this.sgkPaid = false,
  });

  int get totalDaysInMonth => 30; // Sabit 30 gün

  // Çalışılan gün: ay başından mı girdi, ay ortasından mı?
  int get workedDays {
    if (startDay == null || startDay! <= 1) return totalDaysInMonth;
    return totalDaysInMonth - startDay! + 1;
  }

  bool get hasPartialMonth => startDay != null && startDay! > 1;

  // Orantılı maaş (gün hesabı dahil)
  double get calculatedSalary {
    if (!hasPartialMonth) return salary;
    return (salary / totalDaysInMonth) * workedDays;
  }

  // İzin kesintisi: izin günü * günlük maaş
  double get leaveDeduction {
    if (leaveDays <= 0) return 0;
    return (salary / totalDaysInMonth) * leaveDays;
  }

  // Net maaş = Orantılı Maaş - İzin Kesintisi
  double get netSalary => math.max(0, calculatedSalary - leaveDeduction);

  // Elden = Net Maaş - Asgari - Avans - Kesinti
  double get calculatedCash {
    final net = netSalary - minimumWage - advance - deduction;
    return net < 0 ? 0 : net;
  }

  double totalPaid() {
    // Ödenen maaş kalemleri (SGK ayrı)
    double t = 0;
    if (minimumWagePaid) t += minimumWage;
    if (advancePaid) t += advance;
    if (cashPaid) t += calculatedCash;
    return t < 0 ? 0 : t;
  }

  // SGK dahil toplam gider (proje gider hesabı için)
  double totalExpense() {
    double t = totalPaid();
    if (sgkPaid) t += sgk;
    return t;
  }

  double totalPlanned() => netSalary + minimumWage + advance + calculatedCash + sgk;

  Map<String, dynamic> toJson() => {
    'month': month, 'year': year,
    'salary': salary, 'minimumWage': minimumWage,
    'advance': advance, 'sgk': sgk,
    'deduction': deduction, 'deductionNote': deductionNote,
    'startDay': startDay, 'leaveDays': leaveDays,
    'salaryPaid': salaryPaid, 'minimumWagePaid': minimumWagePaid,
    'advancePaid': advancePaid, 'cashPaid': cashPaid, 'sgkPaid': sgkPaid,
  };

  factory MonthlyPayment.fromJson(Map<String, dynamic> j) => MonthlyPayment(
    month: j['month'], year: j['year'],
    salary: (j['salary'] as num).toDouble(),
    minimumWage: (j['minimumWage'] as num? ?? 0).toDouble(),
    advance: (j['advance'] as num? ?? 0).toDouble(),
    sgk: (j['sgk'] as num? ?? 0).toDouble(),
    deduction: (j['deduction'] as num? ?? 0).toDouble(),
    deductionNote: j['deductionNote'] ?? '',
    startDay: j['startDay'] as int?,
    leaveDays: (j['leaveDays'] as int? ?? 0),
    salaryPaid: j['salaryPaid'] ?? false,
    minimumWagePaid: j['minimumWagePaid'] ?? false,
    advancePaid: j['advancePaid'] ?? false,
    cashPaid: j['cashPaid'] ?? false,
    sgkPaid: j['sgkPaid'] ?? false,
  );
}

List<MonthlyPayment> createDefaultMonthlyPayments({
  required double salary,
  required double minimumWage,
  required double advance,
  required double sgk,
  required DateTime startDate,
  int? year,
}) {
  final y = year ?? startDate.year;
  return List.generate(12, (i) {
    final m = i + 1;
    // İşe giriş ayı ise startDay set et
    final isStartMonth = m == startDate.month && y == startDate.year;
    return MonthlyPayment(
      month: m, year: y,
      salary: salary,
      minimumWage: minimumWage,
      advance: advance,
      sgk: sgk,
      startDay: isStartMonth && startDate.day > 1 ? startDate.day : null,
    );
  });
}

class LeaveRecord {
  DateTime date; String leaveType; String note;
  LeaveRecord({required this.date, required this.leaveType, required this.note});
  Map<String, dynamic> toJson() => {'date': date.toIso8601String(), 'leaveType': leaveType, 'note': note};
  factory LeaveRecord.fromJson(Map<String, dynamic> j) => LeaveRecord(
    date: DateTime.parse(j['date']), leaveType: j['leaveType'], note: j['note']);
}

class IncomeEntry {
  String title; double amount; DateTime date; String category; String from;
  IncomeEntry({required this.title, required this.amount, required this.date, this.category = '', this.from = ''});
  Map<String, dynamic> toJson() => {'title': title, 'amount': amount, 'date': date.toIso8601String(), 'category': category, 'from': from};
  factory IncomeEntry.fromJson(Map<String, dynamic> j) => IncomeEntry(
    title: j['title'], amount: (j['amount'] as num).toDouble(),
    date: DateTime.parse(j['date']), category: j['category'] ?? '', from: j['from'] ?? '');
}

class PaymentType {
  static const cash = 'cash';       // Nakit
  static const check = 'check';     // Çek
  static const note = 'note';       // Senet
  static const debt = 'debt';       // Borç
  static const advance = 'advance'; // Avans

  static String label(String t) => switch (t) {
    cash => 'Nakit', check => 'Çek', note => 'Senet',
    debt => 'Borç', advance => 'Avans', _ => t,
  };

  static IconData icon(String t) => switch (t) {
    cash => Icons.payments_rounded,
    check => Icons.receipt_long_rounded,
    note => Icons.description_rounded,
    debt => Icons.account_balance_rounded,
    advance => Icons.forward_rounded,
    _ => Icons.attach_money_rounded,
  };
}

class EntryPayment {
  double amount;
  DateTime date;
  String method; // nakit, çek, senet
  String note;
  EntryPayment({required this.amount, required this.date, this.method = PaymentType.cash, this.note = ''});
  Map<String, dynamic> toJson() => {'amount': amount, 'date': date.toIso8601String(), 'method': method, 'note': note};
  factory EntryPayment.fromJson(Map<String, dynamic> j) => EntryPayment(
    amount: (j['amount'] as num).toDouble(),
    date: DateTime.parse(j['date']),
    method: j['method'] ?? PaymentType.cash,
    note: j['note'] ?? '',
  );
}

class SectionEntry {
  String title; double amount; DateTime date; String note; String invoiceNo;
  String paymentType; // nasıl bir işlem: nakit, çek, borç, avans
  final List<EntryPayment> payments; // yapılan ödemeler

  SectionEntry({
    required this.title, required this.amount, required this.date,
    this.note = '', this.invoiceNo = '',
    this.paymentType = PaymentType.cash,
    List<EntryPayment>? payments,
  }) : payments = payments ?? [];

  double get paidAmount => payments.fold(0, (s, p) => s + p.amount);
  double get remainingAmount => amount - paidAmount;
  bool get isFullyPaid => remainingAmount <= 0;
  bool get hasDebt => paymentType == PaymentType.debt || paymentType == PaymentType.check || paymentType == PaymentType.note || paymentType == PaymentType.advance;

  Map<String, dynamic> toJson() => {
    'title': title, 'amount': amount, 'date': date.toIso8601String(),
    'note': note, 'invoiceNo': invoiceNo, 'paymentType': paymentType,
    'payments': payments.map((p) => p.toJson()).toList(),
  };

  factory SectionEntry.fromJson(Map<String, dynamic> j) => SectionEntry(
    title: j['title'], amount: (j['amount'] as num).toDouble(),
    date: j['date'] != null ? DateTime.parse(j['date']) : DateTime.now(),
    note: j['note'] ?? '', invoiceNo: j['invoiceNo'] ?? '',
    paymentType: j['paymentType'] ?? PaymentType.cash,
    payments: (j['payments'] as List? ?? []).map((p) => EntryPayment.fromJson(p)).toList(),
  );
}

class EmployeeData {
  String name, role, phone;
  String tcNo;          // TC Kimlik No
  String iban;          // IBAN
  DateTime? birthDate;  // Doğum tarihi
  DateTime startDate; DateTime? endDate;
  double salary, advance, minimumWage, sgk;
  final List<MonthlyPayment> monthlyPayments;
  final List<LeaveRecord> leaves;

  EmployeeData({
    required this.name, required this.role, required this.phone,
    this.tcNo = '', this.iban = '', this.birthDate,
    required this.startDate, this.endDate,
    required this.salary, required this.advance,
    required this.minimumWage, required this.sgk,
    List<MonthlyPayment>? monthlyPayments, List<LeaveRecord>? leaves,
  }) : monthlyPayments = monthlyPayments ?? createDefaultMonthlyPayments(
         salary: salary, advance: advance, minimumWage: minimumWage, sgk: sgk, startDate: startDate),
       leaves = leaves ?? [];

  bool get hasExited => endDate != null;
  double totalPaid() => monthlyPayments.fold(0, (s, m) => s + m.totalPaid());
  double totalExpenseWithSgk() => monthlyPayments.fold(0, (s, m) => s + m.totalExpense());
  double totalPaidSalary() => monthlyPayments.where((m) => m.salaryPaid).fold(0, (s, m) => s + m.calculatedSalary);
  double totalPaidSgk() => monthlyPayments.where((m) => m.sgkPaid).fold(0, (s, m) => s + m.sgk);
  double totalDeduction() => monthlyPayments.fold(0, (s, m) => s + m.deduction);
  int paidMonthCount() => monthlyPayments.where((m) => m.salaryPaid).length;

  void syncUnpaidMonthlyValues() {
    for (final m in monthlyPayments) {
      if (!m.salaryPaid) m.salary = salary;
      if (!m.advancePaid) m.advance = advance;
      if (!m.minimumWagePaid) m.minimumWage = minimumWage;
      if (!m.sgkPaid) m.sgk = sgk;
    }
  }

  Map<String, dynamic> toJson() => {
    'name': name, 'role': role, 'phone': phone,
    'tcNo': tcNo, 'iban': iban,
    'birthDate': birthDate?.toIso8601String(),
    'startDate': startDate.toIso8601String(), 'endDate': endDate?.toIso8601String(),
    'salary': salary, 'advance': advance, 'minimumWage': minimumWage, 'sgk': sgk,
    'monthlyPayments': monthlyPayments.map((m) => m.toJson()).toList(),
    'leaves': leaves.map((l) => l.toJson()).toList(),
  };

  factory EmployeeData.fromJson(Map<String, dynamic> j) => EmployeeData(
    name: j['name'], role: j['role'] ?? '', phone: j['phone'] ?? '',
    tcNo: j['tcNo'] ?? '', iban: j['iban'] ?? '',
    birthDate: j['birthDate'] != null ? DateTime.parse(j['birthDate']) : null,
    startDate: DateTime.parse(j['startDate']),
    endDate: j['endDate'] != null ? DateTime.parse(j['endDate']) : null,
    salary: (j['salary'] as num).toDouble(),
    advance: (j['advance'] as num? ?? 0).toDouble(),
    minimumWage: (j['minimumWage'] as num? ?? 0).toDouble(),
    sgk: (j['sgk'] as num? ?? 0).toDouble(),
    monthlyPayments: (j['monthlyPayments'] as List).map((e) => MonthlyPayment.fromJson(e)).toList(),
    leaves: (j['leaves'] as List).map((e) => LeaveRecord.fromJson(e)).toList(),
  );
}

// Cari işlem — çek/nakit/avans verilen
class CariCredit {
  String type;   // 'check', 'cash', 'advance'
  double amount;
  DateTime date;
  String note;
  CariCredit({required this.type, required this.amount, required this.date, this.note = ''});
  Map<String, dynamic> toJson() => {'type': type, 'amount': amount, 'date': date.toIso8601String(), 'note': note};
  factory CariCredit.fromJson(Map<String, dynamic> j) => CariCredit(
    type: j['type'] ?? 'check', amount: (j['amount'] as num).toDouble(),
    date: DateTime.parse(j['date']), note: j['note'] ?? '');
}

class AppSection {
  String title, companyTitle, note;
  DateTime createdDate;
  final List<SectionEntry> entries;
  final List<CariCredit> credits; // verilen çek/nakit/avans

  AppSection({required this.title, required this.companyTitle, required this.createdDate,
    this.note = '', List<SectionEntry>? entries, List<CariCredit>? credits})
      : entries = entries ?? [], credits = credits ?? [];

  // Alınan mallar / hizmetler toplamı
  double get total => entries.fold(0, (s, e) => s + e.amount);
  // Verilen çek/nakit/avans toplamı
  double get totalCredits => credits.fold(0, (s, c) => s + c.amount);
  // Proje giderine yansıyan tutar = sadece verilen çek/nakit/avans
  double get expenseAmount => totalCredits;
  // Bakiye: verilen - alınan (+ ise alacağımız var, - ise borçluyuz)
  double get balance => totalCredits - total;
  bool get hasDebt => balance < 0;
  bool get hasCredit => balance > 0;

  Map<String, dynamic> toJson() => {
    'title': title, 'companyTitle': companyTitle,
    'createdDate': createdDate.toIso8601String(),
    'note': note,
    'entries': entries.map((e) => e.toJson()).toList(),
    'credits': credits.map((c) => c.toJson()).toList(),
  };

  factory AppSection.fromJson(Map<String, dynamic> j) => AppSection(
    title: j['title'], companyTitle: j['companyTitle'],
    createdDate: DateTime.parse(j['createdDate']),
    note: j['note'] ?? '',
    entries: (j['entries'] as List).map((e) => SectionEntry.fromJson(e)).toList(),
    credits: (j['credits'] as List? ?? []).map((c) => CariCredit.fromJson(c)).toList(),
  );
}

class ProjectData {
  String name, description, client, location;
  DateTime startDate, endDate;
  String status;
  double budget;
  double kdvRate;
  final List<IncomeEntry> incomeEntries;
  final List<AppSection> sections;
  final List<EmployeeData> employees;
  final List<Subcontractor> subcontractors;
  final List<ProjeMalzeme> malzemeler;

  ProjectData({
    required this.name, this.description = '',
    this.client = '', this.location = '',
    required this.startDate, required this.endDate,
    this.status = 'active',
    this.budget = 0,
    this.kdvRate = 0,
    List<IncomeEntry>? incomeEntries,
    List<AppSection>? sections,
    List<EmployeeData>? employees,
    List<Subcontractor>? subcontractors,
    List<ProjeMalzeme>? malzemeler,
  }) : incomeEntries = incomeEntries ?? [],
       sections = sections ?? [],
       employees = employees ?? [],
       subcontractors = subcontractors ?? [],
       malzemeler = malzemeler ?? [];

  double totalIncome() => incomeEntries.fold(0, (s, e) => s + e.amount);
  double totalExpense() {
    double t = 0;
    for (final s in sections) t += s.expenseAmount;
    for (final e in employees) t += e.totalExpenseWithSgk();
    for (final sub in subcontractors) t += sub.totalPaid;
    // Ödenen malzemeler gidere yansır
    for (final m in malzemeler) t += m.odenenToplam;
    return t;
  }
  double balance() => totalIncome() - totalExpense();
  double kdvAmount() => kdvRate > 0 ? totalIncome() * (kdvRate / 100) : 0;
  double incomeWithKdv() => totalIncome() + kdvAmount();
  bool get isOverBudget => budget > 0 && totalExpense() > budget;
  double budgetUsagePercent() => budget > 0 ? (totalExpense() / budget * 100).clamp(0, 999) : 0;

  Map<String, dynamic> toJson() => {
    'name': name, 'description': description,
    'client': client, 'location': location,
    'startDate': startDate.toIso8601String(), 'endDate': endDate.toIso8601String(),
    'status': status, 'budget': budget, 'kdvRate': kdvRate,
    'incomeEntries': incomeEntries.map((e) => e.toJson()).toList(),
    'sections': sections.map((s) => s.toJson()).toList(),
    'employees': employees.map((e) => e.toJson()).toList(),
    'subcontractors': subcontractors.map((s) => s.toJson()).toList(),
    'malzemeler': malzemeler.map((m) => m.toJson()).toList(),
  };

  factory ProjectData.fromJson(Map<String, dynamic> j) => ProjectData(
    name: j['name'], description: j['description'] ?? '',
    client: j['client'] ?? '', location: j['location'] ?? '',
    startDate: DateTime.parse(j['startDate']), endDate: DateTime.parse(j['endDate']),
    status: j['status'] ?? 'active',
    budget: (j['budget'] as num? ?? 0).toDouble(),
    kdvRate: (j['kdvRate'] as num? ?? 0).toDouble(),
    incomeEntries: (j['incomeEntries'] as List).map((e) => IncomeEntry.fromJson(e)).toList(),
    sections: (j['sections'] as List).map((e) => AppSection.fromJson(e)).toList(),
    employees: (j['employees'] as List).map((e) => EmployeeData.fromJson(e)).toList(),
    subcontractors: (j['subcontractors'] as List? ?? []).map((s) => Subcontractor.fromJson(s)).toList(),
    malzemeler: (j['malzemeler'] as List? ?? []).map((m) => ProjeMalzeme.fromJson(m)).toList(),
  );
}

// ══════════════════════════════════════════════════════════════
//  DEPOLAMA SERVİSİ (localStorage - web)
// ══════════════════════════════════════════════════════════════

class CompanyInfo {
  String name, taxNo, phone, email, address;
  CompanyInfo({this.name = 'Şirket Adı', this.taxNo = '', this.phone = '', this.email = '', this.address = ''});
  Map<String, dynamic> toJson() => {'name': name, 'taxNo': taxNo, 'phone': phone, 'email': email, 'address': address};
  factory CompanyInfo.fromJson(Map<String, dynamic> j) => CompanyInfo(
    name: j['name'] ?? 'Şirket Adı', taxNo: j['taxNo'] ?? '',
    phone: j['phone'] ?? '', email: j['email'] ?? '', address: j['address'] ?? '');
}

// ══════════════════════════════════════════════════════════════
//  FATURA MODELLERİ
// ══════════════════════════════════════════════════════════════

class InvoiceStatus {
  static const paid = 'paid';
  static const unpaid = 'unpaid';
  static const draft = 'unpaid';
  static const sent = 'unpaid';
  static const overdue = 'unpaid';
}

class InvoiceItem {
  String description;
  double quantity, unitPrice, kdvRate;
  InvoiceItem({required this.description, required this.quantity,
    required this.unitPrice, this.kdvRate = 18});
  double get subtotal => quantity * unitPrice;
  double get kdvAmount => subtotal * (kdvRate / 100);
  double get total => subtotal + kdvAmount;
  Map<String, dynamic> toJson() => {'description': description, 'quantity': quantity,
    'unitPrice': unitPrice, 'kdvRate': kdvRate};
  factory InvoiceItem.fromJson(Map<String, dynamic> j) => InvoiceItem(
    description: j['description'],
    quantity: (j['quantity'] as num).toDouble(),
    unitPrice: (j['unitPrice'] as num).toDouble(),
    kdvRate: (j['kdvRate'] as num? ?? 18).toDouble());
}

class Invoice {
  String id, direction, docType, senderName, senderTaxNo, note, status, projectId;
  // direction: 'incoming' | 'outgoing'
  // docType: 'invoice' (fatura) | 'receipt' (fis)
  int month, year;
  DateTime issueDate;
  final List<InvoiceItem> items;

  Invoice({
    required this.id,
    required this.direction,
    required this.senderName,
    required this.issueDate,
    required this.month,
    required this.year,
    this.docType = 'invoice',
    this.senderTaxNo = '',
    this.note = '',
    this.status = InvoiceStatus.unpaid,
    this.projectId = '',
    List<InvoiceItem>? items,
  }) : items = items ?? [];

  bool get isIncoming => direction == 'incoming';
  bool get isOutgoing => direction == 'outgoing';
  bool get isFatura => docType == 'invoice';
  bool get isFis => docType == 'receipt';
  String get docLabel => docType == 'receipt' ? 'Fis' : 'Fatura';
  String get invoiceNo => '${isIncoming ? "GEL" : "GID"}-${isFis ? "FIS" : "FAT"}-${id.substring(math.max(0, id.length - 6))}';

  double subtotal() => items.fold(0, (s, i) => s + i.subtotal);
  double kdvAmount() => items.fold(0, (s, i) => s + i.kdvAmount);
  double total() => subtotal() + kdvAmount();
  bool get isPaid => status == InvoiceStatus.paid;

  Map<String, dynamic> toJson() => {
    'id': id, 'direction': direction, 'docType': docType,
    'senderName': senderName, 'senderTaxNo': senderTaxNo,
    'note': note, 'status': status, 'projectId': projectId,
    'month': month, 'year': year,
    'issueDate': issueDate.toIso8601String(),
    'items': items.map((i) => i.toJson()).toList(),
  };

  factory Invoice.fromJson(Map<String, dynamic> j) => Invoice(
    id: j['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
    direction: j['direction'] ?? 'outgoing',
    docType: j['docType'] ?? 'invoice',
    senderName: j['senderName'] ?? j['clientName'] ?? '',
    senderTaxNo: j['senderTaxNo'] ?? j['clientTaxNo'] ?? '',
    note: j['note'] ?? '',
    status: j['status'] ?? InvoiceStatus.unpaid,
    projectId: j['projectId'] ?? '',
    month: j['month'] ?? DateTime.now().month,
    year: j['year'] ?? DateTime.now().year,
    issueDate: j['issueDate'] != null ? DateTime.parse(j['issueDate'])
      : j['date'] != null ? DateTime.parse(j['date']) : DateTime.now(),
    items: (j['items'] as List? ?? []).map((i) => InvoiceItem.fromJson(i)).toList(),
  );
}

// ══════════════════════════════════════════════════════════════
//  TAŞERON MODELLERİ
// ══════════════════════════════════════════════════════════════

class SubcontractorPayment {
  String type;        // 'advance', 'progress', 'final'
  String payMethod;   // 'cash', 'check' (nakit / çek)
  String workItem;    // iş kalemi açıklaması
  double amount;
  DateTime date;
  String note;
  SubcontractorPayment({required this.type, required this.amount, required this.date,
    this.payMethod = 'cash', this.workItem = '', this.note = ''});
  String get typeLabel => switch(type) { 'advance' => 'Avans', 'progress' => 'Hakediş', 'final' => 'Kesin Hakediş', _ => type };
  String get methodLabel => payMethod == 'check' ? 'Çek' : 'Nakit';
  Map<String, dynamic> toJson() => {'type': type, 'amount': amount, 'date': date.toIso8601String(),
    'note': note, 'payMethod': payMethod, 'workItem': workItem};
  factory SubcontractorPayment.fromJson(Map<String, dynamic> j) => SubcontractorPayment(
    type: j['type'] ?? 'advance', amount: (j['amount'] as num).toDouble(),
    date: DateTime.parse(j['date']), note: j['note'] ?? '',
    payMethod: j['payMethod'] ?? 'cash', workItem: j['workItem'] ?? '');
}

class SubcontractorWork {
  String description;
  String unit; // m2, m3, adet, ton, metre...
  double quantity, unitPrice;
  SubcontractorWork({required this.description, required this.unit, required this.quantity, required this.unitPrice});
  double get total => quantity * unitPrice;
  Map<String, dynamic> toJson() => {'description': description, 'unit': unit, 'quantity': quantity, 'unitPrice': unitPrice};
  factory SubcontractorWork.fromJson(Map<String, dynamic> j) => SubcontractorWork(
    description: j['description'], unit: j['unit'] ?? 'adet',
    quantity: (j['quantity'] as num).toDouble(), unitPrice: (j['unitPrice'] as num).toDouble());
}

class Subcontractor {
  String id, name, contact, phone, taxNo, note;
  final List<SubcontractorWork> works;
  final List<SubcontractorPayment> payments;

  Subcontractor({required this.id, required this.name, this.contact = '',
    this.phone = '', this.taxNo = '', this.note = '',
    List<SubcontractorWork>? works, List<SubcontractorPayment>? payments})
    : works = works ?? [], payments = payments ?? [];

  double get totalContractAmount => works.fold(0, (s, w) => s + w.total);
  double get totalPaid => payments.fold(0, (s, p) => s + p.amount);
  double get remaining => totalContractAmount - totalPaid;
  bool get isFullyPaid => remaining <= 0;
  double get progressPercent => totalContractAmount > 0 ? (totalPaid / totalContractAmount * 100).clamp(0, 100) : 0;

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'contact': contact, 'phone': phone,
    'taxNo': taxNo, 'note': note,
    'works': works.map((w) => w.toJson()).toList(),
    'payments': payments.map((p) => p.toJson()).toList(),
  };

  factory Subcontractor.fromJson(Map<String, dynamic> j) => Subcontractor(
    id: j['id'] ?? '', name: j['name'] ?? '', contact: j['contact'] ?? '',
    phone: j['phone'] ?? '', taxNo: j['taxNo'] ?? '', note: j['note'] ?? '',
    works: (j['works'] as List? ?? []).map((w) => SubcontractorWork.fromJson(w)).toList(),
    payments: (j['payments'] as List? ?? []).map((p) => SubcontractorPayment.fromJson(p)).toList(),
  );
}

// ══════════════════════════════════════════════════════════════
//  MÜŞTERİ & TEDARİKÇİ MODELLERİ
// ══════════════════════════════════════════════════════════════

class ContactType { static const customer = 'customer'; static const supplier = 'supplier'; }

class Contact {
  String id, name, type, phone, email, address, taxNo, note;
  Contact({required this.id, required this.name, required this.type,
    this.phone = '', this.email = '', this.address = '', this.taxNo = '', this.note = ''});
  bool get isCustomer => type == ContactType.customer;
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'type': type, 'phone': phone, 'email': email, 'address': address, 'taxNo': taxNo, 'note': note};
  factory Contact.fromJson(Map<String, dynamic> j) => Contact(
    id: j['id'] ?? '', name: j['name'] ?? '', type: j['type'] ?? '',
    phone: j['phone'] ?? '', email: j['email'] ?? '', address: j['address'] ?? '',
    taxNo: j['taxNo'] ?? '', note: j['note'] ?? '');
}

// ══════════════════════════════════════════════════════════════
//  ÇEK & SENET MODELLERİ
// ══════════════════════════════════════════════════════════════

class CheckStatus { static const pending = 'pending'; static const cashed = 'cashed'; static const bounced = 'bounced'; }

class CheckRecord {
  String id, type, drawer, bank, no, status, note, projectId, recipient;
  double amount;
  DateTime dueDate, issueDate;
  CheckRecord({required this.id, required this.type, required this.drawer,
    required this.bank, required this.no, required this.amount,
    required this.dueDate, required this.issueDate,
    this.status = CheckStatus.pending, this.note = '',
    this.projectId = '', this.recipient = ''});
  bool get isPending => status == CheckStatus.pending;
  bool get isOverdue => isPending && dueDate.isBefore(DateTime.now());
  Map<String, dynamic> toJson() => {'id': id, 'type': type, 'drawer': drawer, 'bank': bank,
    'no': no, 'amount': amount, 'dueDate': dueDate.toIso8601String(),
    'issueDate': issueDate.toIso8601String(), 'status': status, 'note': note,
    'projectId': projectId, 'recipient': recipient};
  factory CheckRecord.fromJson(Map<String, dynamic> j) => CheckRecord(
    id: j['id'] ?? '', type: j['type'] ?? 'check', drawer: j['drawer'] ?? '',
    bank: j['bank'] ?? '', no: j['no'] ?? '', amount: (j['amount'] as num).toDouble(),
    dueDate: DateTime.parse(j['dueDate']), issueDate: DateTime.parse(j['issueDate']),
    status: j['status'] ?? CheckStatus.pending, note: j['note'] ?? '',
    projectId: j['projectId'] ?? '', recipient: j['recipient'] ?? '');
}

// ══════════════════════════════════════════════════════════════
//  TEKLİF & SÖZLEŞME MODELLERİ
// ══════════════════════════════════════════════════════════════

class ProposalStatus { static const draft = 'draft'; static const sent = 'sent'; static const accepted = 'accepted'; static const rejected = 'rejected'; }

class ProposalItem {
  String description;
  double quantity, unitPrice;
  ProposalItem({required this.description, required this.quantity, required this.unitPrice});
  double get total => quantity * unitPrice;
  Map<String, dynamic> toJson() => {'description': description, 'quantity': quantity, 'unitPrice': unitPrice};
  factory ProposalItem.fromJson(Map<String, dynamic> j) => ProposalItem(
    description: j['description'], quantity: (j['quantity'] as num).toDouble(), unitPrice: (j['unitPrice'] as num).toDouble());
}

class Proposal {
  String id, title, clientName, status, note, projectId;
  DateTime date;
  double kdvRate;
  final List<ProposalItem> items;
  Proposal({required this.id, required this.title, required this.clientName,
    required this.date, this.status = ProposalStatus.draft,
    this.note = '', this.projectId = '', this.kdvRate = 0, List<ProposalItem>? items})
    : items = items ?? [];
  double subtotal() => items.fold(0, (s, i) => s + i.total);
  double kdvAmount() => subtotal() * (kdvRate / 100);
  double total() => subtotal() + kdvAmount();
  String get statusLabel => switch (status) { ProposalStatus.draft => 'Taslak', ProposalStatus.sent => 'Gönderildi', ProposalStatus.accepted => 'Kabul Edildi', ProposalStatus.rejected => 'Reddedildi', _ => status };
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'clientName': clientName, 'date': date.toIso8601String(), 'status': status, 'note': note, 'projectId': projectId, 'kdvRate': kdvRate, 'items': items.map((i) => i.toJson()).toList()};
  factory Proposal.fromJson(Map<String, dynamic> j) => Proposal(
    id: j['id'], title: j['title'], clientName: j['clientName'] ?? '',
    date: DateTime.parse(j['date']), status: j['status'] ?? ProposalStatus.draft,
    note: j['note'] ?? '', projectId: j['projectId'] ?? '',
    kdvRate: (j['kdvRate'] as num? ?? 0).toDouble(),
    items: (j['items'] as List).map((i) => ProposalItem.fromJson(i)).toList());
}

class StorageService {
  static const _key = 'eprojex_v2';
  static const _companyKey = 'eprojex_company';
  static const _darkKey = 'eprojex_dark';
  static List<ProjectData> _cache = [];

  static Future<List<ProjectData>> load() async {
    try {
      final raw = html.window.localStorage[_key];
      if (raw == null || raw.isEmpty) return [];
      _cache = (jsonDecode(raw) as List).map((e) => ProjectData.fromJson(e)).toList();
      return _cache;
    } catch (_) { return []; }
  }

  static Future<void> save(List<ProjectData> projects) async {
    try {
      _cache = projects;
      html.window.localStorage[_key] = jsonEncode(projects.map((p) => p.toJson()).toList());
    } catch (_) {}
  }

  static CompanyInfo loadCompany() {
    try {
      final raw = html.window.localStorage[_companyKey];
      if (raw == null || raw.isEmpty) return CompanyInfo();
      return CompanyInfo.fromJson(jsonDecode(raw));
    } catch (_) { return CompanyInfo(); }
  }

  static void saveCompany(CompanyInfo info) {
    try { html.window.localStorage[_companyKey] = jsonEncode(info.toJson()); } catch (_) {}
  }

  static bool loadDarkMode() {
    try { return html.window.localStorage[_darkKey] == 'true'; } catch (_) { return false; }
  }

  static void saveDarkMode(bool val) {
    try { html.window.localStorage[_darkKey] = val.toString(); } catch (_) {}
  }

  static const _contactsKey = 'eprojex_contacts';
  static const _checksKey = 'eprojex_checks';
  static const _proposalsKey = 'eprojex_proposals';

  static List<Contact> loadContacts() {
    try {
      final raw = html.window.localStorage[_contactsKey];
      if (raw == null || raw.isEmpty) return [];
      return (jsonDecode(raw) as List).map((e) => Contact.fromJson(e)).toList();
    } catch (_) { return []; }
  }

  static void saveContacts(List<Contact> contacts) {
    try { html.window.localStorage[_contactsKey] = jsonEncode(contacts.map((c) => c.toJson()).toList()); } catch (_) {}
  }

  static List<CheckRecord> loadChecks() {
    try {
      final raw = html.window.localStorage[_checksKey];
      if (raw == null || raw.isEmpty) return [];
      return (jsonDecode(raw) as List).map((e) => CheckRecord.fromJson(e)).toList();
    } catch (_) { return []; }
  }

  static void saveChecks(List<CheckRecord> checks) {
    try { html.window.localStorage[_checksKey] = jsonEncode(checks.map((c) => c.toJson()).toList()); } catch (_) {}
  }

  static List<Proposal> loadProposals() {
    try {
      final raw = html.window.localStorage[_proposalsKey];
      if (raw == null || raw.isEmpty) return [];
      return (jsonDecode(raw) as List).map((e) => Proposal.fromJson(e)).toList();
    } catch (_) { return []; }
  }

  static void saveProposals(List<Proposal> proposals) {
    try { html.window.localStorage[_proposalsKey] = jsonEncode(proposals.map((p) => p.toJson()).toList()); } catch (_) {}
  }

  static const _invoicesKey = 'eprojex_invoices';

  static List<Invoice> loadInvoices() {
    try {
      final raw = html.window.localStorage[_invoicesKey];
      if (raw == null || raw.isEmpty) return [];
      return (jsonDecode(raw) as List).map((e) => Invoice.fromJson(e)).toList();
    } catch (_) { return []; }
  }

  static void saveInvoices(List<Invoice> invoices) {
    try { html.window.localStorage[_invoicesKey] = jsonEncode(invoices.map((i) => i.toJson()).toList()); } catch (_) {}
  }

  static const _depoKey = 'eprojex_depo';

  static List<StokItem> loadDepo() {
    try {
      final raw = html.window.localStorage[_depoKey];
      if (raw == null || raw.isEmpty) return [];
      return (jsonDecode(raw) as List).map((e) => StokItem.fromJson(e)).toList();
    } catch (_) { return []; }
  }

  static void saveDepo(List<StokItem> items) {
    try { html.window.localStorage[_depoKey] = jsonEncode(items.map((i) => i.toJson()).toList()); } catch (_) {}
  }

  // ── Kullanıcı Yönetimi ────────────────────────────────────────
  static const _usersKey    = 'eprojex_users';
  static const _sessionKey  = 'eprojex_session';
  static const _otpKey      = 'eprojex_otp';

  static Map<String, dynamic>? get currentUser {
    try {
      final raw = html.window.localStorage[_sessionKey];
      if (raw == null || raw.isEmpty) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) { return null; }
  }

  static List<Map<String, dynamic>> loadUsers() {
    try {
      final raw = html.window.localStorage[_usersKey];
      if (raw == null || raw.isEmpty) return [];
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) { return []; }
  }

  static void saveUsers(List<Map<String, dynamic>> users) {
    try { html.window.localStorage[_usersKey] = jsonEncode(users); } catch (_) {}
  }

  static bool login(String email, String password) {
    final users = loadUsers();
    final user = users.where((u) => u['email'] == email.trim().toLowerCase() && u['password'] == password).firstOrNull;
    if (user == null) return false;
    if (user['verified'] != true) return false;
    html.window.localStorage[_sessionKey] = jsonEncode(user);
    return true;
  }

  static void logout() {
    try { html.window.localStorage.remove(_sessionKey); } catch (_) {}
  }

  static bool registerUser({required String name, required String email, required String password}) {
    final users = loadUsers();
    if (users.any((u) => u['email'] == email.trim().toLowerCase())) return false;
    final isFirst = users.isEmpty;
    users.add({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'name': name.trim(),
      'email': email.trim().toLowerCase(),
      'password': password,
      'role': isFirst ? 'admin' : 'user',
      'verified': false,
      'createdAt': DateTime.now().toIso8601String(),
    });
    saveUsers(users);
    return true;
  }

  static void verifyUser(String email) {
    final users = loadUsers();
    final idx = users.indexWhere((u) => u['email'] == email.trim().toLowerCase());
    if (idx >= 0) {
      users[idx]['verified'] = true;
      saveUsers(users);
    }
  }

  static void saveOtp(String email, String otp) {
    try {
      html.window.localStorage[_otpKey] = jsonEncode({
        'email': email.trim().toLowerCase(),
        'otp': otp,
        'expiry': DateTime.now().add(const Duration(minutes: 10)).toIso8601String(),
      });
    } catch (_) {}
  }

  static bool verifyOtp(String email, String otp) {
    try {
      final raw = html.window.localStorage[_otpKey];
      if (raw == null) return false;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['email'] != email.trim().toLowerCase()) return false;
      if (data['otp'] != otp.trim()) return false;
      if (DateTime.now().isAfter(DateTime.parse(data['expiry']))) return false;
      html.window.localStorage.remove(_otpKey);
      return true;
    } catch (_) { return false; }
  }

  static void updateUser(String id, Map<String, dynamic> updates) {
    final users = loadUsers();
    final idx = users.indexWhere((u) => u['id'] == id);
    if (idx >= 0) {
      users[idx] = {...users[idx], ...updates};
      saveUsers(users);
      if (currentUser?['id'] == id) {
        html.window.localStorage[_sessionKey] = jsonEncode(users[idx]);
      }
    }
  }

  static void deleteUser(String id) {
    final users = loadUsers()..removeWhere((u) => u['id'] == id);
    saveUsers(users);
  }

  // ── Brevo API Key ─────────────────────────────────────────────
  static const _brevoKey = 'eprojex_brevo_key';

  static String loadBrevoKey() {
    try { return html.window.localStorage[_brevoKey] ?? ''; } catch (_) { return ''; }
  }

  static void saveBrevoKey(String key) {
    try { html.window.localStorage[_brevoKey] = key.trim(); } catch (_) {}
  }
}

// ══════════════════════════════════════════════════════════════
//  UYGULAMA
// ══════════════════════════════════════════════════════════════

class EProjexApp extends StatefulWidget {
  const EProjexApp({super.key});
  static _EProjexAppState? of(BuildContext context) => context.findAncestorStateOfType<_EProjexAppState>();
  @override State<EProjexApp> createState() => _EProjexAppState();
}

class _EProjexAppState extends State<EProjexApp> {
  bool _darkMode = false;

  @override
  void initState() {
    super.initState();
    _darkMode = StorageService.loadDarkMode();
  }

  void toggleDark() {
    setState(() => _darkMode = !_darkMode);
    StorageService.saveDarkMode(_darkMode);
  }

  bool get isDark => _darkMode;

  ThemeData _buildTheme(Brightness brightness) => ThemeData(
    useMaterial3: true,
    fontFamily: 'Segoe UI',
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: brightness),
    scaffoldBackgroundColor: brightness == Brightness.dark ? const Color(0xFF0F172A) : AppColors.bg,
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: brightness == Brightness.dark ? const Color(0xFF1E293B) : AppColors.border)),
      color: brightness == Brightness.dark ? const Color(0xFF1E293B) : AppColors.surface,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary, foregroundColor: Colors.white,
        elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: brightness == Brightness.dark ? const Color(0xFF1E293B) : AppColors.surfaceAlt,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: brightness == Brightness.dark ? const Color(0xFF334155) : AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: brightness == Brightness.dark ? const Color(0xFF334155) : AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'e-Projex',
    debugShowCheckedModeBanner: false,
    theme: _buildTheme(Brightness.light),
    darkTheme: _buildTheme(Brightness.dark),
    themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
    home: const LoginPage(),
  );
}

// ══════════════════════════════════════════════════════════════
//  LOGIN SAYFASI
// ══════════════════════════════════════════════════════════════

// ── E-posta Servisi (Brevo) ────────────────────────────────────
// Brevo ücretsiz: https://app.brevo.com → API Keys → Create API key
// Admin Paneli > Sistem > Brevo API Key alanına yapıştırın.
// Ayarlanmadıysa OTP ekranda gösterilir.

Future<bool> sendOtpEmail({required String toEmail, required String toName, required String otp}) async {
  final apiKey = StorageService.loadBrevoKey();
  if (apiKey.isEmpty) return false;
  try {
    final body = jsonEncode({
      'sender': {'name': 'e-Projex', 'email': 'noreply@eprojex.app'},
      'to': [{'email': toEmail, 'name': toName.isEmpty ? toEmail : toName}],
      'subject': 'e-Projex Doğrulama Kodunuz',
      'htmlContent': '''
        <div style="font-family:Arial,sans-serif;max-width:500px;margin:auto;padding:32px;background:#f8faff;border-radius:12px">
          <h2 style="color:#1E40AF;margin-bottom:8px">e-Projex</h2>
          <p style="color:#475569">Merhaba <b>$toName</b>,</p>
          <p style="color:#475569">Hesabınızı doğrulamak için aşağıdaki kodu kullanın:</p>
          <div style="background:#1E40AF;color:white;font-size:36px;font-weight:900;letter-spacing:12px;text-align:center;padding:24px;border-radius:8px;margin:24px 0">
            $otp
          </div>
          <p style="color:#94A3B8;font-size:13px">Bu kod 10 dakika geçerlidir. Eğer bu işlemi siz yapmadıysanız dikkate almayın.</p>
        </div>
      ''',
    });
    final req = await html.HttpRequest.request(
      'https://api.brevo.com/v3/smtp/email',
      method: 'POST',
      requestHeaders: {'Content-Type': 'application/json', 'api-key': apiKey},
      sendData: body,
    );
    return req.status == 201;
  } catch (_) {
    return false;
  }
}

String _generateOtp() {
  final rng = math.Random();
  return List.generate(6, (_) => rng.nextInt(10)).join();
}

// ─────────────────────────────────────────────────────────────
//  LOGIN SAYFASI
// ─────────────────────────────────────────────────────────────

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override State<LoginPage> createState() => _LoginPageState();
}

enum _AuthMode { login, register, verify }

class _LoginPageState extends State<LoginPage> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _otpCtrl   = TextEditingController();
  bool _obscure = true, _loading = false;
  _AuthMode _mode = _AuthMode.login;
  String _pendingEmail = '';

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose();
    _passCtrl.dispose(); _otpCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.danger : AppColors.success,
    ));
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    final ok = StorageService.login(_emailCtrl.text, _passCtrl.text);
    setState(() => _loading = false);
    if (ok) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainShellPage()));
    } else {
      // İlk kez: hiç kullanıcı yoksa admin kayıt ekranına yönlendir
      final users = StorageService.loadUsers();
      if (users.isEmpty) {
        _snack('Henüz kayıt yok. Lütfen hesap oluşturun.', error: true);
        setState(() => _mode = _AuthMode.register);
      } else {
        _snack('E-posta veya şifre hatalı ya da hesap doğrulanmamış.', error: true);
      }
    }
  }

  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    final ok = StorageService.registerUser(
      name: _nameCtrl.text,
      email: _emailCtrl.text,
      password: _passCtrl.text,
    );
    if (!ok) {
      setState(() => _loading = false);
      _snack('Bu e-posta adresi zaten kayıtlı!', error: true);
      return;
    }
    final otp = _generateOtp();
    StorageService.saveOtp(_emailCtrl.text, otp);
    _pendingEmail = _emailCtrl.text.trim().toLowerCase();

    // E-posta gönder
    final sent = await sendOtpEmail(
      toEmail: _pendingEmail,
      toName: _nameCtrl.text.trim(),
      otp: otp,
    );
    if (!mounted) return;
    setState(() { _loading = false; _mode = _AuthMode.verify; });
    if (sent) {
      _snack('Doğrulama kodu $_pendingEmail adresine gönderildi.');
    } else {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('E-posta Gönderilemedi'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Brevo API anahtarı ayarlanmamış. Doğrulama kodunuzu aşağıdan kopyalayın ve doğrulama ekranına girin:'),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(color: const Color(0xFF1E40AF), borderRadius: BorderRadius.circular(8)),
              child: SelectableText(otp,
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 10),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            const Text('Bu kod 10 dakika geçerlidir.', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tamam, Anladım')),
          ],
        ),
      );
    }
  }

  Future<void> _verify() async {
    if (_otpCtrl.text.trim().length != 6) {
      _snack('6 haneli kodu girin', error: true); return;
    }
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 300));
    final ok = StorageService.verifyOtp(_pendingEmail, _otpCtrl.text.trim());
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      StorageService.verifyUser(_pendingEmail);
      _snack('Hesabınız doğrulandı! Giriş yapabilirsiniz.');
      setState(() { _mode = _AuthMode.login; _emailCtrl.text = _pendingEmail; });
    } else {
      _snack('Kod hatalı veya süresi dolmuş.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF0F2057), Color(0xFF1E40AF), Color(0xFF0369A1)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 40, offset: const Offset(0, 20))]),
                child: isWide
                    ? Row(children: [_buildLeftPanel(), Expanded(child: _buildForm())])
                    : Column(children: [_buildTopBanner(), _buildForm()]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeftPanel() => Container(
    width: 380,
    padding: const EdgeInsets.all(48),
    decoration: const BoxDecoration(
      gradient: LinearGradient(colors: [Color(0xFF1E3A8A), Color(0xFF1D4ED8)],
        begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.only(topLeft: Radius.circular(24), bottomLeft: Radius.circular(24)),
    ),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 56, height: 56,
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.business_center_rounded, color: Colors.white, size: 30)),
      const SizedBox(height: 32),
      const Text('e-Projex', style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1)),
      const SizedBox(height: 16),
      const Text('Projelerinizi, personellerinizi\nve finanslarınızı tek ekranda\nyönetin.',
          style: TextStyle(fontSize: 17, height: 1.7, color: Colors.white70)),
      const SizedBox(height: 48),
      _fr(Icons.folder_special_rounded, 'Proje & Bölüm Takibi'),
      const SizedBox(height: 16),
      _fr(Icons.people_rounded, 'Personel & Maaş Yönetimi'),
      const SizedBox(height: 16),
      _fr(Icons.bar_chart_rounded, 'Gelir / Gider Analizi'),
    ]),
  );

  Widget _fr(IconData icon, String text) => Row(children: [
    Icon(icon, color: Colors.white54, size: 20), const SizedBox(width: 12),
    Text(text, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w500)),
  ]);

  Widget _buildTopBanner() => Container(
    width: double.infinity, padding: const EdgeInsets.all(32),
    decoration: const BoxDecoration(
      gradient: LinearGradient(colors: [Color(0xFF1E3A8A), Color(0xFF1D4ED8)]),
      borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
    ),
    child: const Column(children: [
      Icon(Icons.business_center_rounded, color: Colors.white, size: 48),
      SizedBox(height: 12),
      Text('e-Projex', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
    ]),
  );

  Widget _buildForm() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Form(
        key: _formKey,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (_mode == _AuthMode.login) ..._loginFields(),
          if (_mode == _AuthMode.register) ..._registerFields(),
          if (_mode == _AuthMode.verify) ..._verifyFields(),
        ]),
      ),
    );
  }

  List<Widget> _loginFields() => [
    const Text('Hoş Geldiniz', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textDark)),
    const SizedBox(height: 8),
    const Text('Devam etmek için giriş yapın', style: TextStyle(color: AppColors.textMid)),
    const SizedBox(height: 32),
    TextFormField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress,
      decoration: const InputDecoration(labelText: 'E-posta', prefixIcon: Icon(Icons.email_outlined)),
      validator: (v) => (v == null || !v.contains('@')) ? 'Geçerli bir e-posta girin' : null),
    const SizedBox(height: 16),
    TextFormField(controller: _passCtrl, obscureText: _obscure,
      decoration: InputDecoration(labelText: 'Şifre', prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(onPressed: () => setState(() => _obscure = !_obscure),
          icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined))),
      validator: (v) => (v == null || v.length < 6) ? 'En az 6 karakter' : null),
    const SizedBox(height: 24),
    SizedBox(height: 52, child: ElevatedButton(
      onPressed: _loading ? null : _login,
      child: _loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Text('Giriş Yap', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)))),
    const SizedBox(height: 16),
    TextButton(onPressed: () => setState(() { _mode = _AuthMode.register; _formKey.currentState?.reset(); }),
      child: const Text('Hesabınız yok mu? Kayıt olun')),
  ];

  List<Widget> _registerFields() => [
    const Text('Hesap Oluştur', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textDark)),
    const SizedBox(height: 8),
    const Text('Bilgilerinizi girerek kayıt olun', style: TextStyle(color: AppColors.textMid)),
    const SizedBox(height: 32),
    TextFormField(controller: _nameCtrl,
      decoration: const InputDecoration(labelText: 'Ad Soyad', prefixIcon: Icon(Icons.person_outline)),
      validator: (v) => (v == null || v.trim().isEmpty) ? 'Ad soyad gerekli' : null),
    const SizedBox(height: 16),
    TextFormField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress,
      decoration: const InputDecoration(labelText: 'E-posta', prefixIcon: Icon(Icons.email_outlined)),
      validator: (v) => (v == null || !v.contains('@')) ? 'Geçerli bir e-posta girin' : null),
    const SizedBox(height: 16),
    TextFormField(controller: _passCtrl, obscureText: _obscure,
      decoration: InputDecoration(labelText: 'Şifre (min. 6 karakter)', prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(onPressed: () => setState(() => _obscure = !_obscure),
          icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined))),
      validator: (v) => (v == null || v.length < 6) ? 'En az 6 karakter' : null),
    const SizedBox(height: 24),
    SizedBox(height: 52, child: ElevatedButton(
      onPressed: _loading ? null : _register,
      child: _loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Text('Kayıt Ol & Kod Gönder', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)))),
    const SizedBox(height: 16),
    TextButton(onPressed: () => setState(() => _mode = _AuthMode.login),
      child: const Text('Zaten hesabınız var mı? Giriş yapın')),
  ];

  List<Widget> _verifyFields() => [
    const Icon(Icons.mark_email_read_outlined, size: 56, color: AppColors.primary),
    const SizedBox(height: 20),
    const Text('E-postanızı Doğrulayın', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textDark)),
    const SizedBox(height: 8),
    Text('$_pendingEmail adresine 6 haneli doğrulama kodu gönderdik.',
        style: const TextStyle(color: AppColors.textMid), textAlign: TextAlign.center),
    const SizedBox(height: 32),
    TextFormField(controller: _otpCtrl, keyboardType: TextInputType.number,
      textAlign: TextAlign.center, maxLength: 6,
      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 12),
      decoration: const InputDecoration(labelText: 'Doğrulama Kodu', counterText: '',
        prefixIcon: Icon(Icons.pin_outlined))),
    const SizedBox(height: 24),
    SizedBox(height: 52, child: ElevatedButton(
      onPressed: _loading ? null : _verify,
      child: _loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Text('Doğrula', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)))),
    const SizedBox(height: 16),
    TextButton(onPressed: () async {
      final otp = _generateOtp();
      StorageService.saveOtp(_pendingEmail, otp);
      final sent = await sendOtpEmail(toEmail: _pendingEmail, toName: '', otp: otp);
      if (!mounted) return;
      if (sent) {
        _snack('Yeni kod gönderildi.');
      } else {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('E-posta Gönderilemedi'),
            content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Brevo API anahtarı ayarlanmamış. Doğrulama kodunuzu aşağıdan kopyalayın:'),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                decoration: BoxDecoration(color: const Color(0xFF1E40AF), borderRadius: BorderRadius.circular(8)),
                child: SelectableText(otp,
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 10),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              const Text('Bu kod 10 dakika geçerlidir.', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tamam')),
            ],
          ),
        );
      }
    }, child: const Text('Kodu tekrar gönder')),
    const SizedBox(height: 8),
    TextButton(onPressed: () => setState(() => _mode = _AuthMode.login),
      child: const Text('Geri dön')),
  ];
}

// ══════════════════════════════════════════════════════════════
//  ANA KABUK
// ══════════════════════════════════════════════════════════════

class MainShellPage extends StatefulWidget {
  const MainShellPage({super.key});
  @override State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  int _idx = 0;
  List<ProjectData> projects = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final data = await StorageService.load();
    if (mounted) setState(() { projects = data; _loading = false; });
  }

  Future<void> _save() => StorageService.save(projects);

  static const _navItems = [
    (Icons.dashboard_rounded, Icons.dashboard_outlined, 'Ana Sayfa'),
    (Icons.folder_rounded, Icons.folder_outlined, 'Projeler'),
    (Icons.account_balance_rounded, Icons.account_balance_outlined, 'Çek & Senet'),
    (Icons.receipt_long_rounded, Icons.receipt_long_outlined, 'E-Fatura'),
    (Icons.bar_chart_rounded, Icons.bar_chart_outlined, 'Raporlar'),
    (Icons.settings_rounded, Icons.settings_outlined, 'Ayarlar'),
    (Icons.admin_panel_settings_rounded, Icons.admin_panel_settings_outlined, 'Yönetici'),
  ];
  // Mobil için kısa etiketler
  static const _mobileNavItems = [
    (Icons.dashboard_rounded, Icons.dashboard_outlined, 'Anasayfa'),
    (Icons.folder_rounded, Icons.folder_outlined, 'Projeler'),
    (Icons.account_balance_rounded, Icons.account_balance_outlined, 'Çekler'),
    (Icons.receipt_long_rounded, Icons.receipt_long_outlined, 'Fatura'),
    (Icons.bar_chart_rounded, Icons.bar_chart_outlined, 'Raporlar'),
    (Icons.settings_rounded, Icons.settings_outlined, 'Ayarlar'),
    (Icons.admin_panel_settings_rounded, Icons.admin_panel_settings_outlined, 'Admin'),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      appBar: isWide ? null : AppBar(
        title: Text(_navItems[_idx < _navItems.length ? _idx : 0].$3, style: const TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.surfaceOf(context),
        elevation: 0,
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(height: 1, color: AppColors.borderOf(context))),
      ),
      drawer: isWide ? null : Drawer(child: _SideNav(idx: _idx, onTap: (i) { setState(() => _idx = i); Navigator.pop(context); }, projects: projects)),
      bottomNavigationBar: isWide ? null : NavigationBar(
        selectedIndex: _idx < _mobileNavItems.length ? _idx : 0,
        onDestinationSelected: (i) => setState(() => _idx = i),
        backgroundColor: AppColors.surfaceOf(context),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: _mobileNavItems.map((n) => NavigationDestination(
          icon: Icon(n.$2), selectedIcon: Icon(n.$1), label: n.$3)).toList(),
      ),
      body: Row(
        children: [
          if (isWide) _SideNav(idx: _idx, onTap: (i) => setState(() => _idx = i), projects: projects),
          Expanded(child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_idx) {
      case 0: return _DashboardPage(projects: projects);
      case 1: return _ProjectsPage(projects: projects, onChanged: () async { await _save(); setState(() {}); });
      case 2: return _ChecksPage(projects: projects);
      case 3: return _InvoicesPage(projects: projects);
      case 4: return _ReportsPage(projects: projects);
      case 5: return _SettingsPage(onChanged: () => setState(() {}));
      case 6: return _AdminPanelPage(onChanged: () => setState(() {}));
      default: return const SizedBox();
    }
  }
}

// ══════════════════════════════════════════════════════════════
//  YAN MENÜ
// ══════════════════════════════════════════════════════════════

class _SideNav extends StatelessWidget {
  final int idx;
  final ValueChanged<int> onTap;
  final List<ProjectData> projects;
  const _SideNav({required this.idx, required this.onTap, required this.projects});

  @override
  Widget build(BuildContext context) {
    final surf = AppColors.surfaceOf(context);
    final bord = AppColors.borderOf(context);
    final txtD = AppColors.textDarkOf(context);
    final txtL = AppColors.textLightOf(context);
    final user = StorageService.currentUser;
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: surf,
        border: Border(right: BorderSide(color: bord)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
                  borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.business_center_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('e-Projex', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: txtD)),
                Text('v1.0', style: TextStyle(fontSize: 11, color: txtL)),
              ]),
            ]),
          ),
          Divider(height: 1, color: bord),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(children: [
              _NavTile(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard_rounded, label: 'Ana Sayfa', selected: idx == 0, onTap: () => onTap(0)),
              _NavTile(icon: Icons.folder_outlined, activeIcon: Icons.folder_rounded, label: 'Projeler', selected: idx == 1, badge: projects.length.toString(), onTap: () => onTap(1)),
              Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1, color: bord)),
              _NavTile(icon: Icons.account_balance_outlined, activeIcon: Icons.account_balance_rounded, label: 'Çek & Senet', selected: idx == 2, onTap: () => onTap(2)),
              _NavTile(icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long_rounded, label: 'E-Fatura', selected: idx == 3, onTap: () => onTap(3)),
              Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1, color: bord)),
              _NavTile(icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart_rounded, label: 'Raporlar', selected: idx == 4, onTap: () => onTap(4)),
              _NavTile(icon: Icons.settings_outlined, activeIcon: Icons.settings_rounded, label: 'Ayarlar', selected: idx == 5, onTap: () => onTap(5)),
              if (user != null && user['role'] == 'admin') ...[
                Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1, color: bord)),
                _NavTile(icon: Icons.admin_panel_settings_outlined, activeIcon: Icons.admin_panel_settings_rounded, label: 'Yönetici', selected: idx == 6, onTap: () => onTap(6)),
              ],
            ]),
          ),
          const Spacer(),
          Divider(height: 1, color: bord),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              CircleAvatar(backgroundColor: AppColors.primaryLight, radius: 18, child: const Icon(Icons.person, color: Colors.white, size: 18)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(user?['name'] ?? 'Kullanıcı', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: txtD)),
                Text(user?['email'] ?? '', style: TextStyle(fontSize: 11, color: txtL), overflow: TextOverflow.ellipsis),
              ])),
              GestureDetector(
                onTap: () {
                  StorageService.logout();
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
                },
                child: Icon(Icons.logout_rounded, size: 18, color: txtL),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final bool selected;
  final String? badge;
  final VoidCallback onTap;
  const _NavTile({required this.icon, required this.activeIcon, required this.label, required this.selected, required this.onTap, this.badge});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(selected ? activeIcon : icon, color: selected ? AppColors.primary : AppColors.textMid, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.primary : AppColors.textDark, fontSize: 14))),
          if (badge != null && badge != '0')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
              child: Text(badge!, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
        ]),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
//  ANA SAYFA (DASHBOARD)
// ══════════════════════════════════════════════════════════════

class _DashboardPage extends StatelessWidget {
  final List<ProjectData> projects;
  const _DashboardPage({required this.projects});

  // 7 gün içinde vadesi dolacak çekler
  List<CheckRecord> _getYaklasanCekler() {
    final checks = StorageService.loadChecks();
    final now = DateTime.now();
    final limit = now.add(const Duration(days: 7));
    return checks.where((c) => c.isPending && c.dueDate.isAfter(now) && c.dueDate.isBefore(limit)).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  // Son eklenen projeler (en son 5)
  List<ProjectData> get _sonProjeler {
    final sorted = [...projects]..sort((a, b) => b.startDate.compareTo(a.startDate));
    return sorted.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final totalIncome = projects.fold<double>(0, (s, p) => s + p.totalIncome());
    final totalExpense = projects.fold<double>(0, (s, p) => s + p.totalExpense());
    final totalBalance = totalIncome - totalExpense;
    final activeProjects = projects.where((p) => p.status == 'active').length;
    final yaklasanCekler = _getYaklasanCekler();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // BAŞLIK
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Genel Bakış', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.textDark)),
            Text(formatDate(now), style: const TextStyle(color: AppColors.textMid, fontSize: 13)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Row(children: [
              const Icon(Icons.circle, size: 8, color: AppColors.success),
              const SizedBox(width: 6),
              Text('$activeProjects Aktif Proje', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 12)),
            ]),
          ),
        ]),
        const SizedBox(height: 24),

        // KPI KARTLAR
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth > 700 ? 4 : 2;
          return GridView.count(
            crossAxisCount: cols, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.4,
            children: [
              _KpiCard(label: 'Toplam Gelir', value: '${formatMoney(totalIncome)} ₺', icon: Icons.trending_up_rounded, color: AppColors.success),
              _KpiCard(label: 'Toplam Gider', value: '${formatMoney(totalExpense)} ₺', icon: Icons.trending_down_rounded, color: AppColors.danger),
              _KpiCard(label: 'Net Bakiye', value: '${formatMoney(totalBalance)} ₺', icon: Icons.account_balance_wallet_rounded,
                color: totalBalance >= 0 ? AppColors.primary : AppColors.danger),
              _KpiCard(label: 'Proje Sayısı', value: '${projects.length}', icon: Icons.folder_rounded, color: AppColors.warning),
            ],
          );
        }),
        const SizedBox(height: 24),

        // VADESİ YAKLAŞAN ÇEKLER (7 GÜN)
        if (yaklasanCekler.isNotEmpty) ...[
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(8)),
              child: Text('${yaklasanCekler.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
            ),
            const SizedBox(width: 10),
            const Text('7 Gün İçinde Vadesi Dolan Çekler', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.danger)),
          ]),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.danger.withOpacity(0.03),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.danger.withOpacity(0.2))),
            child: Column(children: yaklasanCekler.asMap().entries.map((entry) {
              final c = entry.value;
              final kalanGun = c.dueDate.difference(now).inDays;
              final isLast = entry.key == yaklasanCekler.length - 1;
              return Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(children: [
                    Container(width: 40, height: 40,
                      decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.account_balance_rounded, color: AppColors.danger, size: 20)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(c.recipient.isNotEmpty ? c.recipient : c.drawer,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      Text('${c.bank.isNotEmpty ? c.bank : "Banka yok"} • No: ${c.no.isNotEmpty ? c.no : "—"}',
                        style: const TextStyle(color: AppColors.textMid, fontSize: 12)),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('${formatMoney(c.amount)} ₺',
                        style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.danger, fontSize: 15)),
                      Text(kalanGun == 0 ? 'Bugün!' : '$kalanGun gün kaldı',
                        style: TextStyle(color: kalanGun == 0 ? AppColors.danger : AppColors.warning,
                          fontWeight: FontWeight.w700, fontSize: 11)),
                    ]),
                  ]),
                ),
                if (!isLast) const Divider(height: 1, indent: 68, color: AppColors.border),
              ]);
            }).toList()),
          ),
          const SizedBox(height: 24),
        ],

        // GELİR/GİDER GRAFİĞİ
        if (projects.isNotEmpty) ...[
          const Text('Proje Gelir / Gider', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
            child: Column(children: [
              _BarChart(projects: projects),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _LegendDot(color: AppColors.success, label: 'Gelir'),
                const SizedBox(width: 16),
                _LegendDot(color: AppColors.danger, label: 'Gider'),
                const SizedBox(width: 16),
                _LegendDot(color: AppColors.primary, label: 'Bakiye'),
              ]),
            ]),
          ),
          const SizedBox(height: 24),
        ],

        // SON EKLENEN PROJELER
        if (projects.isNotEmpty) ...[
          const Text('Son Projeler', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          const SizedBox(height: 12),
          ..._sonProjeler.map((p) => _ProjectSummaryCard(project: p)),
        ] else
          _EmptyState(icon: Icons.folder_open_rounded, title: 'Henüz proje yok', subtitle: 'Projeler sekmesinden ilk projenizi oluşturun.'),

        const SizedBox(height: 20),
      ]),
    );
  }
}

class _BarChart extends StatelessWidget {
  final List<ProjectData> projects;
  const _BarChart({required this.projects});

  @override
  Widget build(BuildContext context) {
    if (projects.isEmpty) return const SizedBox();
    final maxVal = projects.fold<double>(0, (m, p) => math.max(m, math.max(p.totalIncome(), p.totalExpense())));
    if (maxVal == 0) return const Center(child: Text('Henüz veri yok', style: TextStyle(color: AppColors.textLight)));

    return SizedBox(
      height: 200,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: projects.map((p) {
          final incomeH = maxVal > 0 ? (p.totalIncome() / maxVal) * 160 : 0.0;
          final expenseH = maxVal > 0 ? (p.totalExpense() / maxVal) * 160 : 0.0;
          final balanceH = maxVal > 0 ? (p.balance().abs() / maxVal) * 160 : 0.0;
          final name = p.name.length > 8 ? '${p.name.substring(0, 8)}…' : p.name;
          return Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.center, children: [
                _Bar(height: incomeH, color: AppColors.success, tooltip: 'Gelir: ${formatMoney(p.totalIncome())} ₺'),
                const SizedBox(width: 3),
                _Bar(height: expenseH, color: AppColors.danger, tooltip: 'Gider: ${formatMoney(p.totalExpense())} ₺'),
                const SizedBox(width: 3),
                _Bar(height: balanceH, color: p.balance() >= 0 ? AppColors.primary : AppColors.warning, tooltip: 'Bakiye: ${formatMoney(p.balance())} ₺'),
              ]),
              const SizedBox(height: 8),
              Text(name, style: const TextStyle(fontSize: 10, color: AppColors.textMid), textAlign: TextAlign.center, maxLines: 1),
            ]),
          ));
        }).toList(),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final double height;
  final Color color;
  final String tooltip;
  const _Bar({required this.height, required this.color, required this.tooltip});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      width: 14,
      height: height.clamp(4, 160),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
    ),
  );
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
    const SizedBox(width: 6),
    Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMid, fontWeight: FontWeight.w600)),
  ]);
}

class _KpiCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _KpiCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 16),
        ),
        const Spacer(),
      ]),
      const SizedBox(height: 8),
      Text(label, style: const TextStyle(color: AppColors.textMid, fontSize: 11, fontWeight: FontWeight.w600)),
      const SizedBox(height: 2),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textDark)),
      ),
    ]),
  );
}

class _ProjectSummaryCard extends StatelessWidget {
  final ProjectData project;
  const _ProjectSummaryCard({required this.project});

  @override
  Widget build(BuildContext context) {
    final balance = project.balance();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Column(children: [
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.folder_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(project.name, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark)),
            const SizedBox(height: 4),
            Text('${project.employees.length} personel • ${project.sections.length} bölüm',
                style: const TextStyle(color: AppColors.textMid, fontSize: 12)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${formatMoney(balance)} ₺',
                style: TextStyle(fontWeight: FontWeight.w800, color: balance >= 0 ? AppColors.success : AppColors.danger)),
            const SizedBox(height: 4),
            _StatusBadge(status: project.status),
          ]),
        ]),
        const SizedBox(height: 10),
        const Divider(height: 1, color: AppColors.border),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton.icon(
            onPressed: () => exportProjectPdf(context, project),
            icon: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.danger, size: 16),
            label: const Text('PDF Oluştur', style: TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w700)),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          ),
        ]),
      ]),
    );
  }
}

class _EmployeeSummaryCard extends StatelessWidget {
  final EmployeeData employee;
  final String projectName;
  const _EmployeeSummaryCard({required this.employee, required this.projectName});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: employee.hasExited ? AppColors.exitedBg : AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: employee.hasExited ? AppColors.exitedText.withOpacity(0.2) : AppColors.border),
    ),
    child: Column(children: [
      Row(children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: employee.hasExited ? AppColors.exitedText.withOpacity(0.1) : AppColors.primary.withOpacity(0.1),
          child: Text(employee.name.isNotEmpty ? employee.name[0].toUpperCase() : '?',
            style: TextStyle(color: employee.hasExited ? AppColors.exitedText : AppColors.primary, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(employee.name, style: TextStyle(fontWeight: FontWeight.w700, color: employee.hasExited ? AppColors.exitedText : AppColors.textDark)),
          Text('$projectName • ${employee.role}', style: const TextStyle(color: AppColors.textMid, fontSize: 12)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${formatMoney(employee.totalPaid())} ₺', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          Text('${employee.paidMonthCount()} ay ödendi', style: const TextStyle(color: AppColors.textLight, fontSize: 11)),
        ]),
      ]),
      const SizedBox(height: 8),
      const Divider(height: 1, color: AppColors.border),
      const SizedBox(height: 6),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        TextButton.icon(
          onPressed: () => exportEmployeePdf(context, employee, projectName),
          icon: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.danger, size: 16),
          label: const Text('PDF Oluştur', style: TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w700)),
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
        ),
      ]),
    ]),
  );
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});
  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'active' => ('Aktif', AppColors.success),
      'completed' => ('Tamamlandı', AppColors.primary),
      'paused' => ('Beklemede', AppColors.warning),
      _ => ('Belirsiz', AppColors.textLight),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  PROJELER SAYFASI
// ══════════════════════════════════════════════════════════════

class _ProjectsPage extends StatefulWidget {
  final List<ProjectData> projects;
  final VoidCallback onChanged;
  const _ProjectsPage({required this.projects, required this.onChanged});
  @override State<_ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<_ProjectsPage> {
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _addProject() async {
    final result = await _showProjectDialog(context);
    if (result != null) { widget.projects.add(result); widget.onChanged(); }
  }

  Future<void> _editProject(ProjectData p) async {
    final result = await _showProjectDialog(context, existing: p);
    if (result != null) {
      p.name = result.name; p.description = result.description;
      p.client = result.client; p.location = result.location;
      p.startDate = result.startDate; p.endDate = result.endDate;
      p.status = result.status;
      widget.onChanged();
    }
  }

  Future<void> _deleteProject(ProjectData p) async {
    final ok = await _confirm(context, 'Projeyi Sil', '${p.name} projesini silmek istiyor musunuz?\nTüm veriler silinecek!');
    if (ok) { widget.projects.remove(p); widget.onChanged(); }
  }

  void _copyProject(ProjectData p) {
    final copy = ProjectData(
      name: '${p.name} (Kopya)',
      description: p.description,
      startDate: DateTime.now(),
      endDate: DateTime.now().add(p.endDate.difference(p.startDate)),
      status: 'active',
      budget: p.budget,
      kdvRate: p.kdvRate,
    );
    widget.projects.add(copy);
    widget.onChanged();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"${p.name}" kopyalandı'), backgroundColor: AppColors.success));
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.projects.where((p) =>
      p.name.toLowerCase().contains(_search.toLowerCase()) ||
      p.description.toLowerCase().contains(_search.toLowerCase())).toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
          child: Row(children: [
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Projeler', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.textDark)),
              Text('Tüm projelerinizi buradan yönetin', style: TextStyle(color: AppColors.textMid)),
            ])),
            ElevatedButton.icon(onPressed: _addProject, icon: const Icon(Icons.add), label: const Text('Yeni Proje')),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Proje ara...',
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textLight),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.close_rounded, size: 18), onPressed: () { _searchCtrl.clear(); setState(() => _search = ''); })
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: widget.projects.isEmpty
              ? _EmptyState(icon: Icons.folder_open_rounded, title: 'Henüz proje yok', subtitle: 'İlk projenizi oluşturmak için butona tıklayın.',
                  action: ElevatedButton.icon(onPressed: _addProject, icon: const Icon(Icons.add), label: const Text('Proje Oluştur')))
              : filtered.isEmpty
                  ? _EmptyState(icon: Icons.search_off_rounded, title: 'Sonuç bulunamadı', subtitle: '"$_search" araması için proje yok.')
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final p = filtered[i];
                        return _ProjectCard(project: p,
                          onTap: () async {
                            await Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectDashboardPage(project: p)));
                            widget.onChanged();
                          },
                          onEdit: () => _editProject(p),
                          onDelete: () => _deleteProject(p),
                          onCopy: () => _copyProject(p),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final ProjectData project;
  final VoidCallback onTap, onEdit, onDelete, onCopy;
  const _ProjectCard({required this.project, required this.onTap, required this.onEdit, required this.onDelete, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    final balance = project.balance();
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
          child: Column(children: [
            Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.primary, AppColors.accent]), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.folder_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(project.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                if (project.description.isNotEmpty) Text(project.description, style: const TextStyle(color: AppColors.textMid, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
              _StatusBadge(status: project.status),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                onSelected: (v) { if (v == 'edit') onEdit(); else if (v == 'copy') onCopy(); else onDelete(); },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Düzenle')])),
                  PopupMenuItem(value: 'copy', child: Row(children: [Icon(Icons.copy_outlined, size: 18, color: AppColors.primary), SizedBox(width: 8), Text('Kopyala', style: TextStyle(color: AppColors.primary))])),
                  PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: AppColors.danger), SizedBox(width: 8), Text('Sil', style: TextStyle(color: AppColors.danger))])),
                ],
              ),
            ]),
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 16),
            Row(children: [
              _MiniStat(label: 'Gelir', value: '${formatMoney(project.totalIncome())} ₺', color: AppColors.success),
              const SizedBox(width: 12),
              _MiniStat(label: 'Gider', value: '${formatMoney(project.totalExpense())} ₺', color: AppColors.danger),
              const SizedBox(width: 12),
              _MiniStat(label: 'Bakiye', value: '${formatMoney(balance)} ₺', color: balance >= 0 ? AppColors.primary : AppColors.danger),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.calendar_today_outlined, size: 13, color: AppColors.textLight),
              const SizedBox(width: 4),
              Text('${formatDate(project.startDate)} – ${formatDate(project.endDate)}',
                  style: const TextStyle(color: AppColors.textLight, fontSize: 12)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Icon(Icons.people_outlined, size: 14, color: AppColors.textLight),
              const SizedBox(width: 4),
              Text('${project.employees.length} personel', style: const TextStyle(color: AppColors.textMid, fontSize: 12)),
              const SizedBox(width: 16),
              Icon(Icons.layers_outlined, size: 14, color: AppColors.textLight),
              const SizedBox(width: 4),
              Text('${project.sections.length} bölüm', style: const TextStyle(color: AppColors.textMid, fontSize: 12)),
              const SizedBox(width: 16),
              Icon(Icons.receipt_outlined, size: 14, color: AppColors.textLight),
              const SizedBox(width: 4),
              Text('${project.incomeEntries.length} gelir kaydı', style: const TextStyle(color: AppColors.textMid, fontSize: 12)),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(color: AppColors.textLight, fontSize: 11)),
    Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
  ]);
}

// ══════════════════════════════════════════════════════════════
//  PROJE DASHBOARD
// ══════════════════════════════════════════════════════════════

class ProjectDashboardPage extends StatefulWidget {
  final ProjectData project;
  const ProjectDashboardPage({super.key, required this.project});
  @override State<ProjectDashboardPage> createState() => _ProjectDashboardPageState();
}

class _ProjectDashboardPageState extends State<ProjectDashboardPage> with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() { super.initState(); _tab = TabController(length: 5, vsync: this); }
  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _save() => StorageService.save([widget.project]);

  @override
  Widget build(BuildContext context) {
    final p = widget.project;
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      appBar: AppBar(
        backgroundColor: AppColors.surfaceOf(context),
        elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.name, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textDarkOf(context))),
          Text('${formatDate(p.startDate)} – ${formatDate(p.endDate)}', style: TextStyle(fontSize: 12, color: AppColors.textMidOf(context))),
        ]),
        actions: [
          TextButton.icon(
            onPressed: () => exportProjectPdf(context, widget.project),
            icon: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.danger, size: 18),
            label: const Text('PDF Oluştur', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tab,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMid,
          indicatorColor: AppColors.primary,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [Tab(text: 'Özet'), Tab(text: 'Gelir & Gider'), Tab(text: 'Personel'), Tab(text: 'Taşeron'), Tab(text: 'Malzeme')],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _ProjectSummaryTab(project: p),
          _SectionsIncomeTab(project: p, onChanged: () async { await _save(); setState(() {}); }),
          _EmployeesTab(project: p, onChanged: () async { await _save(); setState(() {}); }),
          _SubcontractorsTab(project: p, onChanged: () async { await _save(); setState(() {}); }),
          _ProjectMalzemelerTab(project: p, onChanged: () async { await _save(); setState(() {}); }),
        ],
      ),
    );
  }
}

// ─── ÖZET TAB ────────────────────────────────────────────────

class _ProjectSummaryTab extends StatelessWidget {
  final ProjectData project;
  const _ProjectSummaryTab({required this.project});

  @override
  Widget build(BuildContext context) {
    final balance = project.balance();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth > 600 ? 3 : 1;
          return GridView.count(
            crossAxisCount: cols, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: cols == 3 ? 2.2 : 3,
            children: [
              _KpiCard(label: 'Toplam Gelir', value: '${formatMoney(project.totalIncome())} ₺', icon: Icons.trending_up_rounded, color: AppColors.success),
              _KpiCard(label: 'Toplam Gider', value: '${formatMoney(project.totalExpense())} ₺', icon: Icons.trending_down_rounded, color: AppColors.danger),
              _KpiCard(label: 'Net Bakiye', value: '${formatMoney(balance)} ₺', icon: Icons.account_balance_wallet_rounded,
                  color: balance >= 0 ? AppColors.primary : AppColors.danger),
            ],
          );
        }),
        const SizedBox(height: 24),
        _InfoCard(title: 'Proje Bilgileri', children: [
          _InfoRow2(label: 'Proje Adı', value: project.name),
          if (project.description.isNotEmpty) _InfoRow2(label: 'Açıklama', value: project.description),
          if (project.client.isNotEmpty) _InfoRow2(label: 'Müşteri / İşveren', value: project.client),
          if (project.location.isNotEmpty) _InfoRow2(label: 'İş Yeri / Şantiye', value: project.location),
          _InfoRow2(label: 'İşin Başlama Tarihi', value: formatDate(project.startDate)),
          _InfoRow2(label: 'İşin Bitiş Tarihi', value: formatDate(project.endDate)),
          _InfoRow2(label: 'Durum', value: _statusLabel(project.status)),
          _InfoRow2(label: 'Personel', value: '${project.employees.length} kişi'),
          _InfoRow2(label: 'Bölüm', value: '${project.sections.length} adet'),
          if (project.budget > 0) _InfoRow2(label: 'Bütçe Hedefi', value: '${formatMoney(project.budget)} ₺'),
          if (project.kdvRate > 0) _InfoRow2(label: 'KDV Oranı', value: '%${project.kdvRate.toStringAsFixed(0)}'),
        ]),
        if (project.budget > 0) ...[const SizedBox(height: 16), _BudgetCard(project: project)],
        if (project.kdvRate > 0) ...[const SizedBox(height: 16), _KdvCard(project: project)],
        const SizedBox(height: 20),
        if (project.employees.isNotEmpty) ...[
          _InfoCard(title: 'Personel Ödeme Özeti', children: [
            ...project.employees.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                CircleAvatar(radius: 16, backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Text(e.name[0], style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 13))),
                const SizedBox(width: 10),
                Expanded(child: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                Text('${formatMoney(e.totalPaid())} ₺', style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
            )),
          ]),
        ],
      ]),
    );
  }

  String _statusLabel(String s) => switch (s) { 'active' => 'Aktif', 'completed' => 'Tamamlandı', 'paused' => 'Beklemede', _ => s };
}

// ─── BÖLÜMLER & GELİR TAB ────────────────────────────────────

class _SectionsIncomeTab extends StatefulWidget {
  final ProjectData project;
  final VoidCallback onChanged;
  const _SectionsIncomeTab({required this.project, required this.onChanged});
  @override State<_SectionsIncomeTab> createState() => _SectionsIncomeTabState();
}

class _SectionsIncomeTabState extends State<_SectionsIncomeTab> {
  ProjectData get p => widget.project;

  // ── GELİR ──
  Future<void> _addIncome() async {
    final result = await _showIncomeDialog(context);
    if (result != null) { setState(() => p.incomeEntries.add(result)); widget.onChanged(); }
  }

  Future<void> _editIncome(int i) async {
    final result = await _showIncomeDialog(context, existing: p.incomeEntries[i]);
    if (result != null) { setState(() => p.incomeEntries[i] = result); widget.onChanged(); }
  }

  Future<void> _deleteIncome(int i) async {
    final ok = await _confirm(context, 'Geliri Sil', 'Bu gelir kaydını silmek istiyor musunuz?');
    if (ok) { setState(() => p.incomeEntries.removeAt(i)); widget.onChanged(); }
  }

  // ── BÖLÜM ──
  Future<void> _addSection() async {
    final result = await _showSectionDialog(context);
    if (result != null) { setState(() => p.sections.add(result)); widget.onChanged(); }
  }

  Future<void> _editSection(AppSection s) async {
    final result = await _showSectionDialog(context, existing: s);
    if (result != null) { setState(() { s.title = result.title; s.companyTitle = result.companyTitle; s.note = result.note; s.createdDate = result.createdDate; }); widget.onChanged(); }
  }

  Future<void> _deleteSection(AppSection s) async {
    final ok = await _confirm(context, 'Bölümü Sil', '${s.title} bölümünü silmek istiyor musunuz?');
    if (ok) { setState(() => p.sections.remove(s)); widget.onChanged(); }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // GELİRLER
      _SectionHeader(title: 'Gelir Kayıtları', badge: '${p.incomeEntries.length}', onAdd: _addIncome, buttonLabel: '+ Gelir Ekle'),
      const SizedBox(height: 12),
      if (p.incomeEntries.isEmpty)
        _EmptyCard(text: 'Henüz gelir kaydı yok')
      else
        Container(
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
          child: Column(children: [
            ...p.incomeEntries.asMap().entries.map((e) => _IncomeRow(
              entry: e.value, index: e.key,
              onEdit: () => _editIncome(e.key), onDelete: () => _deleteIncome(e.key),
              last: e.key == p.incomeEntries.length - 1,
            )),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF0FDF4),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(14), bottomRight: Radius.circular(14)),
              ),
              child: Row(children: [
                const Text('Toplam Gelir', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.success)),
                const Spacer(),
                Text('${formatMoney(p.totalIncome())} ₺', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.success, fontSize: 16)),
              ]),
            ),
          ]),
        ),
      const SizedBox(height: 28),
      // BÖLÜMLER
      _SectionHeader(title: 'Gider Kategorileri', badge: '${p.sections.length}', onAdd: _addSection, buttonLabel: '+ Gider Ekle'),
      const SizedBox(height: 12),
      if (p.sections.isEmpty)
        _EmptyCard(text: 'Henüz bölüm eklenmedi')
      else
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: p.sections.length,
          onReorder: (o, n) async {
            setState(() { if (n > o) n--; p.sections.insert(n, p.sections.removeAt(o)); });
            widget.onChanged();
          },
          itemBuilder: (context, i) {
            final s = p.sections[i];
            return Container(
              key: ValueKey('${s.title}-$i'),
              margin: const EdgeInsets.only(bottom: 12),
              child: _SectionCard(section: s,
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => SectionDetailPage(project: p, section: s)));
                  setState(() {}); widget.onChanged();
                },
                onEdit: () => _editSection(s),
                onDelete: () => _deleteSection(s),
                index: i,
              ),
            );
          },
        ),
    ]),
  );
}

class _SectionHeader extends StatelessWidget {
  final String title, badge, buttonLabel;
  final VoidCallback onAdd;
  const _SectionHeader({required this.title, required this.badge, required this.onAdd, required this.buttonLabel});
  @override
  Widget build(BuildContext context) => Row(children: [
    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
    const SizedBox(width: 8),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(badge, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12)),
    ),
    const Spacer(),
    ElevatedButton.icon(onPressed: onAdd, icon: const Icon(Icons.add, size: 16), label: Text(buttonLabel)),
  ]);
}

class _IncomeRow extends StatelessWidget {
  final IncomeEntry entry;
  final int index;
  final VoidCallback onEdit, onDelete;
  final bool last;
  const _IncomeRow({required this.entry, required this.index, required this.onEdit, required this.onDelete, required this.last});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_downward_rounded, color: AppColors.success, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(entry.from.isNotEmpty ? entry.from : entry.title,
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark)),
            if (entry.from.isNotEmpty && entry.title.isNotEmpty && entry.title != entry.from)
              Text(entry.title, style: const TextStyle(color: AppColors.textMid, fontSize: 12)),
            Text(formatDate(entry.date), style: const TextStyle(color: AppColors.textLight, fontSize: 12)),
          ])),
          Text('${formatMoney(entry.amount)} ₺', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.success)),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            onSelected: (v) { if (v == 'edit') onEdit(); else onDelete(); },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Düzenle')),
              PopupMenuItem(value: 'delete', child: Text('Sil', style: TextStyle(color: AppColors.danger))),
            ],
          ),
        ]),
      ),
      if (!last) const Divider(height: 1, indent: 64, color: AppColors.border),
    ],
  );
}

class _SectionCard extends StatelessWidget {
  final AppSection section;
  final VoidCallback onTap, onEdit, onDelete;
  final int index;
  const _SectionCard({required this.section, required this.onTap, required this.onEdit, required this.onDelete, required this.index});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        ReorderableDragStartListener(index: index, child: const Icon(Icons.drag_indicator, color: AppColors.textLight)),
        const SizedBox(width: 12),
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.layers_rounded, color: AppColors.warning, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(section.title, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark)),
          Text('${section.companyTitle.isEmpty ? '—' : section.companyTitle} • ${formatDate(section.createdDate)}',
              style: const TextStyle(color: AppColors.textMid, fontSize: 12)),
          Text('${section.entries.length} kayıt', style: const TextStyle(color: AppColors.textLight, fontSize: 12)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${formatMoney(section.total)} ₺', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textDark)),
          const Icon(Icons.chevron_right, color: AppColors.textLight, size: 18),
        ]),
        PopupMenuButton<String>(
          onSelected: (v) { if (v == 'edit') onEdit(); else onDelete(); },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Düzenle')),
            PopupMenuItem(value: 'delete', child: Text('Sil', style: TextStyle(color: AppColors.danger))),
          ],
        ),
      ]),
    ),
  );
}

// ─── PERSONELLER TAB ─────────────────────────────────────────

class _EmployeesTab extends StatefulWidget {
  final ProjectData project;
  final VoidCallback onChanged;
  const _EmployeesTab({required this.project, required this.onChanged});
  @override State<_EmployeesTab> createState() => _EmployeesTabState();
}

class _EmployeesTabState extends State<_EmployeesTab> {
  ProjectData get p => widget.project;
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _add() async {
    final result = await Navigator.push<EmployeeData>(
      context,
      MaterialPageRoute(builder: (_) => const EmployeeFormPage()),
    );
    if (result != null) { setState(() => p.employees.add(result)); widget.onChanged(); }
  }

  Future<void> _edit(int i) async {
    final result = await Navigator.push<EmployeeData>(
      context,
      MaterialPageRoute(builder: (_) => EmployeeFormPage(existing: p.employees[i])),
    );
    if (result != null) {
      final e = p.employees[i];
      e.name = result.name; e.role = result.role; e.phone = result.phone;
      e.startDate = result.startDate; e.endDate = result.endDate;
      e.salary = result.salary; e.sgk = result.sgk;
      e.advance = result.advance; e.minimumWage = result.minimumWage;
      e.syncUnpaidMonthlyValues();
      setState(() {}); widget.onChanged();
    }
  }

  Future<void> _delete(int i) async {
    final ok = await _confirm(context, 'Personeli Sil', '${p.employees[i].name} isimli personeli silmek istiyor musunuz?');
    if (ok) { setState(() => p.employees.removeAt(i)); widget.onChanged(); }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = p.employees.where((e) =>
      e.name.toLowerCase().contains(_search.toLowerCase()) ||
      e.role.toLowerCase().contains(_search.toLowerCase()) ||
      e.phone.contains(_search)).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Row(children: [
            Text('${p.employees.length} Personel', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
            const Spacer(),
            ElevatedButton.icon(onPressed: _add, icon: const Icon(Icons.person_add_rounded, size: 16), label: const Text('+ Personel')),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'İsim, görev veya telefon ara...',
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textLight),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.close_rounded, size: 18), onPressed: () { _searchCtrl.clear(); setState(() => _search = ''); })
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: p.employees.isEmpty
              ? _EmptyState(icon: Icons.people_outline, title: 'Personel yok', subtitle: 'Projeye personel ekleyin.')
              : filtered.isEmpty
                  ? _EmptyState(icon: Icons.search_off_rounded, title: 'Sonuç bulunamadı', subtitle: '"$_search" araması için personel yok.')
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final e = filtered[i];
                        final realIdx = p.employees.indexOf(e);
                        return _EmployeeCard(employee: e,
                          onTap: () async {
                            await Navigator.push(context, MaterialPageRoute(
                              builder: (_) => EmployeeDetailPage(project: p, employee: e)));
                            setState(() {}); widget.onChanged();
                          },
                          onEdit: () => _edit(realIdx),
                          onDelete: () => _delete(realIdx),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  final EmployeeData employee;
  final VoidCallback onTap, onEdit, onDelete;
  const _EmployeeCard({required this.employee, required this.onTap, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final e = employee;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: e.hasExited ? AppColors.exitedBg : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: e.hasExited ? AppColors.exitedText.withOpacity(0.3) : AppColors.border),
          ),
          child: Row(children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: e.hasExited ? AppColors.exitedText.withOpacity(0.1) : AppColors.primary.withOpacity(0.1),
              child: Text(e.name.isNotEmpty ? e.name[0].toUpperCase() : '?',
                style: TextStyle(color: e.hasExited ? AppColors.exitedText : AppColors.primary, fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(e.name, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15,
                  color: e.hasExited ? AppColors.exitedText : AppColors.textDark)),
                if (e.hasExited) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.exitedText.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                    child: const Text('Çıktı', style: TextStyle(color: AppColors.exitedText, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ],
              ]),
              const SizedBox(height: 4),
              Text('${e.role} • ${e.phone}', style: const TextStyle(color: AppColors.textMid, fontSize: 12)),
              Text('Giriş: ${formatDate(e.startDate)}${e.endDate != null ? ' • Çıkış: ${formatDate(e.endDate!)}' : ''}',
                  style: const TextStyle(color: AppColors.textLight, fontSize: 12)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${formatMoney(e.totalPaid())} ₺', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              Text('${e.paidMonthCount()} ay', style: const TextStyle(color: AppColors.textLight, fontSize: 12)),
            ]),
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              onSelected: (v) { if (v == 'edit') onEdit(); else onDelete(); },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                PopupMenuItem(value: 'delete', child: Text('Sil', style: TextStyle(color: AppColors.danger))),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  PERSONEL DETAY SAYFASI
// ══════════════════════════════════════════════════════════════

// ══════════════════════════════════════════════════════════════
//  TAŞERONLAR TAB
// ══════════════════════════════════════════════════════════════

class _SubcontractorsTab extends StatefulWidget {
  final ProjectData project;
  final VoidCallback onChanged;
  const _SubcontractorsTab({required this.project, required this.onChanged});
  @override State<_SubcontractorsTab> createState() => _SubcontractorsTabState();
}

class _SubcontractorsTabState extends State<_SubcontractorsTab> {
  ProjectData get p => widget.project;

  Future<void> _add() async {
    final result = await Navigator.push<Subcontractor>(
      context, MaterialPageRoute(builder: (_) => SubcontractorDetailPage(project: p)));
    if (result != null) { setState(() => p.subcontractors.add(result)); widget.onChanged(); }
  }

  Future<void> _open(Subcontractor sub) async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => SubcontractorDetailPage(project: p, existing: sub)));
    setState(() {}); widget.onChanged();
  }

  Future<void> _delete(Subcontractor sub) async {
    final ok = await _confirm(context, 'Taşeronu Sil', '${sub.name} silinsin mi?');
    if (ok) { setState(() => p.subcontractors.remove(sub)); widget.onChanged(); }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Taşeronlar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
            Text('${p.subcontractors.length} taşeron firma', style: const TextStyle(color: AppColors.textMid, fontSize: 12)),
          ]),
          const Spacer(),
          ElevatedButton.icon(onPressed: _add, icon: const Icon(Icons.add, size: 16), label: const Text('+ Taşeron Ekle')),
        ]),
      ),
      // Özet
      if (p.subcontractors.isNotEmpty) ...[
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(children: [
            Expanded(child: _subStatCard('Toplam Sözleşme',
              '${formatMoney(p.subcontractors.fold(0.0, (s, c) => s + c.totalContractAmount))} ₺', AppColors.primary)),
            const SizedBox(width: 10),
            Expanded(child: _subStatCard('Toplam Ödenen',
              '${formatMoney(p.subcontractors.fold(0.0, (s, c) => s + c.totalPaid))} ₺', AppColors.success)),
            const SizedBox(width: 10),
            Expanded(child: _subStatCard('Kalan Borç',
              '${formatMoney(p.subcontractors.fold(0.0, (s, c) => s + (c.remaining > 0 ? c.remaining : 0)))} ₺', AppColors.warning)),
          ]),
        ),
      ],
      const SizedBox(height: 16),
      Expanded(
        child: p.subcontractors.isEmpty
            ? _EmptyState(icon: Icons.handyman_outlined, title: 'Taşeron yok', subtitle: 'Projeye taşeron firma ekleyin.')
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                itemCount: p.subcontractors.length,
                itemBuilder: (context, i) {
                  final sub = p.subcontractors[i];
                  final pct = sub.progressPercent;
                  final color = pct >= 100 ? AppColors.success : pct > 50 ? AppColors.warning : AppColors.primary;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () => _open(sub),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                        child: Column(children: [
                          Row(children: [
                            CircleAvatar(
                              radius: 24, backgroundColor: AppColors.primary.withOpacity(0.1),
                              child: Text(sub.name.isNotEmpty ? sub.name[0].toUpperCase() : '?',
                                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 18)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(sub.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textDark)),
                              if (sub.contact.isNotEmpty || sub.phone.isNotEmpty)
                                Text('${sub.contact}${sub.contact.isNotEmpty && sub.phone.isNotEmpty ? ' • ' : ''}${sub.phone}',
                                  style: const TextStyle(color: AppColors.textMid, fontSize: 12)),
                              Text('${sub.works.length} iş kalemi • ${sub.payments.length} ödeme',
                                style: const TextStyle(color: AppColors.textLight, fontSize: 11)),
                            ])),
                            PopupMenuButton<String>(
                              onSelected: (v) { if (v == 'open') _open(sub); else _delete(sub); },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'open', child: Text('Aç / Düzenle')),
                                PopupMenuItem(value: 'delete', child: Text('Sil', style: TextStyle(color: AppColors.danger))),
                              ],
                            ),
                          ]),
                          const SizedBox(height: 14),
                          const Divider(height: 1, color: AppColors.border),
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(child: _MiniStat(label: 'Sözleşme', value: '${formatMoney(sub.totalContractAmount)} ₺', color: AppColors.primary)),
                            Expanded(child: _MiniStat(label: 'Ödenen', value: '${formatMoney(sub.totalPaid)} ₺', color: AppColors.success)),
                            Expanded(child: _MiniStat(label: 'Kalan', value: '${formatMoney(sub.remaining > 0 ? sub.remaining : 0)} ₺', color: sub.isFullyPaid ? AppColors.success : AppColors.warning)),
                          ]),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(value: pct / 100, backgroundColor: AppColors.border,
                                valueColor: AlwaysStoppedAnimation<Color>(color), minHeight: 8),
                            )),
                            const SizedBox(width: 10),
                            Text('%${pct.toStringAsFixed(0)}', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
                          ]),
                        ]),
                      ),
                    ),
                  );
                },
              ),
      ),
    ],
  );

  Widget _subStatCard(String label, String value, Color color) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14)),
    ]),
  );
}

// ── TAŞERON DETAY / FORM SAYFASI ────────────────────────────

class SubcontractorDetailPage extends StatefulWidget {
  final ProjectData project;
  final Subcontractor? existing;
  const SubcontractorDetailPage({super.key, required this.project, this.existing});
  @override State<SubcontractorDetailPage> createState() => _SubcontractorDetailPageState();
}

class _SubcontractorDetailPageState extends State<SubcontractorDetailPage> {
  late Subcontractor _sub;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _contactCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _taxCtrl;
  late final TextEditingController _noteCtrl;

  @override
  void initState() {
    super.initState();
    _sub = widget.existing ?? Subcontractor(id: DateTime.now().millisecondsSinceEpoch.toString(), name: '');
    _nameCtrl = TextEditingController(text: _sub.name);
    _contactCtrl = TextEditingController(text: _sub.contact);
    _phoneCtrl = TextEditingController(text: _sub.phone);
    _taxCtrl = TextEditingController(text: _sub.taxNo);
    _noteCtrl = TextEditingController(text: _sub.note);
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _contactCtrl, _phoneCtrl, _taxCtrl, _noteCtrl]) c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    _sub.name = _nameCtrl.text.trim();
    _sub.contact = _contactCtrl.text.trim();
    _sub.phone = _phoneCtrl.text.trim();
    _sub.taxNo = _taxCtrl.text.trim();
    _sub.note = _noteCtrl.text.trim();
    await StorageService.save([widget.project]);
  }

  Future<void> _addWork() async {
    final descCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController();
    String unit = 'm2';
    const units = ['m2', 'm3', 'metre', 'adet', 'ton', 'kg', 'litre', 'saat', 'gün'];

    final result = await showDialog<SubcontractorWork>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('İş Kalemi Ekle'),
          content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: descCtrl, decoration: const InputDecoration(
              labelText: 'İş Tanımı *', hintText: 'Kalıp işçiliği, beton dökümü...',
              prefixIcon: Icon(Icons.construction_rounded))),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: qtyCtrl, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Miktar *'))),
              const SizedBox(width: 10),
              Expanded(child: DropdownButtonFormField<String>(
                value: unit,
                decoration: const InputDecoration(labelText: 'Birim'),
                items: units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                onChanged: (v) => ss(() => unit = v!),
              )),
            ]),
            const SizedBox(height: 12),
            TextField(controller: priceCtrl, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Birim Fiyat (₺) *',
                prefixIcon: Icon(Icons.attach_money_rounded))),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
            ElevatedButton(onPressed: () {
              if (descCtrl.text.trim().isEmpty) return;
              final qty = double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? 1;
              final price = parseTrMoney(priceCtrl.text);
              Navigator.pop(ctx, SubcontractorWork(
                description: descCtrl.text.trim(), unit: unit, quantity: qty, unitPrice: price));
            }, child: const Text('Ekle')),
          ],
        ),
      ),
    );
    descCtrl.dispose(); qtyCtrl.dispose(); priceCtrl.dispose();
    if (result != null) { setState(() => _sub.works.add(result)); await _save(); }
  }

  Future<void> _addPayment() async {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    DateTime date = DateTime.now();
    String type = 'advance';
    String payMethod = 'cash';
    String workItem = '';

    final result = await showDialog<SubcontractorPayment>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('Ödeme Ekle'),
          content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Özet
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(10)),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Sözleşme Tutarı:', style: TextStyle(color: AppColors.textMid, fontSize: 12)),
                  Text('${formatMoney(_sub.totalContractAmount)} ₺', style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 4),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Toplam Ödenen:', style: TextStyle(color: AppColors.success, fontSize: 12)),
                  Text('${formatMoney(_sub.totalPaid)} ₺', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 4),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Kalan:', style: TextStyle(color: AppColors.warning, fontSize: 12, fontWeight: FontWeight.w600)),
                  Text('${formatMoney(_sub.remaining)} ₺', style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.w800)),
                ]),
              ]),
            ),
            const SizedBox(height: 14),
            // Ödeme tipi
            DropdownButtonFormField<String>(
              value: type,
              decoration: const InputDecoration(labelText: 'Ödeme Tipi'),
              items: const [
                DropdownMenuItem(value: 'advance', child: Text('Avans')),
                DropdownMenuItem(value: 'progress', child: Text('Hakediş')),
                DropdownMenuItem(value: 'final', child: Text('Kesin Hakediş')),
              ],
              onChanged: (v) => ss(() => type = v!),
            ),
            const SizedBox(height: 12),
            // Ödeme yöntemi - Nakit / Çek
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => ss(() => payMethod = 'cash'),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: payMethod == 'cash' ? AppColors.success.withOpacity(0.1) : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: payMethod == 'cash' ? AppColors.success : AppColors.border)),
                  child: Column(children: [
                    Icon(Icons.payments_rounded, color: payMethod == 'cash' ? AppColors.success : AppColors.textMid, size: 20),
                    const SizedBox(height: 4),
                    Text('Nakit', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12,
                      color: payMethod == 'cash' ? AppColors.success : AppColors.textMid)),
                  ]),
                ),
              )),
              const SizedBox(width: 10),
              Expanded(child: GestureDetector(
                onTap: () => ss(() => payMethod = 'check'),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: payMethod == 'check' ? AppColors.primary.withOpacity(0.1) : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: payMethod == 'check' ? AppColors.primary : AppColors.border)),
                  child: Column(children: [
                    Icon(Icons.receipt_long_rounded, color: payMethod == 'check' ? AppColors.primary : AppColors.textMid, size: 20),
                    const SizedBox(height: 4),
                    Text('Çek', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12,
                      color: payMethod == 'check' ? AppColors.primary : AppColors.textMid)),
                  ]),
                ),
              )),
            ]),
            const SizedBox(height: 12),
            // İş kalemi
            TextField(
              onChanged: (v) => workItem = v,
              decoration: const InputDecoration(
                labelText: 'İş Kalemi (isteğe bağlı)',
                prefixIcon: Icon(Icons.work_outline_rounded)),
            ),
            const SizedBox(height: 12),
            TextField(controller: amountCtrl, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Tutar (₺) *',
                prefixIcon: Icon(Icons.attach_money_rounded))),
            const SizedBox(height: 12),
            _DateField(label: 'Tarih', date: date, onPicked: (d) => ss(() => date = d)),
            const SizedBox(height: 12),
            TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Not / Çek No')),
          ]))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
            ElevatedButton(onPressed: () {
              final amount = parseTrMoney(amountCtrl.text);
              if (amount <= 0) return;
              Navigator.pop(ctx, SubcontractorPayment(
                type: type, amount: amount, date: date,
                payMethod: payMethod, workItem: workItem,
                note: noteCtrl.text.trim()));
            }, child: const Text('Kaydet')),
          ],
        ),
      ),
    );
    amountCtrl.dispose(); noteCtrl.dispose();
    if (result != null) { setState(() => _sub.payments.add(result)); await _save(); }
  }

  @override
  Widget build(BuildContext context) {
    final pct = _sub.progressPercent;
    final color = pct >= 100 ? AppColors.success : pct > 50 ? AppColors.warning : AppColors.primary;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface, elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_sub.name.isEmpty ? 'Yeni Taşeron' : _sub.name,
            style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textDark)),
          Text(widget.project.name, style: const TextStyle(fontSize: 12, color: AppColors.textMid)),
        ]),
        actions: [
          if (_sub.name.isNotEmpty)
            TextButton.icon(
              onPressed: () => exportTaseronPdf(context, _sub, widget.project.name),
              icon: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.danger, size: 18),
              label: const Text('PDF', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
            ),
          TextButton(
            onPressed: () async {
              if (_nameCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Firma adı zorunlu')));
                return;
              }
              await _save();
              if (mounted) Navigator.pop(context, _sub);
            },
            child: const Text('Kaydet', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── BİLGİLER ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
            child: Column(children: [
              TextField(controller: _nameCtrl, onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Firma Adı *', prefixIcon: Icon(Icons.business_rounded))),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: _contactCtrl,
                  decoration: const InputDecoration(labelText: 'Yetkili Kişi', prefixIcon: Icon(Icons.person_outline_rounded)))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Telefon', prefixIcon: Icon(Icons.phone_outlined)))),
              ]),
              const SizedBox(height: 12),
              TextField(controller: _taxCtrl,
                decoration: const InputDecoration(labelText: 'Vergi No', prefixIcon: Icon(Icons.numbers_rounded))),
              const SizedBox(height: 12),
              TextField(controller: _noteCtrl, maxLines: 2,
                decoration: const InputDecoration(labelText: 'Not')),
            ]),
          ),

          const SizedBox(height: 20),

          // ── ÖZET ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(children: [
              Row(children: [
                Expanded(child: _subStat('Sözleşme', '${formatMoney(_sub.totalContractAmount)} ₺', Colors.white)),
                Expanded(child: _subStat('Ödenen', '${formatMoney(_sub.totalPaid)} ₺', Colors.white)),
                Expanded(child: _subStat('Kalan', '${formatMoney(_sub.remaining > 0 ? _sub.remaining : 0)} ₺', Colors.white)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(value: pct / 100, backgroundColor: Colors.white30,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white), minHeight: 10),
                )),
                const SizedBox(width: 10),
                Text('%${pct.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
              ]),
            ]),
          ),

          const SizedBox(height: 20),

          // ── İŞ KALEMLERİ ──────────────────────────────────────
          Row(children: [
            const Expanded(child: Text('İş Kalemleri (Sözleşme)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark))),
            ElevatedButton.icon(onPressed: _addWork, icon: const Icon(Icons.add, size: 15), label: const Text('+ Ekle')),
          ]),
          const SizedBox(height: 10),
          if (_sub.works.isEmpty)
            _EmptyCard(text: 'İş kalemi eklenmedi')
          else
            Container(
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: const BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
                  child: const Row(children: [
                    Expanded(flex: 3, child: Text('İş Tanımı', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textMid))),
                    Expanded(flex: 1, child: Text('Miktar', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textMid), textAlign: TextAlign.center)),
                    Expanded(flex: 1, child: Text('B.Fiyat', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textMid), textAlign: TextAlign.right)),
                    Expanded(flex: 1, child: Text('Toplam', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textMid), textAlign: TextAlign.right)),
                    SizedBox(width: 32),
                  ]),
                ),
                ..._sub.works.asMap().entries.map((e) => Column(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(children: [
                      Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(e.value.description, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(e.value.unit, style: const TextStyle(color: AppColors.textLight, fontSize: 11)),
                      ])),
                      Expanded(flex: 1, child: Text('${e.value.quantity}', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMid))),
                      Expanded(flex: 1, child: Text('${formatMoney(e.value.unitPrice)} ₺', textAlign: TextAlign.right, style: const TextStyle(color: AppColors.textMid, fontSize: 12))),
                      Expanded(flex: 1, child: Text('${formatMoney(e.value.total)} ₺', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700))),
                      IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 16),
                        onPressed: () async { setState(() => _sub.works.removeAt(e.key)); await _save(); }),
                    ]),
                  ),
                  if (e.key < _sub.works.length - 1) const Divider(height: 1, indent: 14, color: AppColors.border),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: const BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.vertical(bottom: Radius.circular(14))),
                  child: Row(children: [
                    const Text('TOPLAM SÖZLEŞME', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
                    const Spacer(),
                    Text('${formatMoney(_sub.totalContractAmount)} ₺', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary, fontSize: 16)),
                  ]),
                ),
              ]),
            ),

          const SizedBox(height: 20),

          // ── ÖDEMELER ──────────────────────────────────────────
          Row(children: [
            const Expanded(child: Text('Ödemeler',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark))),
            ElevatedButton.icon(
              onPressed: _sub.works.isEmpty ? null : _addPayment,
              icon: const Icon(Icons.payments_rounded, size: 15),
              label: const Text('+ Ödeme Ekle'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            ),
          ]),
          const SizedBox(height: 10),
          if (_sub.payments.isEmpty)
            _EmptyCard(text: 'Henüz ödeme yapılmadı')
          else
            Container(
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
              child: Column(children: [
                ..._sub.payments.asMap().entries.map((e) {
                  final pay = e.value;
                  final typeColor = pay.type == 'advance' ? AppColors.warning : pay.type == 'progress' ? AppColors.primary : AppColors.success;
                  final methodColor = pay.payMethod == 'check' ? AppColors.primary : AppColors.success;
                  return Column(children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(color: typeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.payments_rounded, size: 18, color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(color: typeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                              child: Text(pay.typeLabel, style: TextStyle(color: typeColor, fontSize: 11, fontWeight: FontWeight.w700)),
                            ),
                            const SizedBox(width: 8),
                            Text(formatDate(pay.date), style: const TextStyle(color: AppColors.textLight, fontSize: 12)),
                          ]),
                          if (pay.note.isNotEmpty) Text(pay.note, style: const TextStyle(color: AppColors.textMid, fontSize: 12)),
                        ])),
                        Text('${formatMoney(pay.amount)} ₺', style: TextStyle(fontWeight: FontWeight.w800, color: typeColor, fontSize: 14)),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 16),
                          onPressed: () async { setState(() => _sub.payments.removeAt(e.key)); await _save(); },
                        ),
                      ]),
                    ),
                    if (e.key < _sub.payments.length - 1) const Divider(height: 1, indent: 14, color: AppColors.border),
                  ]);
                }),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: const BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.vertical(bottom: Radius.circular(14))),
                  child: Column(children: [
                    Row(children: [
                      const Text('Toplam Ödenen', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.success)),
                      const Spacer(),
                      Text('${formatMoney(_sub.totalPaid)} ₺', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.success, fontSize: 15)),
                    ]),
                    if (_sub.remaining > 0) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        const Text('Kalan Borç', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.warning)),
                        const Spacer(),
                        Text('${formatMoney(_sub.remaining)} ₺', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.warning, fontSize: 15)),
                      ]),
                    ],
                  ]),
                ),
              ]),
            ),

          const SizedBox(height: 80),
        ]),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (_nameCtrl.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Firma adı zorunlu')));
            return;
          }
          await _save();
          if (mounted) Navigator.pop(context, _sub);
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.save_rounded, color: Colors.white),
        label: const Text('Kaydet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _subStat(String label, String value, Color color) => Column(children: [
    Text(label, style: TextStyle(color: color.withOpacity(0.8), fontSize: 11)),
    const SizedBox(height: 4),
    Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13)),
  ]);
}

// ══════════════════════════════════════════════════════════════
//  PROJE MALZEMELERİ
// ══════════════════════════════════════════════════════════════

// ══════════════════════════════════════════════════════════════
//  PROJE MALZEMELERİ
// ══════════════════════════════════════════════════════════════

// ══════════════════════════════════════════════════════════════
//  PROJE MALZEMELERİ
// ══════════════════════════════════════════════════════════════

class MalzemeKalemi {
  String id, ad, birim, belgeNo;
  String odemeYontemi; // 'nakit', 'cek'
  double miktar, birimTutar;
  DateTime tarih;
  bool odendi;

  MalzemeKalemi({required this.id, required this.ad, required this.miktar,
    required this.birimTutar, required this.tarih,
    this.birim = 'adet', this.belgeNo = '', this.odendi = false,
    this.odemeYontemi = 'nakit'});

  static const double kdvOran = 20;
  double get kdvsizToplam => miktar * birimTutar;
  double get kdvTutar => kdvsizToplam * (kdvOran / 100);
  double get kdvliToplam => kdvsizToplam + kdvTutar;

  Map<String, dynamic> toJson() => {
    'id': id, 'ad': ad, 'miktar': miktar, 'birim': birim,
    'birimTutar': birimTutar, 'belgeNo': belgeNo,
    'tarih': tarih.toIso8601String(), 'odendi': odendi,
    'odemeYontemi': odemeYontemi,
  };
  factory MalzemeKalemi.fromJson(Map<String, dynamic> j) => MalzemeKalemi(
    id: j['id'] ?? '', ad: j['ad'] ?? '',
    miktar: (j['miktar'] as num).toDouble(),
    birimTutar: (j['birimTutar'] as num? ?? 0).toDouble(),
    birim: j['birim'] ?? 'adet', belgeNo: j['belgeNo'] ?? '',
    tarih: DateTime.parse(j['tarih']),
    odendi: j['odendi'] ?? false,
    odemeYontemi: j['odemeYontemi'] ?? 'nakit');
}

class ProjeMalzeme {
  String id, firmaAdi, firmaTel, not_;
  final List<MalzemeKalemi> kalemler;

  ProjeMalzeme({required this.id, required this.firmaAdi,
    this.firmaTel = '', this.not_ = '',
    List<MalzemeKalemi>? kalemler}) : kalemler = kalemler ?? [];

  double get toplamKdvsiz => kalemler.fold(0, (s, k) => s + k.kdvsizToplam);
  double get toplamKdv => kalemler.fold(0, (s, k) => s + k.kdvTutar);
  double get toplamKdvli => kalemler.fold(0, (s, k) => s + k.kdvliToplam);
  double get odenenToplam => kalemler.where((k) => k.odendi).fold(0, (s, k) => s + k.kdvliToplam);
  double get bekleyenToplam => kalemler.where((k) => !k.odendi).fold(0, (s, k) => s + k.kdvliToplam);

  Map<String, dynamic> toJson() => {
    'id': id, 'firmaAdi': firmaAdi, 'firmaTel': firmaTel, 'not_': not_,
    'kalemler': kalemler.map((k) => k.toJson()).toList(),
  };
  factory ProjeMalzeme.fromJson(Map<String, dynamic> j) => ProjeMalzeme(
    id: j['id'] ?? '', firmaAdi: j['firmaAdi'] ?? '',
    firmaTel: j['firmaTel'] ?? '', not_: j['not_'] ?? '',
    kalemler: (j['kalemler'] as List? ?? []).map((k) => MalzemeKalemi.fromJson(k)).toList());
}

class _ProjectMalzemelerTab extends StatefulWidget {
  final ProjectData project;
  final VoidCallback onChanged;
  const _ProjectMalzemelerTab({required this.project, required this.onChanged});
  @override State<_ProjectMalzemelerTab> createState() => _ProjectMalzemelerTabState();
}

class _ProjectMalzemelerTabState extends State<_ProjectMalzemelerTab> {
  ProjectData get p => widget.project;
  String _search = '';
  final _searchCtrl = TextEditingController();



  double get _genelKdvli => p.malzemeler.fold(0, (s, m) => s + m.toplamKdvli);
  double get _genelOdenen => p.malzemeler.fold(0, (s, m) => s + m.odenenToplam);
  double get _genelBekleyen => p.malzemeler.fold(0, (s, m) => s + m.bekleyenToplam);



  Future<void> _addFirma() async {
    final firmaCtrl = TextEditingController();
    final telCtrl = TextEditingController();
    final notCtrl = TextEditingController();

    final result = await showDialog<ProjeMalzeme>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Firma Ekle'),
        content: SizedBox(width: 380, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: firmaCtrl, autofocus: true,
            decoration: const InputDecoration(labelText: 'Firma / Tedarikçi Adı *',
              prefixIcon: Icon(Icons.store_outlined))),
          const SizedBox(height: 10),
          TextField(controller: telCtrl, keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Telefon',
              prefixIcon: Icon(Icons.phone_outlined))),
          const SizedBox(height: 10),
          TextField(controller: notCtrl,
            decoration: const InputDecoration(labelText: 'Not')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(onPressed: () {
            if (firmaCtrl.text.trim().isEmpty) return;
            Navigator.pop(ctx, ProjeMalzeme(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              firmaAdi: firmaCtrl.text.trim(),
              firmaTel: telCtrl.text.trim(),
              not_: notCtrl.text.trim(),
            ));
          }, child: const Text('Ekle')),
        ],
      ),
    );
    firmaCtrl.dispose(); telCtrl.dispose(); notCtrl.dispose();
    if (result != null) { setState(() => p.malzemeler.add(result)); widget.onChanged(); }
  }

  Future<void> _editFirma(ProjeMalzeme firma) async {
    final firmaCtrl = TextEditingController(text: firma.firmaAdi);
    final telCtrl = TextEditingController(text: firma.firmaTel);
    final notCtrl = TextEditingController(text: firma.not_);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Firmayı Düzenle'),
        content: SizedBox(width: 380, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: firmaCtrl, autofocus: true,
            decoration: const InputDecoration(labelText: 'Firma / Tedarikçi Adı *',
              prefixIcon: Icon(Icons.store_outlined))),
          const SizedBox(height: 10),
          TextField(controller: telCtrl, keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Telefon',
              prefixIcon: Icon(Icons.phone_outlined))),
          const SizedBox(height: 10),
          TextField(controller: notCtrl,
            decoration: const InputDecoration(labelText: 'Not')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(onPressed: () {
            if (firmaCtrl.text.trim().isEmpty) return;
            setState(() {
              firma.firmaAdi = firmaCtrl.text.trim();
              firma.firmaTel = telCtrl.text.trim();
              firma.not_ = notCtrl.text.trim();
            });
            widget.onChanged();
            Navigator.pop(ctx);
          }, child: const Text('Kaydet')),
        ],
      ),
    );
    firmaCtrl.dispose(); telCtrl.dispose(); notCtrl.dispose();
  }

  Future<void> _deleteFirma(ProjeMalzeme firma) async {
    final ok = await _confirm(context, 'Firmayı Sil', '"${firma.firmaAdi}" ve tüm kalemleri silinsin mi?');
    if (ok) { setState(() => p.malzemeler.remove(firma)); widget.onChanged(); }
  }

  void _openFirma(ProjeMalzeme firma) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _FirmaDetailPage(firma: firma, onChanged: () { setState(() {}); widget.onChanged(); })
    ));
  }

  @override
  @override
  Widget build(BuildContext context) => Column(children: [
    // Genel özet
    if (p.malzemeler.isNotEmpty)
      Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
          borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          Row(children: [
            const Expanded(child: Text('Toplam Malzeme Gideri',
              style: TextStyle(color: Colors.white70, fontSize: 12))),
            Text('${formatMoney(_genelKdvli)} ₺',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
          ]),
          const SizedBox(height: 10),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _tot('Ödenen', '${formatMoney(_genelOdenen)} ₺', const Color(0xFF86EFAC))),
            Container(width: 1, height: 24, color: Colors.white30),
            Expanded(child: _tot('Bekleyen', '${formatMoney(_genelBekleyen)} ₺', const Color(0xFFFCA5A5))),
            Container(width: 1, height: 24, color: Colors.white30),
            Expanded(child: _tot('Firma', '${p.malzemeler.length} adet', Colors.white)),
          ]),
        ]),
      ),
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(children: [
        Text('${p.malzemeler.length} Firma', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textMid, fontSize: 13)),
        const Spacer(),
        ElevatedButton.icon(onPressed: _addFirma, icon: const Icon(Icons.add, size: 15), label: const Text('+ Firma Ekle')),
      ]),
    ),
    Expanded(
      child: p.malzemeler.isEmpty
        ? const _EmptyState(icon: Icons.store_outlined,
            title: 'Firma yok', subtitle: 'Önce firma ekleyin, sonra malzeme girin.')
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            itemCount: p.malzemeler.length,
            itemBuilder: (context, fi) {
              final firma = p.malzemeler[fi];
              final tumOdendi = firma.kalemler.isNotEmpty && firma.kalemler.every((k) => k.odendi);
              return InkWell(
                onTap: () => _openFirma(firma),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: tumOdendi ? AppColors.success.withOpacity(0.03) : AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: tumOdendi ? AppColors.success.withOpacity(0.3) : AppColors.border)),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 22, backgroundColor: AppColors.primary.withOpacity(0.1),
                      child: Text(firma.firmaAdi.isNotEmpty ? firma.firmaAdi[0].toUpperCase() : '?',
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 18))),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(firma.firmaAdi, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        if (tumOdendi) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                            child: const Text('Ödendi', style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.w700))),
                        ],
                      ]),
                      if (firma.firmaTel.isNotEmpty)
                        Text(firma.firmaTel, style: const TextStyle(color: AppColors.textMid, fontSize: 12)),
                      Text('${firma.kalemler.length} kalem',
                        style: const TextStyle(color: AppColors.textLight, fontSize: 11)),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('${formatMoney(firma.toplamKdvli)} ₺',
                        style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary, fontSize: 15)),
                      Text('KDV Dahil', style: const TextStyle(color: AppColors.textLight, fontSize: 10)),
                      if (firma.bekleyenToplam > 0)
                        Text('Bekleyen: ${formatMoney(firma.bekleyenToplam)} ₺',
                          style: const TextStyle(color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.w600)),
                    ]),
                    PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'edit') _editFirma(firma);
                        else if (v == 'delete') _deleteFirma(firma);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Row(children: [
                          Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                          SizedBox(width: 8), Text('Düzenle')])),
                        PopupMenuItem(value: 'delete', child: Row(children: [
                          Icon(Icons.delete_outline, size: 16, color: AppColors.danger),
                          SizedBox(width: 8), Text('Sil', style: TextStyle(color: AppColors.danger))])),
                      ],
                    ),
                  ]),
                ),
              );
            }),
    ),
    ]);

  Widget _tot(String label, String value, Color color) => Column(children: [
    Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12), overflow: TextOverflow.ellipsis),
    Text(label, style: TextStyle(color: color.withOpacity(0.7), fontSize: 10)),
  ]);
}

// FİRMA DETAY SAYFASI
class _FirmaDetailPage extends StatefulWidget {
  final ProjeMalzeme firma;
  final VoidCallback onChanged;
  const _FirmaDetailPage({required this.firma, required this.onChanged});
  @override State<_FirmaDetailPage> createState() => _FirmaDetailPageState();
}

class _FirmaDetailPageState extends State<_FirmaDetailPage> {
  ProjeMalzeme get firma => widget.firma;
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override void dispose() { _searchCtrl.dispose(); super.dispose(); }

  List<MalzemeKalemi> get _filtered => firma.kalemler.where((k) =>
    _search.isEmpty || k.ad.toLowerCase().contains(_search.toLowerCase()) ||
    k.belgeNo.toLowerCase().contains(_search.toLowerCase())).toList();

  Future<void> _addKalem() async {
    final adCtrl = TextEditingController();
    final belgeCtrl = TextEditingController();
    final miktarCtrl = TextEditingController();
    final fiyatCtrl = TextEditingController();
    String birim = 'adet';
    String odemeYontemi = 'nakit';
    DateTime tarih = DateTime.now();
    const birimler = ['adet', 'kg', 'ton', 'litre', 'm2', 'm3', 'metre', 'kutu', 'paket', 'torba'];

    final result = await showDialog<MalzemeKalemi>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) {
        final miktar = double.tryParse(miktarCtrl.text.replaceAll(',', '.')) ?? 0;
        final fiyat = parseTrMoney(fiyatCtrl.text);
        final kdvsiz = miktar * fiyat;
        final kdvT = kdvsiz * (MalzemeKalemi.kdvOran / 100);
        final kdvli = kdvsiz + kdvT;
        return AlertDialog(
          title: Text('${firma.firmaAdi} — Malzeme Ekle'),
          content: SizedBox(width: 440, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: belgeCtrl,
              decoration: const InputDecoration(labelText: 'Belge / Fatura No',
                prefixIcon: Icon(Icons.receipt_outlined))),
            const SizedBox(height: 10),
            _DateField(label: 'Tarih', date: tarih, onPicked: (d) => ss(() => tarih = d)),
            const SizedBox(height: 10),
            TextField(controller: adCtrl, autofocus: true,
              decoration: const InputDecoration(labelText: 'Malzeme Adı *',
                prefixIcon: Icon(Icons.inventory_2_outlined))),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(
                controller: miktarCtrl, keyboardType: TextInputType.number,
                onChanged: (_) => ss(() {}),
                decoration: const InputDecoration(labelText: 'Miktar *'))),
              const SizedBox(width: 10),
              Expanded(child: DropdownButtonFormField<String>(
                value: birim,
                decoration: const InputDecoration(labelText: 'Birim'),
                items: birimler.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                onChanged: (v) => ss(() => birim = v!),
              )),
            ]),
            const SizedBox(height: 10),
            TextField(
              controller: fiyatCtrl, keyboardType: TextInputType.number,
              onChanged: (_) => ss(() {}),
              decoration: const InputDecoration(
                labelText: 'Birim Tutar (₺) *',
                prefixIcon: Icon(Icons.attach_money_rounded))),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => ss(() => odemeYontemi = 'nakit'),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: odemeYontemi == 'nakit' ? AppColors.success.withOpacity(0.1) : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: odemeYontemi == 'nakit' ? AppColors.success : AppColors.border)),
                  child: Column(children: [
                    Icon(Icons.payments_rounded, color: odemeYontemi == 'nakit' ? AppColors.success : AppColors.textMid, size: 18),
                    const SizedBox(height: 4),
                    Text('Nakit', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12,
                      color: odemeYontemi == 'nakit' ? AppColors.success : AppColors.textMid)),
                  ]),
                ),
              )),
              const SizedBox(width: 10),
              Expanded(child: GestureDetector(
                onTap: () => ss(() => odemeYontemi = 'cek'),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: odemeYontemi == 'cek' ? AppColors.primary.withOpacity(0.1) : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: odemeYontemi == 'cek' ? AppColors.primary : AppColors.border)),
                  child: Column(children: [
                    Icon(Icons.receipt_long_rounded, color: odemeYontemi == 'cek' ? AppColors.primary : AppColors.textMid, size: 18),
                    const SizedBox(height: 4),
                    Text('Çek', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12,
                      color: odemeYontemi == 'cek' ? AppColors.primary : AppColors.textMid)),
                  ]),
                ),
              )),
            ]),
            if (miktar > 0 && fiyat > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2))),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('KDV Hariç:', style: TextStyle(color: AppColors.textMid, fontSize: 12)),
                    Text('${formatMoney(kdvsiz)} ₺', style: const TextStyle(fontSize: 12)),
                  ]),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('KDV (%20):', style: TextStyle(color: AppColors.accent, fontSize: 12)),
                    Text('${formatMoney(kdvT)} ₺', style: const TextStyle(color: AppColors.accent, fontSize: 12)),
                  ]),
                  const Divider(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('KDV Dahil:', style: TextStyle(fontWeight: FontWeight.w700)),
                    Text('${formatMoney(kdvli)} ₺',
                      style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary, fontSize: 15)),
                  ]),
                ]),
              ),
            ],
          ]))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
            ElevatedButton(onPressed: () {
              if (adCtrl.text.trim().isEmpty) return;
              final m = double.tryParse(miktarCtrl.text.replaceAll(',', '.')) ?? 0;
              final f = parseTrMoney(fiyatCtrl.text);
              if (m <= 0) return;
              Navigator.pop(ctx, MalzemeKalemi(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                ad: adCtrl.text.trim(), miktar: m, birim: birim,
                birimTutar: f, belgeNo: belgeCtrl.text.trim(), tarih: tarih,
                odemeYontemi: odemeYontemi,
              ));
            }, child: const Text('Ekle')),
          ],
        );
      }),
    );
    adCtrl.dispose(); belgeCtrl.dispose(); miktarCtrl.dispose(); fiyatCtrl.dispose();
    if (result != null) { setState(() => firma.kalemler.add(result)); widget.onChanged(); }
  }

  Future<void> _deleteKalem(MalzemeKalemi kalem) async {
    final ok = await _confirm(context, 'Sil', '"${kalem.ad}" silinsin mi?');
    if (ok) { setState(() => firma.kalemler.remove(kalem)); widget.onChanged(); }
  }

  void _toggleOdendi(MalzemeKalemi kalem) {
    setState(() => kalem.odendi = !kalem.odendi);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final tumOdendi = firma.kalemler.isNotEmpty && firma.kalemler.every((k) => k.odendi);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface, elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(firma.firmaAdi, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textDark)),
          if (firma.firmaTel.isNotEmpty)
            Text(firma.firmaTel, style: const TextStyle(fontSize: 12, color: AppColors.textMid)),
        ]),
        actions: [
          TextButton.icon(
            onPressed: () => exportFirmaMalzemePdf(context, firma),
            icon: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.danger, size: 18),
            label: const Text('PDF', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addKalem,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('+ Malzeme Ekle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: Column(children: [
        // Firma özet
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: tumOdendi
              ? [AppColors.success, AppColors.success.withOpacity(0.7)]
              : [AppColors.primary, AppColors.primaryLight]),
            borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(firma.firmaAdi, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
                if (firma.not_.isNotEmpty)
                  Text(firma.not_, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Text('KDV Dahil Toplam', style: TextStyle(color: Colors.white70, fontSize: 11)),
                Text('${formatMoney(firma.toplamKdvli)} ₺',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
              ]),
            ]),
            const SizedBox(height: 10),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _ozetTile('KDV Hariç', '${formatMoney(firma.toplamKdvsiz)} ₺')),
              Container(width: 1, height: 24, color: Colors.white30),
              Expanded(child: _ozetTile('KDV (%20)', '${formatMoney(firma.toplamKdv)} ₺')),
              Container(width: 1, height: 24, color: Colors.white30),
              Expanded(child: _ozetTile('Ödenen', '${formatMoney(firma.odenenToplam)} ₺',
                color: const Color(0xFF86EFAC))),
              Container(width: 1, height: 24, color: Colors.white30),
              Expanded(child: _ozetTile('Bekleyen', '${formatMoney(firma.bekleyenToplam)} ₺',
                color: const Color(0xFFFCA5A5))),
            ]),
          ]),
        ),

        // Arama kutusu
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Malzeme adı veya belge no ara...',
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textLight),
              suffixIcon: _search.isNotEmpty
                ? IconButton(icon: const Icon(Icons.close_rounded, size: 16),
                    onPressed: () { _searchCtrl.clear(); setState(() => _search = ''); })
                : null),
          ),
        ),

        // Tablo başlığı
        if (firma.kalemler.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.surfaceAlt,
            child: const Row(children: [
              SizedBox(width: 40, child: Text('Ödendi', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textMid))),
              SizedBox(width: 8),
              Expanded(flex: 2, child: Text('Malzeme', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textMid))),
              Expanded(flex: 1, child: Text('Tarih', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textMid))),
              Expanded(flex: 1, child: Text('Belge', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textMid))),
              Expanded(flex: 1, child: Text('Miktar', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textMid), textAlign: TextAlign.center)),
              Expanded(flex: 1, child: Text('Birim ₺', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textMid), textAlign: TextAlign.right)),
              Expanded(flex: 1, child: Text('KDV Hariç', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textMid), textAlign: TextAlign.right)),
              Expanded(flex: 1, child: Text('KDV %20', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textMid), textAlign: TextAlign.right)),
              Expanded(flex: 1, child: Text('KDV Dahil', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textMid), textAlign: TextAlign.right)),
              SizedBox(width: 32),
            ]),
          ),

        // Kalemler
        Expanded(
          child: firma.kalemler.isEmpty
            ? _EmptyState(icon: Icons.inventory_2_outlined,
                title: 'Malzeme yok',
                subtitle: 'Sağ alttaki + butonuyla malzeme ekleyin.')
            : _filtered.isEmpty
            ? const Center(child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('Sonuç bulunamadı', style: TextStyle(color: AppColors.textMid))))
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: 100),
                itemCount: _filtered.length,
                itemBuilder: (ctx, i) {
                  final k = _filtered[i];
                  return Column(children: [
                    Container(
                      color: k.odendi ? AppColors.success.withOpacity(0.03) : Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(children: [
                        // Ödendi checkbox
                        SizedBox(width: 40, child: Checkbox(
                          value: k.odendi,
                          activeColor: AppColors.success,
                          onChanged: (_) => _toggleOdendi(k),
                        )),
                        const SizedBox(width: 8),
                        // Malzeme adı
                        Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(k.ad, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13,
                            color: AppColors.textDark)),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: k.odemeYontemi == 'cek' ? AppColors.primary.withOpacity(0.1) : AppColors.success.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4)),
                            child: Text(k.odemeYontemi == 'cek' ? 'Çek' : 'Nakit',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                                color: k.odemeYontemi == 'cek' ? AppColors.primary : AppColors.success)),
                          ),
                        ])),
                        Expanded(flex: 1, child: Text(formatDate(k.tarih),
                          style: const TextStyle(fontSize: 11, color: AppColors.textMid))),
                        Expanded(flex: 1, child: Text(k.belgeNo.isNotEmpty ? k.belgeNo : '—',
                          style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600))),
                        Expanded(flex: 1, child: Text('${k.miktar} ${k.birim}',
                          style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)),
                        Expanded(flex: 1, child: Text('${formatMoney(k.birimTutar)} ₺',
                          style: const TextStyle(fontSize: 11), textAlign: TextAlign.right)),
                        Expanded(flex: 1, child: Text('${formatMoney(k.kdvsizToplam)} ₺',
                          style: const TextStyle(fontSize: 11), textAlign: TextAlign.right)),
                        Expanded(flex: 1, child: Text('${formatMoney(k.kdvTutar)} ₺',
                          style: const TextStyle(fontSize: 11, color: AppColors.accent), textAlign: TextAlign.right)),
                        Expanded(flex: 1, child: Text('${formatMoney(k.kdvliToplam)} ₺',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                            color: k.odendi ? AppColors.success : AppColors.primary), textAlign: TextAlign.right)),
                        IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 16),
                          onPressed: () => _deleteKalem(k)),
                      ]),
                    ),
                    const Divider(height: 1, color: AppColors.border),
                  ]);
                },
              ),
        ),

        // Alt toplam
        if (firma.kalemler.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.surfaceAlt,
              border: Border(top: BorderSide(color: AppColors.border))),
            child: Row(children: [
              const SizedBox(width: 48),
              const Expanded(flex: 2, child: Text('TOPLAM', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
              const Expanded(flex: 1, child: SizedBox()),
              const Expanded(flex: 1, child: SizedBox()),
              const Expanded(flex: 1, child: SizedBox()),
              const Expanded(flex: 1, child: SizedBox()),
              Expanded(flex: 1, child: Text('${formatMoney(firma.toplamKdvsiz)} ₺',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11), textAlign: TextAlign.right)),
              Expanded(flex: 1, child: Text('${formatMoney(firma.toplamKdv)} ₺',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppColors.accent), textAlign: TextAlign.right)),
              Expanded(flex: 1, child: Text('${formatMoney(firma.toplamKdvli)} ₺',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.primary), textAlign: TextAlign.right)),
              const SizedBox(width: 32),
            ]),
          ),
      ]),
    );
  }

  Widget _ozetTile(String label, String value, {Color? color}) => Column(children: [
    Text(value, style: TextStyle(color: color ?? Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
      overflow: TextOverflow.ellipsis),
    Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
  ]);
}

class EmployeeDetailPage extends StatefulWidget {
  final ProjectData project;
  final EmployeeData employee;
  const EmployeeDetailPage({super.key, required this.project, required this.employee});
  @override State<EmployeeDetailPage> createState() => _EmployeeDetailPageState();
}

class _EmployeeDetailPageState extends State<EmployeeDetailPage> {
  EmployeeData get e => widget.employee;
  Future<void> _save() => StorageService.save([widget.project]);

  Future<void> _editPayment(MonthlyPayment payment) async {
    final salaryCtrl = TextEditingController(text: formatMoney(payment.salary));
    final minWageCtrl = TextEditingController(text: formatMoney(payment.minimumWage));
    final advanceCtrl = TextEditingController(text: formatMoney(payment.advance));
    final sgkCtrl = TextEditingController(text: formatMoney(payment.sgk));
    final deductionCtrl = TextEditingController(text: formatMoney(payment.deduction));
    final deductionNoteCtrl = TextEditingController(text: payment.deductionNote);
    int leaveDays = payment.leaveDays;

    bool salaryPaid = payment.salaryPaid;
    bool minimumWagePaid = payment.minimumWagePaid;
    bool advancePaid = payment.advancePaid;
    bool cashPaid = payment.cashPaid;
    bool sgkPaid = payment.sgkPaid;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) {
          // Anlık hesaplama
          final sal = parseTrMoney(salaryCtrl.text);
          final minW = parseTrMoney(minWageCtrl.text);
          final adv = parseTrMoney(advanceCtrl.text);
          final ded = parseTrMoney(deductionCtrl.text);
          final days = daysInMonth(payment.month, payment.year);
          final worked = payment.startDay != null && payment.startDay! > 1
              ? days - payment.startDay! + 1 : days;
          final calcSalary = payment.startDay != null && payment.startDay! > 1
              ? (sal / days) * worked : sal;
          final leaveDeduction = leaveDays > 0 ? (sal / days) * leaveDays : 0.0;
          final calcCash = math.max(0.0, calcSalary - leaveDeduction - minW - adv - ded);

          return AlertDialog(
            title: Text('${monthNameTr(payment.month)} ${payment.year} — Bordro'),
            content: SizedBox(width: 500, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Giriş günü bilgisi
              if (payment.hasPartialMonth)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.warning.withOpacity(0.2))),
                  child: Text(
                    '${payment.startDay}. gunten giris: $worked/$days gun calisma',
                    style: const TextStyle(color: AppColors.warning, fontSize: 12, fontWeight: FontWeight.w600)),
                ),

              // İzin günü sayacı
              Row(children: [
                const Icon(Icons.beach_access_rounded, color: AppColors.accent, size: 20),
                const SizedBox(width: 10),
                const Expanded(child: Text('Fazladan Kullanilan Izin Gunu', style: TextStyle(fontWeight: FontWeight.w600))),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 20, color: AppColors.danger),
                  onPressed: () => ss(() { if (leaveDays > 0) leaveDays--; }),
                ),
                Container(
                  width: 52, height: 36,
                  decoration: BoxDecoration(
                    color: leaveDays > 0 ? AppColors.accent.withOpacity(0.1) : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: leaveDays > 0 ? AppColors.accent : AppColors.border),
                  ),
                  child: Center(child: Text('$leaveDays', style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 18,
                    color: leaveDays > 0 ? AppColors.accent : AppColors.textMid))),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 20, color: AppColors.success),
                  onPressed: () => ss(() => leaveDays++),
                ),
                const Text('gun', style: TextStyle(color: AppColors.textMid, fontSize: 13)),
              ]),
              if (leaveDays > 0)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.06), borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Fazladan izin kesintisi: $leaveDays gun x ${formatMoney(sal / days)} TL',
                      style: const TextStyle(color: AppColors.accent, fontSize: 12)),
                    Text('- ${formatMoney((sal / days) * leaveDays)} TL',
                      style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700, fontSize: 12)),
                  ]),
                ),
              const Divider(height: 16),

              // Maaş - sadece referans, ödendi checkbox'ı yok
              Row(children: [
                Expanded(child: TextField(
                  controller: salaryCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => ss(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Aylık Maaş (Referans)',
                    prefixIcon: Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary, size: 18),
                  ),
                )),
              ]),
              const SizedBox(height: 8),
              // Asgari
              _payRowNew('Asgari Ücret', minWageCtrl, minimumWagePaid, Icons.money_outlined, AppColors.textMid,
                (v) => ss(() => minimumWagePaid = v), onChanged: () => ss(() {})),
              const SizedBox(height: 8),
              // Avans
              _payRowNew('Avans', advanceCtrl, advancePaid, Icons.payments_outlined, AppColors.warning,
                (v) => ss(() => advancePaid = v), onChanged: () => ss(() {})),
              const SizedBox(height: 8),
              // SGK
              _payRowNew('SGK', sgkCtrl, sgkPaid, Icons.health_and_safety_outlined, AppColors.accent,
                (v) => ss(() => sgkPaid = v), onChanged: () => ss(() {})),
              const SizedBox(height: 12),
              // Kesinti
              Row(children: [
                Expanded(child: TextField(controller: deductionCtrl, keyboardType: TextInputType.number,
                  onChanged: (_) => ss(() {}),
                  decoration: const InputDecoration(labelText: 'Kesinti', prefixIcon: Icon(Icons.remove_circle_outline)))),
              ]),
              const SizedBox(height: 8),
              TextField(controller: deductionNoteCtrl, maxLines: 1,
                decoration: const InputDecoration(labelText: 'Kesinti Açıklaması')),

              const Divider(height: 20),

              // Otomatik hesaplanan elden
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.success.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.success.withOpacity(0.2))),
                child: Column(children: [
                  Row(children: [
                    const Icon(Icons.calculate_rounded, color: AppColors.success, size: 16),
                    const SizedBox(width: 8),
                    const Text('Elden (Otomatik)', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 8),
                  if (payment.hasPartialMonth)
                    _calcRowSmall('Orantili Maas ($worked/$days gun)', '${formatMoney(calcSalary)} TL'),
                  if (leaveDays > 0)
                    _calcRowSmall('- Izin ($leaveDays gun)', '- ${formatMoney((sal / days) * leaveDays)} TL'),
                  _calcRowSmall('Net Maas', '${formatMoney(math.max(0, calcSalary - (sal / days) * leaveDays))} TL'),
                  _calcRowSmall('- Asgari', '- ${formatMoney(minW)} TL'),
                  _calcRowSmall('- Avans', '- ${formatMoney(adv)} TL'),
                  _calcRowSmall('- Kesinti', '- ${formatMoney(ded)} TL'),
                  const Divider(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('= Elden', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700)),
                    Text('${formatMoney(calcCash)} TL', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w900, fontSize: 16)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: const Text('Elden Odendi mi?', style: TextStyle(fontSize: 13))),
                    Checkbox(value: cashPaid, onChanged: (v) => ss(() => cashPaid = v ?? false)),
                  ]),
                ]),
              ),
            ]))),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
              ElevatedButton(onPressed: () {
                final sal2 = parseTrMoney(salaryCtrl.text);
                final minW2 = parseTrMoney(minWageCtrl.text);
                final adv2 = parseTrMoney(advanceCtrl.text);
                final ded2 = parseTrMoney(deductionCtrl.text);
                final days2 = daysInMonth(payment.month, payment.year);
                final calcSal2 = payment.startDay != null && payment.startDay! > 1
                    ? (sal2 / days2) * (days2 - payment.startDay! + 1) : sal2;
                final calcCash2 = math.max(0.0, calcSal2 - minW2 - adv2 - ded2);

                payment.salary = sal2;
                payment.minimumWage = minW2;
                payment.minimumWagePaid = minimumWagePaid;
                payment.advance = adv2;
                payment.advancePaid = advancePaid;
                payment.sgk = parseTrMoney(sgkCtrl.text);
                payment.sgkPaid = sgkPaid;
                payment.deduction = ded2;
                payment.deductionNote = deductionNoteCtrl.text.trim();
                payment.cashPaid = cashPaid;
                payment.leaveDays = leaveDays;
                Navigator.pop(ctx, true);
              }, child: const Text('Kaydet')),
            ],
          );
        },
      ),
    );
    for (final c in [salaryCtrl, minWageCtrl, advanceCtrl, sgkCtrl, deductionCtrl, deductionNoteCtrl]) c.dispose();
    if (saved == true) { setState(() {}); await _save(); }
  }

  Widget _payRowNew(String label, TextEditingController ctrl, bool paid, IconData icon, Color color,
      ValueChanged<bool> onPaid, {required VoidCallback onChanged}) => Row(children: [
    Expanded(child: TextField(controller: ctrl, keyboardType: TextInputType.number,
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, color: color, size: 18)))),
    const SizedBox(width: 8),
    Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('Ödendi', style: TextStyle(fontSize: 10, color: AppColors.textMid)),
      Checkbox(value: paid, onChanged: (v) => onPaid(v ?? false)),
    ]),
  ]);

  Widget _calcRowSmall(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: AppColors.textMid, fontSize: 12)),
      Text(value, style: const TextStyle(color: AppColors.textMid, fontSize: 12)),
    ]),
  );

  Future<LeaveRecord?> _showLeaveDialog(BuildContext ctx, {LeaveRecord? existing}) async {
    DateTime date = existing?.date ?? DateTime.now();
    final typeCtrl = TextEditingController(text: existing?.leaveType ?? '');
    final noteCtrl = TextEditingController(text: existing?.note ?? '');
    final result = await showDialog<LeaveRecord>(
      context: ctx,
      builder: (ctx2) => StatefulBuilder(
        builder: (ctx2, ss) => AlertDialog(
          title: Text(existing == null ? 'İzin Ekle' : 'İzin Düzenle'),
          content: SizedBox(width: 380, child: Column(mainAxisSize: MainAxisSize.min, children: [
            _DateField(label: 'Tarih', date: date, onPicked: (d) => ss(() => date = d)),
            const SizedBox(height: 12),
            TextField(controller: typeCtrl, decoration: const InputDecoration(
              labelText: 'İzin Türü *', hintText: 'Yıllık, Mazeret, Hastalık...')),
            const SizedBox(height: 12),
            TextField(controller: noteCtrl, maxLines: 2,
              decoration: const InputDecoration(labelText: 'Açıklama')),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx2), child: const Text('İptal')),
            ElevatedButton(onPressed: () {
              if (typeCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx2, LeaveRecord(
                date: date, leaveType: typeCtrl.text.trim(), note: noteCtrl.text.trim()));
            }, child: const Text('Kaydet')),
          ],
        ),
      ),
    );
    typeCtrl.dispose(); noteCtrl.dispose();
    return result;
  }

  Future<void> _addLeave() async {
    final result = await _showLeaveDialog(context);
    if (result != null) { setState(() => e.leaves.add(result)); await _save(); }
  }

  Future<void> _editLeave(int i) async {
    final result = await _showLeaveDialog(context, existing: e.leaves[i]);
    if (result != null) {
      setState(() { e.leaves[i].date = result.date; e.leaves[i].leaveType = result.leaveType; e.leaves[i].note = result.note; });
      await _save();
    }
  }

  Future<void> _deleteLeave(int i) async {
    final ok = await _confirm(context, 'İzin Sil', 'Bu izin kaydını silmek istiyor musunuz?');
    if (ok) { setState(() => e.leaves.removeAt(i)); await _save(); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textDark)),
      actions: [
        TextButton.icon(
          onPressed: () => exportEmployeePdf(context, widget.employee, widget.project.name),
          icon: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.danger, size: 18),
          label: const Text('PDF Oluştur', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 8),
      ],
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // BİLGİ KARTI
        _InfoCard(title: 'Personel Bilgileri', children: [
          _InfoRow2(label: 'Ad Soyad', value: e.name),
          if (e.role.isNotEmpty) _InfoRow2(label: 'Görev', value: e.role),
          if (e.tcNo.isNotEmpty) _InfoRow2(label: 'TC Kimlik No', value: e.tcNo),
          if (e.birthDate != null) _InfoRow2(label: 'Doğum Tarihi', value: formatDate(e.birthDate!)),
          if (e.phone.isNotEmpty) _InfoRow2(label: 'Telefon', value: e.phone),
          if (e.iban.isNotEmpty) _InfoRow2(label: 'IBAN', value: e.iban),
          _InfoRow2(label: 'İşe Giriş', value: formatDate(e.startDate)),
          _InfoRow2(label: 'İşten Çıkış', value: e.endDate != null ? formatDate(e.endDate!) : 'Devam ediyor'),
          _InfoRow2(label: 'Durum', value: e.hasExited ? 'İşten ayrıldı' : 'Aktif'),
          _InfoRow2(label: 'Aylık Maaş', value: '${formatMoney(e.salary)} ₺'),
        ]),
        const SizedBox(height: 20),
        // ÖZET
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth > 600 ? 4 : 2;
          return GridView.count(
            crossAxisCount: cols, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.0,
            children: [
              _KpiCard(label: 'Toplam Ödenen', value: '${formatMoney(e.totalPaid())} ₺', icon: Icons.payments_rounded, color: AppColors.primary),
              _KpiCard(label: 'Ödenen Maaş', value: '${formatMoney(e.totalPaidSalary())} ₺', icon: Icons.account_balance_rounded, color: AppColors.success),
              _KpiCard(label: 'Ödenen SGK', value: '${formatMoney(e.totalPaidSgk())} ₺', icon: Icons.health_and_safety_rounded, color: AppColors.accent),
              _KpiCard(label: 'Toplam Kesinti', value: '${formatMoney(e.totalDeduction())} ₺', icon: Icons.remove_circle_rounded, color: AppColors.danger),
            ],
          );
        }),
        const SizedBox(height: 24),
        // AYLIK ÖDEMELER
        const Text('Aylık Ödeme Takibi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
        const SizedBox(height: 12),
        ...e.monthlyPayments.map((payment) => _MonthCard(payment: payment, onEdit: () => _editPayment(payment))),
        const SizedBox(height: 24),
        // İZİNLER
        Row(children: [
          const Text('İzin Kayıtları', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text('${e.leaves.length}', style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.w700, fontSize: 12)),
          ),
          const Spacer(),
          ElevatedButton.icon(onPressed: _addLeave, icon: const Icon(Icons.add, size: 16), label: const Text('+ İzin')),
        ]),
        const SizedBox(height: 12),
        if (e.leaves.isEmpty)
          _EmptyCard(text: 'Henüz izin kaydı yok')
        else
          ...e.leaves.asMap().entries.map((entry) => _LeaveCard(
            leave: entry.value, onEdit: () => _editLeave(entry.key), onDelete: () => _deleteLeave(entry.key))),
      ]),
    ),
  );
}

class _MonthCard extends StatelessWidget {
  final MonthlyPayment payment;
  final VoidCallback onEdit;
  const _MonthCard({required this.payment, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final calcSalary = payment.calculatedSalary;
    final calcCash = payment.calculatedCash;
    final allPaid = payment.minimumWagePaid && payment.advancePaid && payment.cashPaid && payment.sgkPaid;
    final anyPaid = payment.advancePaid || payment.minimumWagePaid || payment.cashPaid || payment.sgkPaid;
    final statusColor = allPaid ? AppColors.success : anyPaid ? AppColors.warning : AppColors.textLight;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${monthNameTr(payment.month)} ${payment.year}',
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark)),
          const SizedBox(height: 6),
          // Giriş & izin bilgisi
          Row(children: [
            if (payment.hasPartialMonth)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Text('${payment.startDay}. gunten giris — ${payment.workedDays}/${payment.totalDaysInMonth} gun',
                  style: const TextStyle(color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            if (payment.leaveDays > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.beach_access_rounded, size: 12, color: AppColors.accent),
                  const SizedBox(width: 4),
                  Text('${payment.leaveDays} gun izin',
                    style: const TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w700)),
                ]),
              ),
          ]),
          if (payment.hasPartialMonth || payment.leaveDays > 0) const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 6, children: [
            // Maaş - girilen maaş sabit gösterilir
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
              child: Text('Maas: ${formatMoney(payment.salary)} TL',
                style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
            _PayChip(label: 'Asgari', paid: payment.minimumWagePaid, amount: payment.minimumWage),
            _PayChip(label: 'Avans', paid: payment.advancePaid, amount: payment.advance),
            _PayChip(label: 'Elden', paid: payment.cashPaid, amount: payment.calculatedCash),
            _PayChip(label: 'SGK', paid: payment.sgkPaid, amount: payment.sgk),
            if (payment.leaveDays > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Text('Izin Kesintisi: -${formatMoney(payment.leaveDeduction)} TL',
                    style: const TextStyle(color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            if (payment.deduction > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Text('Kesinti: -${formatMoney(payment.deduction)} TL',
                    style: const TextStyle(color: AppColors.danger, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
          ]),
          if (payment.deductionNote.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Not: ${payment.deductionNote}', style: const TextStyle(color: AppColors.textMid, fontSize: 11)),
          ],
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${formatMoney(payment.totalPaid())} ₺', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 6),
          OutlinedButton(onPressed: onEdit, style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            child: const Text('Düzenle', style: TextStyle(fontSize: 12))),
        ]),
      ]),
    );
  }
}

class _PayChip extends StatelessWidget {
  final String label;
  final bool paid;
  final double amount;
  const _PayChip({required this.label, required this.paid, required this.amount});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: paid ? AppColors.success.withOpacity(0.1) : AppColors.bg,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: paid ? AppColors.success.withOpacity(0.3) : AppColors.border),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (paid) const Icon(Icons.check_circle_rounded, size: 12, color: AppColors.success),
      if (paid) const SizedBox(width: 4),
      Text('$label: ${formatMoney(amount)} ₺',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: paid ? AppColors.success : AppColors.textMid)),
    ]),
  );
}

class _LeaveCard extends StatelessWidget {
  final LeaveRecord leave;
  final VoidCallback onEdit, onDelete;
  const _LeaveCard({required this.leave, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
    child: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.event_busy_rounded, color: AppColors.warning, size: 18),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(leave.leaveType, style: const TextStyle(fontWeight: FontWeight.w700)),
        Text(formatDate(leave.date), style: const TextStyle(color: AppColors.textMid, fontSize: 12)),
        if (leave.note.isNotEmpty) Text(leave.note, style: const TextStyle(color: AppColors.textLight, fontSize: 12)),
      ])),
      PopupMenuButton<String>(
        onSelected: (v) { if (v == 'edit') onEdit(); else onDelete(); },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Düzenle')),
          PopupMenuItem(value: 'delete', child: Text('Sil', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════
//  BÖLÜM DETAY SAYFASI
// ══════════════════════════════════════════════════════════════

class SectionDetailPage extends StatefulWidget {
  final ProjectData project;
  final AppSection section;
  const SectionDetailPage({super.key, required this.project, required this.section});
  @override State<SectionDetailPage> createState() => _SectionDetailPageState();
}

class _SectionDetailPageState extends State<SectionDetailPage> {
  AppSection get s => widget.section;
  Future<void> _save() => StorageService.save([widget.project]);

  Future<void> _addCredit() async {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    DateTime date = DateTime.now();
    String type = 'check';
    final result = await showDialog<CariCredit>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => AlertDialog(
        title: const Text('Çek / Nakit / Avans Ekle'),
        content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            _tipBtn('Çek', 'check', Icons.receipt_long_rounded, type, (v) => ss(() => type = v)),
            const SizedBox(width: 8),
            _tipBtn('Nakit', 'cash', Icons.payments_rounded, type, (v) => ss(() => type = v)),
            const SizedBox(width: 8),
            _tipBtn('Avans', 'advance', Icons.forward_rounded, type, (v) => ss(() => type = v)),
          ]),
          const SizedBox(height: 14),
          TextField(controller: amountCtrl, keyboardType: TextInputType.number, autofocus: true,
            decoration: const InputDecoration(labelText: 'Tutar (₺) *', prefixIcon: Icon(Icons.attach_money_rounded))),
          const SizedBox(height: 10),
          _DateField(label: 'Tarih', date: date, onPicked: (d) => ss(() => date = d)),
          const SizedBox(height: 10),
          TextField(controller: noteCtrl,
            decoration: const InputDecoration(labelText: 'Not / Çek No', prefixIcon: Icon(Icons.notes_rounded))),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(onPressed: () {
            final amount = parseTrMoney(amountCtrl.text);
            if (amount <= 0) return;
            Navigator.pop(ctx, CariCredit(type: type, amount: amount, date: date, note: noteCtrl.text.trim()));
          }, child: const Text('Kaydet')),
        ],
      )),
    );
    amountCtrl.dispose(); noteCtrl.dispose();
    if (result != null) { setState(() => s.credits.add(result)); await _save(); }
  }

  Future<void> _deleteCredit(int i) async {
    final ok = await _confirm(context, 'Sil', 'Bu kayıt silinsin mi?');
    if (ok) { setState(() => s.credits.removeAt(i)); await _save(); }
  }

  Future<void> _addEntry() async {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    DateTime date = DateTime.now();
    String paymentType = PaymentType.cash;
    final result = await showDialog<SectionEntry>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => AlertDialog(
        title: const Text('Alınan Ürün / Hizmet Ekle'),
        content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titleCtrl, autofocus: true,
            decoration: const InputDecoration(labelText: 'Ürün / Hizmet Adı *', prefixIcon: Icon(Icons.inventory_2_outlined))),
          const SizedBox(height: 10),
          TextField(controller: noteCtrl,
            decoration: const InputDecoration(labelText: 'Açıklama', prefixIcon: Icon(Icons.notes_rounded))),
          const SizedBox(height: 10),
          _DateField(label: 'Tarih', date: date, onPicked: (d) => ss(() => date = d)),
          const SizedBox(height: 10),
          TextField(controller: amountCtrl, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Tutar (₺) *', prefixIcon: Icon(Icons.attach_money_rounded))),
          const SizedBox(height: 12),
          // Ödeme yöntemi
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => ss(() => paymentType = PaymentType.cash),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: paymentType == PaymentType.cash ? AppColors.success.withOpacity(0.1) : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: paymentType == PaymentType.cash ? AppColors.success : AppColors.border)),
                child: Column(children: [
                  Icon(Icons.payments_rounded, color: paymentType == PaymentType.cash ? AppColors.success : AppColors.textMid, size: 18),
                  const SizedBox(height: 4),
                  Text('Nakit', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12,
                    color: paymentType == PaymentType.cash ? AppColors.success : AppColors.textMid)),
                ]),
              ),
            )),
            const SizedBox(width: 8),
            Expanded(child: GestureDetector(
              onTap: () => ss(() => paymentType = PaymentType.check),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: paymentType == PaymentType.check ? AppColors.primary.withOpacity(0.1) : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: paymentType == PaymentType.check ? AppColors.primary : AppColors.border)),
                child: Column(children: [
                  Icon(Icons.receipt_long_rounded, color: paymentType == PaymentType.check ? AppColors.primary : AppColors.textMid, size: 18),
                  const SizedBox(height: 4),
                  Text('Çek', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12,
                    color: paymentType == PaymentType.check ? AppColors.primary : AppColors.textMid)),
                ]),
              ),
            )),
            const SizedBox(width: 8),
            Expanded(child: GestureDetector(
              onTap: () => ss(() => paymentType = PaymentType.debt),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: paymentType == PaymentType.debt ? AppColors.warning.withOpacity(0.1) : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: paymentType == PaymentType.debt ? AppColors.warning : AppColors.border)),
                child: Column(children: [
                  Icon(Icons.pending_rounded, color: paymentType == PaymentType.debt ? AppColors.warning : AppColors.textMid, size: 18),
                  const SizedBox(height: 4),
                  Text('Veresiye', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12,
                    color: paymentType == PaymentType.debt ? AppColors.warning : AppColors.textMid)),
                ]),
              ),
            )),
          ]),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(onPressed: () {
            if (titleCtrl.text.trim().isEmpty) return;
            final amount = parseTrMoney(amountCtrl.text);
            if (amount <= 0) return;
            Navigator.pop(ctx, SectionEntry(
              title: titleCtrl.text.trim(), amount: amount, date: date,
              note: noteCtrl.text.trim(), paymentType: paymentType));
          }, child: const Text('Kaydet')),
        ],
      )),
    );
    titleCtrl.dispose(); amountCtrl.dispose(); noteCtrl.dispose();
    if (result != null) { setState(() => s.entries.add(result)); await _save(); }
  }

  Future<void> _editEntry(int i) async {
    final e = s.entries[i];
    final titleCtrl = TextEditingController(text: e.title);
    final amountCtrl = TextEditingController(text: formatMoney(e.amount));
    final noteCtrl = TextEditingController(text: e.note);
    DateTime date = e.date;
    final result = await showDialog<SectionEntry>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => AlertDialog(
        title: const Text('Düzenle'),
        content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titleCtrl,
            decoration: const InputDecoration(labelText: 'Ürün / Hizmet Adı *')),
          const SizedBox(height: 10),
          TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Açıklama')),
          const SizedBox(height: 10),
          _DateField(label: 'Tarih', date: date, onPicked: (d) => ss(() => date = d)),
          const SizedBox(height: 10),
          TextField(controller: amountCtrl, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Tutar (₺) *')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(onPressed: () {
            if (titleCtrl.text.trim().isEmpty) return;
            final amount = parseTrMoney(amountCtrl.text);
            if (amount <= 0) return;
            Navigator.pop(ctx, SectionEntry(
              title: titleCtrl.text.trim(), amount: amount, date: date, note: noteCtrl.text.trim()));
          }, child: const Text('Kaydet')),
        ],
      )),
    );
    titleCtrl.dispose(); amountCtrl.dispose(); noteCtrl.dispose();
    if (result != null) { setState(() => s.entries[i] = result); await _save(); }
  }

  Future<void> _deleteEntry(int i) async {
    final ok = await _confirm(context, 'Sil', 'Bu kayıt silinsin mi?');
    if (ok) { setState(() => s.entries.removeAt(i)); await _save(); }
  }

  Widget _tipBtn(String label, String val, IconData icon, String current, ValueChanged<String> onTap) =>
    Expanded(child: GestureDetector(
      onTap: () => onTap(val),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: current == val ? AppColors.primary : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: current == val ? AppColors.primary : AppColors.border),
        ),
        child: Column(children: [
          Icon(icon, size: 18, color: current == val ? Colors.white : AppColors.textMid),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
            color: current == val ? Colors.white : AppColors.textDark)),
        ]),
      ),
    ));

  @override
  Widget build(BuildContext context) {
    final balance = s.balance;
    final balColor = balance >= 0 ? AppColors.success : AppColors.danger;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface, elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.title, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textDark)),
          Text(widget.project.name, style: const TextStyle(fontSize: 12, color: AppColors.textMid)),
        ]),
        actions: [
          TextButton.icon(
            onPressed: () => exportSectionPdf(context, widget.section, widget.project.name),
            icon: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.danger, size: 18),
            label: const Text('PDF Oluştur', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // BAKİYE ÖZET KARTI
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(children: [
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                  if (s.companyTitle.isNotEmpty)
                    Text(s.companyTitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  if (s.note.isNotEmpty)
                    Text(s.note, style: const TextStyle(color: Colors.white60, fontSize: 11)),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(balance >= 0 ? 'Alacağımız' : 'Borcumuz',
                    style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  Text('${formatMoney(balance.abs())} ₺',
                    style: TextStyle(
                      color: balance >= 0 ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                      fontWeight: FontWeight.w900, fontSize: 20)),
                ]),
              ]),
              const SizedBox(height: 12),
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _sumRow('Verilen', s.totalCredits, const Color(0xFF86EFAC))),
                Container(width: 1, height: 32, color: Colors.white24),
                Expanded(child: _sumRow('Alınan', s.total, const Color(0xFFFCA5A5))),
                Container(width: 1, height: 32, color: Colors.white24),
                Expanded(child: _sumRow('Bakiye', balance.abs(), balance >= 0 ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5))),
              ]),
            ]),
          ),

          const SizedBox(height: 22),

          // VERİLEN ÇEK / NAKİT / AVANS
          Row(children: [
            const Expanded(child: Text('Verilen Çek / Nakit / Avans',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textDark))),
            ElevatedButton.icon(
              onPressed: _addCredit,
              icon: const Icon(Icons.add, size: 15),
              label: const Text('+ Ekle'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
            ),
          ]),
          const SizedBox(height: 8),
          if (s.credits.isEmpty)
            _EmptyCard(text: 'Henüz ödeme girilmedi')
          else ...[
            ...s.credits.asMap().entries.map((e) {
              final c = e.value;
              final tc = c.type == 'check' ? AppColors.primary : c.type == 'cash' ? AppColors.success : AppColors.warning;
              final tl = c.type == 'check' ? 'Çek' : c.type == 'cash' ? 'Nakit' : 'Avans';
              final ti = c.type == 'check' ? Icons.receipt_long_rounded : c.type == 'cash' ? Icons.payments_rounded : Icons.forward_rounded;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                child: Row(children: [
                  Container(width: 36, height: 36,
                    decoration: BoxDecoration(color: tc.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Icon(ti, color: tc, size: 18)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: tc.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                        child: Text(tl, style: TextStyle(color: tc, fontSize: 11, fontWeight: FontWeight.w700))),
                      const SizedBox(width: 8),
                      Text(formatDate(c.date), style: const TextStyle(color: AppColors.textLight, fontSize: 12)),
                    ]),
                    if (c.note.isNotEmpty)
                      Text(c.note, style: const TextStyle(color: AppColors.textMid, fontSize: 12)),
                  ])),
                  Text('${formatMoney(c.amount)} ₺', style: TextStyle(fontWeight: FontWeight.w800, color: tc, fontSize: 15)),
                  IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 18),
                    onPressed: () => _deleteCredit(e.key)),
                ]),
              );
            }),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: AppColors.success.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.success.withOpacity(0.2))),
              child: Row(children: [
                const Text('Toplam Verilen', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.success)),
                const Spacer(),
                Text('${formatMoney(s.totalCredits)} ₺',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.success, fontSize: 15)),
              ]),
            ),
          ],

          const SizedBox(height: 22),

          // ALINAN ÜRÜNLER / HİZMETLER
          Row(children: [
            const Expanded(child: Text('Alınan Ürünler / Hizmetler',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textDark))),
            ElevatedButton.icon(
              onPressed: _addEntry,
              icon: const Icon(Icons.add, size: 15),
              label: const Text('+ Ekle'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
            ),
          ]),
          const SizedBox(height: 8),
          if (s.entries.isEmpty)
            _EmptyCard(text: 'Henüz ürün / hizmet girilmedi')
          else ...[
            ...s.entries.asMap().entries.map((e) {
              final entry = e.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                child: Row(children: [
                  Container(width: 36, height: 36,
                    decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.inventory_2_outlined, color: AppColors.danger, size: 18)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(entry.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    Row(children: [
                      Text(formatDate(entry.date), style: const TextStyle(color: AppColors.textLight, fontSize: 11)),
                      if (entry.note.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Expanded(child: Text(entry.note,
                          style: const TextStyle(color: AppColors.textMid, fontSize: 11),
                          overflow: TextOverflow.ellipsis)),
                      ],
                    ]),
                  ])),
                  Text('${formatMoney(entry.amount)} ₺',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.danger, fontSize: 14)),
                  PopupMenuButton<String>(
                    onSelected: (v) { if (v == 'edit') _editEntry(e.key); else _deleteEntry(e.key); },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                      PopupMenuItem(value: 'delete', child: Text('Sil', style: TextStyle(color: AppColors.danger))),
                    ],
                  ),
                ]),
              );
            }),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.danger.withOpacity(0.2))),
              child: Row(children: [
                const Text('Toplam Alınan', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.danger)),
                const Spacer(),
                Text('${formatMoney(s.total)} ₺',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.danger, fontSize: 15)),
              ]),
            ),
          ],

          const SizedBox(height: 22),

          // BAKİYE
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: balColor.withOpacity(0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: balColor.withOpacity(0.3)),
            ),
            child: Row(children: [
              Icon(balance >= 0 ? Icons.thumb_up_rounded : Icons.warning_amber_rounded, color: balColor, size: 26),
              const SizedBox(width: 14),
              Expanded(child: Text(
                balance >= 0 ? 'Alacağımız var' : 'Borcumuz var',
                style: TextStyle(color: balColor, fontWeight: FontWeight.w800, fontSize: 14))),
              Text('${formatMoney(balance.abs())} ₺',
                style: TextStyle(color: balColor, fontWeight: FontWeight.w900, fontSize: 18)),
            ]),
          ),
          const SizedBox(height: 30),
        ]),
      ),
    );
  }

  Widget _sumRow(String label, double amount, Color color) => Column(children: [
    Text('${formatMoney(amount)} ₺', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13),
      overflow: TextOverflow.ellipsis),
    Text(label, style: TextStyle(color: color.withOpacity(0.8), fontSize: 10)),
  ]);
}

// ══════════════════════════════════════════════════════════════
//  RAPORLAR SAYFASI
// ══════════════════════════════════════════════════════════════

// ══════════════════════════════════════════════════════════════
//  BORDRO ÖZETİ SAYFASI
// ══════════════════════════════════════════════════════════════

class _BordroPage extends StatefulWidget {
  final List<ProjectData> projects;
  const _BordroPage({required this.projects});
  @override State<_BordroPage> createState() => _BordroPageState();
}

class _BordroPageState extends State<_BordroPage> {
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  String _selectedProject = 'Tümü';

  List<String> get _projectNames => ['Tümü', ...widget.projects.map((p) => p.name)];

  List<MapEntry<ProjectData, EmployeeData>> get _filteredEmployees {
    final result = <MapEntry<ProjectData, EmployeeData>>[];
    for (final p in widget.projects) {
      if (_selectedProject != 'Tümü' && p.name != _selectedProject) continue;
      for (final e in p.employees) {
        result.add(MapEntry(p, e));
      }
    }
    return result;
  }

  MonthlyPayment? _getPayment(EmployeeData e) {
    try {
      return e.monthlyPayments.firstWhere(
        (m) => m.month == _selectedMonth && m.year == _selectedYear);
    } catch (_) { return null; }
  }

  @override
  Widget build(BuildContext context) {
    final employees = _filteredEmployees;
    final payments = employees.map((e) => _getPayment(e.value)).toList();

    // Toplamlar
    double totalSalary = 0, totalMinWage = 0, totalAdvance = 0,
           totalCash = 0, totalSgk = 0, totalDeduction = 0;
    int totalLeave = 0;
    for (final p in payments) {
      if (p == null) continue;
      totalSalary += p.netSalary;
      totalMinWage += p.minimumWage;
      totalAdvance += p.advance;
      totalCash += p.calculatedCash;
      totalSgk += p.sgk;
      totalDeduction += p.deduction;
      totalLeave += p.leaveDays;
    }

    return Column(children: [
      // ── BAŞLIK & FİLTRELER ──────────────────────────────────
      Container(
        color: AppColors.surface,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
                borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.table_chart_rounded, color: Colors.white, size: 22)),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Bordro Özeti', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textDark)),
              Text('Aylık personel bordro tablosu', style: TextStyle(color: AppColors.textMid, fontSize: 12)),
            ])),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            // Ay seçici
            Expanded(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
              child: DropdownButtonHideUnderline(child: DropdownButton<int>(
                value: _selectedMonth,
                items: List.generate(12, (i) => DropdownMenuItem(
                  value: i + 1, child: Text(monthNameTr(i + 1)))),
                onChanged: (v) => setState(() => _selectedMonth = v!),
              )),
            )),
            const SizedBox(width: 8),
            // Yıl seçici
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
              child: DropdownButtonHideUnderline(child: DropdownButton<int>(
                value: _selectedYear,
                items: [2024, 2025, 2026, 2027].map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                onChanged: (v) => setState(() => _selectedYear = v!),
              )),
            ),
            const SizedBox(width: 8),
            // Proje filtresi
            Expanded(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
              child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                value: _selectedProject,
                isExpanded: true,
                items: _projectNames.map((n) => DropdownMenuItem(value: n, child: Text(n, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (v) => setState(() => _selectedProject = v!),
              )),
            )),
          ]),
        ]),
      ),

      // ── TABLO ───────────────────────────────────────────────
      Expanded(child: employees.isEmpty
        ? const _EmptyState(icon: Icons.people_outlined, title: 'Personel yok', subtitle: 'Projelere personel ekleyin.')
        : SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Tablo başlığı
                Container(
                  color: AppColors.primary,
                  child: Row(children: [
                    _hCell('AD SOYAD', 180, left: true),
                    _hCell('PROJE', 120),
                    _hCell('MAAS', 90),
                    _hCell('IZIN', 50),
                    _hCell('KESINTİ', 80),
                    _hCell('AVANS', 80),
                    _hCell('ASGARİ', 90),
                    _hCell('ELDEN', 90),
                    _hCell('SGK', 80),
                    _hCell('DURUM', 80),
                  ]),
                ),

                // Personel satırları
                ...employees.asMap().entries.map((entry) {
                  final i = entry.key;
                  final proj = entry.value.key;
                  final emp = entry.value.value;
                  final pay = payments[i];
                  final isEven = i % 2 == 0;
                  final isExited = emp.hasExited;
                  final bgColor = isExited
                    ? AppColors.danger.withOpacity(0.06)
                    : isEven ? AppColors.surface : AppColors.surfaceAlt;

                  final allPaid = pay != null &&
                    pay.minimumWagePaid && pay.advancePaid && pay.cashPaid;

                  return Container(
                    decoration: BoxDecoration(
                      color: bgColor,
                      border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
                    ),
                    child: Row(children: [
                      // Ad Soyad
                      Container(
                        width: 180,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: (isExited ? AppColors.textLight : AppColors.primary).withOpacity(0.15),
                            child: Text(emp.name.isNotEmpty ? emp.name[0].toUpperCase() : '?',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                                color: isExited ? AppColors.textLight : AppColors.primary)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(emp.name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12,
                              color: isExited ? AppColors.textLight : AppColors.textDark),
                              overflow: TextOverflow.ellipsis),
                            if (emp.role.isNotEmpty)
                              Text(emp.role, style: const TextStyle(fontSize: 10, color: AppColors.textLight),
                                overflow: TextOverflow.ellipsis),
                          ])),
                        ]),
                      ),
                      // Proje
                      _dCell(proj.name, 120, color: AppColors.primary),
                      // Maaş
                      _dCell(pay != null ? formatMoney(pay.netSalary) : '—', 90),
                      // İzin
                      _dCell(pay != null && pay.leaveDays > 0 ? '${pay.leaveDays} gun' : '—', 50,
                        color: pay != null && pay.leaveDays > 0 ? AppColors.accent : AppColors.textLight),
                      // Kesinti
                      _dCell(pay != null && pay.deduction > 0 ? formatMoney(pay.deduction) : '—', 80,
                        color: pay != null && pay.deduction > 0 ? AppColors.danger : AppColors.textLight),
                      // Avans
                      _dCell(pay != null && pay.advance > 0 ? formatMoney(pay.advance) : '—', 80,
                        color: pay != null && pay.advance > 0 ? AppColors.warning : AppColors.textLight),
                      // Asgari
                      _dCell(pay != null && pay.minimumWage > 0 ? formatMoney(pay.minimumWage) : '—', 90),
                      // Elden
                      _dCell(pay != null ? formatMoney(pay.calculatedCash) : '—', 90,
                        color: AppColors.success, bold: true),
                      // SGK
                      _dCell(pay != null && pay.sgk > 0 ? formatMoney(pay.sgk) : '—', 80),
                      // Durum
                      Container(
                        width: 80,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                        child: Center(child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: isExited ? AppColors.danger.withOpacity(0.1)
                              : allPaid ? AppColors.success.withOpacity(0.1)
                              : AppColors.warning.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6)),
                          child: Text(
                            isExited ? 'Ayrıldı' : allPaid ? 'Odendi' : 'Bekliyor',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                              color: isExited ? AppColors.danger
                                : allPaid ? AppColors.success : AppColors.warning)),
                        )),
                      ),
                    ]),
                  );
                }),

                // Toplam satırı
                Container(
                  color: AppColors.primary.withOpacity(0.08),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.primary, width: 1.5))),
                  child: Row(children: [
                    _hCell('TOPLAM (${employees.length} kisi)', 300, left: true),
                    _dCell(formatMoney(totalSalary), 90, bold: true),
                    _dCell(totalLeave > 0 ? '$totalLeave gun' : '—', 50, color: AppColors.accent, bold: true),
                    _dCell(totalDeduction > 0 ? formatMoney(totalDeduction) : '—', 80, bold: true),
                    _dCell(totalAdvance > 0 ? formatMoney(totalAdvance) : '—', 80, bold: true),
                    _dCell(formatMoney(totalMinWage), 90, bold: true),
                    _dCell(formatMoney(totalCash), 90, color: AppColors.success, bold: true),
                    _dCell(totalSgk > 0 ? formatMoney(totalSgk) : '—', 80, bold: true),
                    const SizedBox(width: 80),
                  ]),
                ),

                // Genel toplam
                Container(
                  color: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(children: [
                    const SizedBox(width: 300),
                    const SizedBox(width: 50 + 80 + 80), // izin+kesinti+avans
                    SizedBox(width: 90, child: Text('Asgari: ${formatMoney(totalMinWage)} TL',
                      style: const TextStyle(color: Colors.white70, fontSize: 11))),
                    SizedBox(width: 90, child: Text('Elden: ${formatMoney(totalCash)} TL',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13))),
                    SizedBox(width: 80, child: Text('SGK: ${formatMoney(totalSgk)} TL',
                      style: const TextStyle(color: Colors.white70, fontSize: 11))),
                    Expanded(child: Text(
                      'GENEL: ${formatMoney(totalMinWage + totalCash)} TL',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                      textAlign: TextAlign.right)),
                  ]),
                ),
              ]),
            ),
          ),
      ),
    ]);
  }

  Widget _hCell(String text, double w, {bool left = false}) => Container(
    width: w,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    alignment: left ? Alignment.centerLeft : Alignment.center,
    child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
  );

  Widget _dCell(String text, double w, {Color? color, bool bold = false}) => Container(
    width: w,
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
    alignment: Alignment.center,
    child: Text(text,
      style: TextStyle(
        color: color ?? AppColors.textDark,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
        fontSize: 12),
      overflow: TextOverflow.ellipsis),
  );
}

// ══════════════════════════════════════════════════════════════
//  DEPO MODELLERİ
// ══════════════════════════════════════════════════════════════

// ══════════════════════════════════════════════════════════════
//  DEPO MODELLERİ
// ══════════════════════════════════════════════════════════════

class GirisKaynagi {
  static const satin = 'satin';   // Satın alınan
  static const kutu  = 'kutu';    // Kendi kutusundan gelen
  static String label(String t) => t == 'kutu' ? 'Kutumdan Geldi' : 'Satın Alındı';
  static IconData icon(String t) => t == 'kutu' ? Icons.inventory_rounded : Icons.shopping_cart_rounded;
  static Color color(String t) => t == 'kutu' ? AppColors.accent : AppColors.success;
}

class StokGiris {
  String id, kaynak, tedarikci, belgeNo, not_;
  // kaynak: 'satin' | 'kutu'
  double miktar, birimFiyat, kdvOran;
  DateTime tarih;

  StokGiris({required this.id, required this.miktar, required this.tarih,
    this.kaynak = GirisKaynagi.satin,
    this.tedarikci = '', this.belgeNo = '', this.not_ = '',
    this.birimFiyat = 0, this.kdvOran = 18});

  double get kdvsizToplam => miktar * birimFiyat;
  double get kdvTutar => kdvsizToplam * (kdvOran / 100);
  double get kdvliToplam => kdvsizToplam + kdvTutar;
  bool get isSatin => kaynak == GirisKaynagi.satin;
  bool get isKutu => kaynak == GirisKaynagi.kutu;

  Map<String, dynamic> toJson() => {
    'id': id, 'kaynak': kaynak, 'tedarikci': tedarikci,
    'belgeNo': belgeNo, 'not_': not_,
    'miktar': miktar, 'birimFiyat': birimFiyat, 'kdvOran': kdvOran,
    'tarih': tarih.toIso8601String(),
  };
  factory StokGiris.fromJson(Map<String, dynamic> j) => StokGiris(
    id: j['id'] ?? '', kaynak: j['kaynak'] ?? GirisKaynagi.satin,
    tedarikci: j['tedarikci'] ?? '', belgeNo: j['belgeNo'] ?? '', not_: j['not_'] ?? '',
    miktar: (j['miktar'] as num).toDouble(),
    birimFiyat: (j['birimFiyat'] as num? ?? 0).toDouble(),
    kdvOran: (j['kdvOran'] as num? ?? 18).toDouble(),
    tarih: DateTime.parse(j['tarih']));
}

class StokCikis {
  String id, projeId, projeAdi, not_;
  double miktar;
  DateTime tarih;

  StokCikis({required this.id, required this.miktar, required this.tarih,
    this.projeId = '', this.projeAdi = '', this.not_ = ''});

  Map<String, dynamic> toJson() => {
    'id': id, 'projeId': projeId, 'projeAdi': projeAdi,
    'not_': not_, 'miktar': miktar, 'tarih': tarih.toIso8601String(),
  };
  factory StokCikis.fromJson(Map<String, dynamic> j) => StokCikis(
    id: j['id'] ?? '', projeId: j['projeId'] ?? '',
    projeAdi: j['projeAdi'] ?? '', not_: j['not_'] ?? '',
    miktar: (j['miktar'] as num).toDouble(),
    tarih: DateTime.parse(j['tarih']));
}

class StokItem {
  String id, ad, birim, kategori;
  double kritikSeviye;
  final List<StokGiris> girisler;
  final List<StokCikis> cikislar;

  StokItem({required this.id, required this.ad, required this.birim,
    this.kategori = '', this.kritikSeviye = 0,
    List<StokGiris>? girisler, List<StokCikis>? cikislar})
    : girisler = girisler ?? [], cikislar = cikislar ?? [];

  double get toplamGiris => girisler.fold(0, (s, g) => s + g.miktar);
  double get satinAlinan => girisler.where((g) => g.isSatin).fold(0, (s, g) => s + g.miktar);
  double get kutudanGelen => girisler.where((g) => g.isKutu).fold(0, (s, g) => s + g.miktar);
  double get toplamCikis => cikislar.fold(0, (s, c) => s + c.miktar);
  double get mevcutMiktar => math.max(0, toplamGiris - toplamCikis);
  double get toplamMaliyet => girisler.where((g) => g.isSatin).fold(0, (s, g) => s + g.kdvliToplam);
  double get ortalamaBirimFiyat => toplamGiris > 0
    ? girisler.where((g) => g.birimFiyat > 0).fold(0.0, (s, g) => s + g.birimFiyat) /
      math.max(1, girisler.where((g) => g.birimFiyat > 0).length)
    : 0;
  bool get kritikMi => kritikSeviye > 0 && mevcutMiktar <= kritikSeviye;

  Map<String, dynamic> toJson() => {
    'id': id, 'ad': ad, 'birim': birim, 'kategori': kategori,
    'kritikSeviye': kritikSeviye,
    'girisler': girisler.map((g) => g.toJson()).toList(),
    'cikislar': cikislar.map((c) => c.toJson()).toList(),
  };
  factory StokItem.fromJson(Map<String, dynamic> j) => StokItem(
    id: j['id'] ?? '', ad: j['ad'] ?? '', birim: j['birim'] ?? 'adet',
    kategori: j['kategori'] ?? '',
    kritikSeviye: (j['kritikSeviye'] as num? ?? 0).toDouble(),
    girisler: (j['girisler'] as List? ?? []).map((g) => StokGiris.fromJson(g)).toList(),
    cikislar: (j['cikislar'] as List? ?? []).map((c) => StokCikis.fromJson(c)).toList());
}

// ══════════════════════════════════════════════════════════════
//  DEPO SAYFASI
// ══════════════════════════════════════════════════════════════

class _DepoPage extends StatefulWidget {
  final List<ProjectData> projects;
  const _DepoPage({required this.projects});
  @override State<_DepoPage> createState() => _DepoPageState();
}

class _DepoPageState extends State<_DepoPage> {
  List<StokItem> _stok = [];
  String _search = '';

  @override
  void initState() { super.initState(); _stok = StorageService.loadDepo(); }
  void _save() => StorageService.saveDepo(_stok);

  List<StokItem> get _filtered => _stok.where((s) =>
    s.ad.toLowerCase().contains(_search.toLowerCase()) ||
    s.kategori.toLowerCase().contains(_search.toLowerCase())).toList();

  int get _kritikSayisi => _stok.where((s) => s.kritikMi).length;

  Future<void> _addItem() async {
    final result = await _showMalzemeDialog(context);
    if (result != null) { setState(() => _stok.add(result)); _save(); }
  }

  Future<void> _editItem(StokItem item) async {
    final result = await _showMalzemeDialog(context, existing: item);
    if (result != null) {
      setState(() { final i = _stok.indexOf(item); if (i >= 0) _stok[i] = result; });
      _save();
    }
  }

  Future<void> _deleteItem(StokItem item) async {
    final ok = await _confirm(context, 'Sil', '"${item.ad}" silinsin mi?');
    if (ok) { setState(() => _stok.remove(item)); _save(); }
  }

  Future<void> _openDetail(StokItem item) async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => _StokDetailPage(item: item, projects: widget.projects, onChanged: () { setState(() {}); _save(); })));
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Depo & Stok', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textDark)),
            Text(
              '${_stok.length} malzeme${_kritikSayisi > 0 ? " · $_kritikSayisi kritik!" : ""}',
              style: TextStyle(color: _kritikSayisi > 0 ? AppColors.danger : AppColors.textMid, fontSize: 12,
                fontWeight: _kritikSayisi > 0 ? FontWeight.w700 : FontWeight.normal)),
          ])),
          ElevatedButton.icon(onPressed: _addItem, icon: const Icon(Icons.add, size: 16), label: const Text('+ Malzeme')),
        ]),
        const SizedBox(height: 12),
        TextField(
          onChanged: (v) => setState(() => _search = v),
          decoration: InputDecoration(
            hintText: 'Malzeme ara...',
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textLight),
            suffixIcon: _search.isNotEmpty
              ? IconButton(icon: const Icon(Icons.close_rounded, size: 16), onPressed: () => setState(() => _search = ''))
              : null),
        ),
      ]),
    ),
    Expanded(
      child: _filtered.isEmpty
        ? _EmptyState(icon: Icons.warehouse_outlined,
            title: _stok.isEmpty ? 'Depo boş' : 'Sonuç yok',
            subtitle: _stok.isEmpty ? 'İlk malzemeyi ekleyin.' : '')
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _filtered.length,
            itemBuilder: (context, i) {
              final item = _filtered[i];
              final isKritik = item.kritikMi;
              final renk = isKritik ? AppColors.danger
                : item.mevcutMiktar == 0 ? AppColors.textLight : AppColors.success;
              return InkWell(
                onTap: () => _openDetail(item),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isKritik ? AppColors.danger.withOpacity(0.03) : AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isKritik ? AppColors.danger.withOpacity(0.3) : AppColors.border)),
                  child: Row(children: [
                    Container(width: 46, height: 46,
                      decoration: BoxDecoration(color: renk.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.inventory_2_rounded, color: renk, size: 24)),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(item.ad, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        if (isKritik) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                            child: const Text('KRİTİK', style: TextStyle(color: AppColors.danger, fontSize: 10, fontWeight: FontWeight.w800))),
                        ],
                      ]),
                      if (item.kategori.isNotEmpty)
                        Text(item.kategori, style: const TextStyle(color: AppColors.textMid, fontSize: 12)),
                      Text('${item.girisler.length} giriş · ${item.cikislar.length} çıkış',
                        style: const TextStyle(color: AppColors.textLight, fontSize: 11)),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('${item.mevcutMiktar}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: renk)),
                      Text(item.birim, style: const TextStyle(color: AppColors.textMid, fontSize: 12)),
                      if (item.toplamMaliyet > 0)
                        Text('${formatMoney(item.toplamMaliyet)} TL', style: const TextStyle(color: AppColors.textLight, fontSize: 11)),
                    ]),
                    PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'edit') _editItem(item);
                        else if (v == 'delete') _deleteItem(item);
                        else _openDetail(item);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'detail', child: Text('Detay / Hareketler')),
                        PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                        PopupMenuItem(value: 'delete', child: Text('Sil', style: TextStyle(color: AppColors.danger))),
                      ],
                    ),
                  ]),
                ),
              );
            }),
    ),
  ]);
}

// MALZEME DETAY SAYFASI
class _StokDetailPage extends StatefulWidget {
  final StokItem item;
  final List<ProjectData> projects;
  final VoidCallback onChanged;
  const _StokDetailPage({required this.item, required this.projects, required this.onChanged});
  @override State<_StokDetailPage> createState() => _StokDetailPageState();
}

class _StokDetailPageState extends State<_StokDetailPage> with SingleTickerProviderStateMixin {
  late TabController _tab;
  StokItem get item => widget.item;

  @override
  void initState() { super.initState(); _tab = TabController(length: 2, vsync: this); }
  @override void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _addGiris() async {
    final tedCtrl = TextEditingController();
    final belgeCtrl = TextEditingController();
    final miktarCtrl = TextEditingController();
    final fiyatCtrl = TextEditingController();
    final notCtrl = TextEditingController();
    double kdvOran = 18;
    DateTime tarih = DateTime.now();
    String kaynak = GirisKaynagi.satin;
    String odemeYontemi = 'nakit';

    final result = await showDialog<StokGiris>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) {
        final miktar = double.tryParse(miktarCtrl.text.replaceAll(',', '.')) ?? 0;
        final fiyat = parseTrMoney(fiyatCtrl.text);
        final kdvsiz = miktar * fiyat;
        final kdvTutar = kdvsiz * (kdvOran / 100);
        final kdvli = kdvsiz + kdvTutar;
        return AlertDialog(
          title: Text('Depo Girişi — ${item.ad}'),
          content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Mevcut stok
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: AppColors.success.withOpacity(0.07), borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Mevcut Stok:', style: TextStyle(color: AppColors.textMid)),
                Text('${item.mevcutMiktar} ${item.birim}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ]),
            ),
            const SizedBox(height: 14),
            // Kaynak seçimi
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => ss(() => kaynak = GirisKaynagi.satin),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kaynak == GirisKaynagi.satin ? AppColors.success.withOpacity(0.1) : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kaynak == GirisKaynagi.satin ? AppColors.success : AppColors.border)),
                  child: Column(children: [
                    Icon(Icons.shopping_cart_rounded,
                      color: kaynak == GirisKaynagi.satin ? AppColors.success : AppColors.textMid, size: 22),
                    const SizedBox(height: 6),
                    Text('Satın Alındı', style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 12,
                      color: kaynak == GirisKaynagi.satin ? AppColors.success : AppColors.textMid)),
                  ]),
                ),
              )),
              const SizedBox(width: 10),
              Expanded(child: GestureDetector(
                onTap: () => ss(() => kaynak = GirisKaynagi.kutu),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kaynak == GirisKaynagi.kutu ? AppColors.accent.withOpacity(0.1) : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kaynak == GirisKaynagi.kutu ? AppColors.accent : AppColors.border)),
                  child: Column(children: [
                    Icon(Icons.inventory_rounded,
                      color: kaynak == GirisKaynagi.kutu ? AppColors.accent : AppColors.textMid, size: 22),
                    const SizedBox(height: 6),
                    Text('Kutumdan Geldi', style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 12,
                      color: kaynak == GirisKaynagi.kutu ? AppColors.accent : AppColors.textMid)),
                  ]),
                ),
              )),
            ]),
            const SizedBox(height: 14),
            TextField(controller: tedCtrl,
              decoration: const InputDecoration(labelText: 'Tedarikçi / Satıcı', prefixIcon: Icon(Icons.store_outlined))),
            const SizedBox(height: 10),
            TextField(controller: belgeCtrl,
              decoration: const InputDecoration(labelText: 'Belge / Fatura No', prefixIcon: Icon(Icons.receipt_outlined))),
            const SizedBox(height: 10),
            TextField(
              controller: miktarCtrl, keyboardType: TextInputType.number, autofocus: true,
              onChanged: (_) => ss(() {}),
              decoration: InputDecoration(labelText: 'Giriş Miktarı (${item.birim}) *',
                prefixIcon: const Icon(Icons.add_rounded, color: AppColors.success))),
            const SizedBox(height: 10),
            TextField(
              controller: fiyatCtrl, keyboardType: TextInputType.number,
              onChanged: (_) => ss(() {}),
              decoration: const InputDecoration(labelText: 'Birim Fiyat (TL)',
                prefixIcon: Icon(Icons.attach_money_rounded))),
            const SizedBox(height: 10),
            if (kaynak == GirisKaynagi.satin)
            DropdownButtonFormField<double>(
              value: kdvOran,
              decoration: const InputDecoration(labelText: 'KDV Oranı'),
              items: const [
                DropdownMenuItem(value: 0, child: Text('KDV Yok')),
                DropdownMenuItem(value: 1, child: Text('%1')),
                DropdownMenuItem(value: 8, child: Text('%8')),
                DropdownMenuItem(value: 10, child: Text('%10')),
                DropdownMenuItem(value: 18, child: Text('%18')),
                DropdownMenuItem(value: 20, child: Text('%20')),
              ],
              onChanged: (v) => ss(() => kdvOran = v ?? 18),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => ss(() => odemeYontemi = 'nakit'),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: odemeYontemi == 'nakit' ? AppColors.success.withOpacity(0.1) : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: odemeYontemi == 'nakit' ? AppColors.success : AppColors.border)),
                  child: Column(children: [
                    Icon(Icons.payments_rounded, color: odemeYontemi == 'nakit' ? AppColors.success : AppColors.textMid, size: 18),
                    const SizedBox(height: 4),
                    Text('Nakit', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12,
                      color: odemeYontemi == 'nakit' ? AppColors.success : AppColors.textMid)),
                  ]),
                ),
              )),
              const SizedBox(width: 10),
              Expanded(child: GestureDetector(
                onTap: () => ss(() => odemeYontemi = 'cek'),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: odemeYontemi == 'cek' ? AppColors.primary.withOpacity(0.1) : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: odemeYontemi == 'cek' ? AppColors.primary : AppColors.border)),
                  child: Column(children: [
                    Icon(Icons.receipt_long_rounded, color: odemeYontemi == 'cek' ? AppColors.primary : AppColors.textMid, size: 18),
                    const SizedBox(height: 4),
                    Text('Çek', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12,
                      color: odemeYontemi == 'cek' ? AppColors.primary : AppColors.textMid)),
                  ]),
                ),
              )),
            ]),
            if (miktar > 0 && fiyat > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2))),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('KDV Hariç:', style: TextStyle(color: AppColors.textMid, fontSize: 12)),
                    Text('${formatMoney(kdvsiz)} TL', style: const TextStyle(fontSize: 12)),
                  ]),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('KDV (%${kdvOran.toStringAsFixed(0)}):', style: const TextStyle(color: AppColors.textMid, fontSize: 12)),
                    Text('${formatMoney(kdvTutar)} TL', style: const TextStyle(color: AppColors.accent, fontSize: 12)),
                  ]),
                  const Divider(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('KDV Dahil Toplam:', style: TextStyle(fontWeight: FontWeight.w700)),
                    Text('${formatMoney(kdvli)} TL',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary, fontSize: 15)),
                  ]),
                ]),
              ),
            ],
            const SizedBox(height: 10),
            _DateField(label: 'Tarih', date: tarih, onPicked: (d) => ss(() => tarih = d)),
            const SizedBox(height: 10),
            TextField(controller: notCtrl,
              decoration: const InputDecoration(labelText: 'Not', prefixIcon: Icon(Icons.notes_rounded))),
          ]))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              onPressed: () {
                final m = double.tryParse(miktarCtrl.text.replaceAll(',', '.')) ?? 0;
                if (m <= 0) return;
                Navigator.pop(ctx, StokGiris(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  miktar: m, tarih: tarih,
                  kaynak: kaynak,
                  tedarikci: tedCtrl.text.trim(),
                  belgeNo: belgeCtrl.text.trim(),
                  birimFiyat: kaynak == GirisKaynagi.satin ? parseTrMoney(fiyatCtrl.text) : 0,
                  kdvOran: kaynak == GirisKaynagi.satin ? kdvOran : 0,
                  not_: notCtrl.text.trim(),
                ));
              },
              child: const Text('Giriş Yap')),
          ],
        );
      }),
    );
    for (final c in [tedCtrl, belgeCtrl, miktarCtrl, fiyatCtrl, notCtrl]) c.dispose();
    if (result != null) { setState(() => item.girisler.add(result)); widget.onChanged(); }
  }

  Future<void> _addCikis(List<ProjectData> projects) async {
    final miktarCtrl = TextEditingController();
    final notCtrl = TextEditingController();
    String projeId = '';
    String projeAdi = '';
    DateTime tarih = DateTime.now();

    final result = await showDialog<StokCikis>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => AlertDialog(
        title: Text('Şantiyeye Çıkış — ${item.ad}'),
        content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.07), borderRadius: BorderRadius.circular(10)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Mevcut Stok:', style: TextStyle(color: AppColors.textMid)),
              Text('${item.mevcutMiktar} ${item.birim}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ]),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: projeId.isEmpty ? null : projeId,
            decoration: const InputDecoration(labelText: 'Gönderildiği Proje / Şantiye',
              prefixIcon: Icon(Icons.folder_outlined)),
            items: [const DropdownMenuItem(value: '', child: Text('Proje Seçme')),
              ...projects.map((p) => DropdownMenuItem(value: p.name, child: Text(p.name)))],
            onChanged: (v) => ss(() { projeId = v ?? ''; projeAdi = v ?? ''; }),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: miktarCtrl, keyboardType: TextInputType.number, autofocus: true,
            decoration: InputDecoration(
              labelText: 'Çıkış Miktarı (${item.birim}) *',
              prefixIcon: const Icon(Icons.remove_rounded, color: AppColors.danger))),
          const SizedBox(height: 10),
          _DateField(label: 'Tarih', date: tarih, onPicked: (d) => ss(() => tarih = d)),
          const SizedBox(height: 10),
          TextField(controller: notCtrl,
            decoration: const InputDecoration(labelText: 'Not', prefixIcon: Icon(Icons.notes_rounded))),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              final m = double.tryParse(miktarCtrl.text.replaceAll(',', '.')) ?? 0;
              if (m <= 0) return;
              if (m > item.mevcutMiktar) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Yetersiz stok!'), backgroundColor: AppColors.danger));
                return;
              }
              Navigator.pop(ctx, StokCikis(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                miktar: m, tarih: tarih,
                projeId: projeId, projeAdi: projeAdi,
                not_: notCtrl.text.trim(),
              ));
            },
            child: const Text('Çıkış Yap')),
        ],
      )),
    );
    miktarCtrl.dispose(); notCtrl.dispose();
    if (result != null) { setState(() => item.cikislar.add(result)); widget.onChanged(); }
  }

  @override
  Widget build(BuildContext context) {
    final renk = item.kritikMi ? AppColors.danger
      : item.mevcutMiktar == 0 ? AppColors.textLight : AppColors.success;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface, elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.ad, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textDark)),
          Text(item.kategori.isNotEmpty ? item.kategori : 'Depo', style: const TextStyle(fontSize: 12, color: AppColors.textMid)),
        ]),
      ),
      body: Column(children: [
        // ÖZET KART
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [renk, renk.withOpacity(0.7)]),
            borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.ad, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                Text('${item.birim} cinsinden stok', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Text('Mevcut Stok', style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text('${item.mevcutMiktar}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 28)),
                Text(item.birim, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ]),
            ]),
            const SizedBox(height: 14),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _ozet('Satın Alınan', '${item.satinAlinan} ${item.birim}', Icons.shopping_cart_rounded)),
              Container(width: 1, height: 32, color: Colors.white24),
              Expanded(child: _ozet('Kutumdan', '${item.kutudanGelen} ${item.birim}', Icons.inventory_rounded)),
              Container(width: 1, height: 32, color: Colors.white24),
              Expanded(child: _ozet('Çıkış', '${item.toplamCikis} ${item.birim}', Icons.remove_circle_rounded)),
            ]),
          ]),
        ),

        // SEKMELER
        Container(
          color: AppColors.surface,
          child: TabBar(
            controller: _tab,
            labelColor: AppColors.primary, unselectedLabelColor: AppColors.textMid, indicatorColor: AppColors.primary,
            tabs: [
              Tab(text: 'Girişler (${item.girisler.length})'),
              Tab(text: 'Çıkışlar (${item.cikislar.length})'),
            ]),
        ),
        Expanded(child: TabBarView(controller: _tab, children: [
          // GİRİŞLER
          _buildGirisler(),
          // ÇIKIŞLAR
          _buildCikislar(),
        ])),
      ]),
      floatingActionButton: Column(mainAxisSize: MainAxisSize.min, children: [
        FloatingActionButton.extended(
          heroTag: 'cikis',
          onPressed: () => _addCikis(widget.projects),
          backgroundColor: AppColors.danger,
          icon: const Icon(Icons.remove_rounded, color: Colors.white),
          label: const Text('Çıkış', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 10),
        FloatingActionButton.extended(
          heroTag: 'giris',
          onPressed: _addGiris,
          backgroundColor: AppColors.success,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text('Giriş', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  Widget _buildGirisler() {
    if (item.girisler.isEmpty)
      return const _EmptyState(icon: Icons.add_circle_outline, title: 'Giriş yok', subtitle: 'Sağ alttaki + butonuyla giriş yapın.');
    final sorted = [...item.girisler]..sort((a, b) => b.tarih.compareTo(a.tarih));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sorted.length,
      itemBuilder: (ctx, i) {
        final g = sorted[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.success.withOpacity(0.2))),
          child: Row(children: [
            const Icon(Icons.add_circle_rounded, color: AppColors.success, size: 22),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(formatDate(g.tarih), style: const TextStyle(color: AppColors.textMid, fontSize: 12)),
                if (g.belgeNo.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
                    child: Text(g.belgeNo, style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w700))),
                ],
              ]),
              if (g.tedarikci.isNotEmpty)
                Text(g.tedarikci, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              if (g.birimFiyat > 0)
                Text('${formatMoney(g.birimFiyat)} TL/birim | KDV Dahil: ${formatMoney(g.kdvliToplam)} TL',
                  style: const TextStyle(color: AppColors.textMid, fontSize: 11)),
              if (g.not_.isNotEmpty)
                Text(g.not_, style: const TextStyle(color: AppColors.textLight, fontSize: 11)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('+${g.miktar} ${item.birim}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.success)),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 18),
                onPressed: () async {
                  final ok = await _confirm(context, 'Sil', 'Bu giriş silinsin mi?');
                  if (ok) { setState(() => item.girisler.remove(g)); widget.onChanged(); }
                }),
            ]),
          ]),
        );
      },
    );
  }

  Widget _buildCikislar() {
    if (item.cikislar.isEmpty)
      return const _EmptyState(icon: Icons.remove_circle_outline, title: 'Çıkış yok', subtitle: 'Sağ alttaki - butonuyla çıkış yapın.');
    final sorted = [...item.cikislar]..sort((a, b) => b.tarih.compareTo(a.tarih));

    // Proje bazlı özet
    final projeOzet = <String, double>{};
    for (final c in item.cikislar) {
      if (c.projeAdi.isNotEmpty) projeOzet[c.projeAdi] = (projeOzet[c.projeAdi] ?? 0) + c.miktar;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Proje dağılımı
        if (projeOzet.isNotEmpty) ...[
          const Text('Proje Dağılımı', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textMid, fontSize: 13)),
          const SizedBox(height: 8),
          ...projeOzet.entries.map((e) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.primary.withOpacity(0.15))),
            child: Row(children: [
              const Icon(Icons.folder_outlined, color: AppColors.primary, size: 16),
              const SizedBox(width: 10),
              Expanded(child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600))),
              Text('${e.value} ${item.birim}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
            ]),
          )),
          const SizedBox(height: 16),
          const Text('Tüm Çıkışlar', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textMid, fontSize: 13)),
          const SizedBox(height: 8),
        ],
        ...sorted.map((c) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.danger.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.danger.withOpacity(0.2))),
          child: Row(children: [
            const Icon(Icons.remove_circle_rounded, color: AppColors.danger, size: 22),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(formatDate(c.tarih), style: const TextStyle(color: AppColors.textMid, fontSize: 12)),
              if (c.projeAdi.isNotEmpty)
                Row(children: [
                  const Icon(Icons.folder_outlined, size: 13, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(c.projeAdi, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 13)),
                ]),
              if (c.not_.isNotEmpty) Text(c.not_, style: const TextStyle(color: AppColors.textLight, fontSize: 11)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('-${c.miktar} ${item.birim}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.danger)),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 18),
                onPressed: () async {
                  final ok = await _confirm(context, 'Sil', 'Bu çıkış silinsin mi?');
                  if (ok) { setState(() => item.cikislar.remove(c)); widget.onChanged(); }
                }),
            ]),
          ]),
        )),
      ]),
    );
  }

  Widget _ozet(String label, String value, IconData icon) => Column(children: [
    Icon(icon, color: Colors.white70, size: 16),
    const SizedBox(height: 4),
    Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
      overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
    Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
  ]);
}

Future<StokItem?> _showMalzemeDialog(BuildContext context, {StokItem? existing}) async {
  final adCtrl = TextEditingController(text: existing?.ad ?? '');
  final kategoriCtrl = TextEditingController(text: existing?.kategori ?? '');
  final kritikCtrl = TextEditingController(text: existing != null && existing.kritikSeviye > 0 ? '${existing.kritikSeviye}' : '');
  String birim = existing?.birim ?? 'adet';
  const birimler = ['adet', 'kg', 'ton', 'litre', 'm2', 'm3', 'metre', 'kutu', 'paket', 'torba', 'çuval'];

  final result = await showDialog<StokItem>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => AlertDialog(
      title: Text(existing == null ? 'Yeni Malzeme' : 'Malzeme Düzenle'),
      content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: adCtrl, autofocus: true,
          decoration: const InputDecoration(labelText: 'Malzeme Adı *', prefixIcon: Icon(Icons.inventory_2_outlined))),
        const SizedBox(height: 10),
        TextField(controller: kategoriCtrl,
          decoration: const InputDecoration(labelText: 'Kategori', hintText: 'Yapı, Elektrik, Boya...',
            prefixIcon: Icon(Icons.category_outlined))),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: birim,
          decoration: const InputDecoration(labelText: 'Birim'),
          items: birimler.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
          onChanged: (v) => ss(() => birim = v!),
        ),
        const SizedBox(height: 10),
        TextField(controller: kritikCtrl, keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Kritik Stok Seviyesi (0 = takip yok)',
            prefixIcon: Icon(Icons.warning_amber_outlined))),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
        ElevatedButton(onPressed: () {
          if (adCtrl.text.trim().isEmpty) return;
          Navigator.pop(ctx, StokItem(
            id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
            ad: adCtrl.text.trim(), birim: birim,
            kategori: kategoriCtrl.text.trim(),
            kritikSeviye: double.tryParse(kritikCtrl.text) ?? 0,
            girisler: existing?.girisler ?? [],
            cikislar: existing?.cikislar ?? [],
          ));
        }, child: const Text('Kaydet')),
      ],
    )),
  );
  adCtrl.dispose(); kategoriCtrl.dispose(); kritikCtrl.dispose();
  return result;
}

class _ReportsPage extends StatelessWidget {
  final List<ProjectData> projects;
  const _ReportsPage({required this.projects});

  @override
  Widget build(BuildContext context) {
    final totalIncome = projects.fold<double>(0, (s, p) => s + p.totalIncome());
    final totalExpense = projects.fold<double>(0, (s, p) => s + p.totalExpense());
    final totalEmployees = projects.fold<int>(0, (s, p) => s + p.employees.length);
    final totalLeaves = projects.fold<int>(0, (s, p) => s + p.employees.fold(0, (a, e) => a + e.leaves.length));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Finansal Rapor', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.textDark)),
        const SizedBox(height: 4),
        const Text('Tüm projelerin özet analizi', style: TextStyle(color: AppColors.textMid)),
        const SizedBox(height: 24),
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth > 700 ? 4 : 2;
          return GridView.count(
            crossAxisCount: cols, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 1.6,
            children: [
              _KpiCard(label: 'Toplam Gelir', value: '${formatMoney(totalIncome)} ₺', icon: Icons.trending_up_rounded, color: AppColors.success),
              _KpiCard(label: 'Toplam Gider', value: '${formatMoney(totalExpense)} ₺', icon: Icons.trending_down_rounded, color: AppColors.danger),
              _KpiCard(label: 'Net Kar/Zarar', value: '${formatMoney(totalIncome - totalExpense)} ₺', icon: Icons.balance_rounded, color: AppColors.primary),
              _KpiCard(label: 'Proje Sayısı', value: '${projects.length}', icon: Icons.folder_rounded, color: AppColors.warning),
            ],
          );
        }),
        const SizedBox(height: 24),
        _InfoCard(title: 'Genel İstatistikler', children: [
          _InfoRow2(label: 'Toplam Personel', value: '$totalEmployees kişi'),
          _InfoRow2(label: 'Toplam İzin Kaydı', value: '$totalLeaves adet'),
          _InfoRow2(label: 'Aktif Proje', value: '${projects.where((p) => p.status == 'active').length} / ${projects.length}'),
          _InfoRow2(label: 'Personel Ödemeleri', value: '${formatMoney(projects.fold<double>(0, (s, p) => s + p.employees.fold(0.0, (a, e) => a + e.totalPaid())))} ₺'),
        ]),
        const SizedBox(height: 24),
        if (projects.isNotEmpty) ...[
          const Text('Proje Kar / Zarar Grafigi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ...projects.map((p) {
                final gelir = p.totalIncome();
                final gider = p.totalExpense();
                final kar = gelir - gider;
                final maxVal = projects.fold<double>(0, (m, pp) => math.max(m, math.max(pp.totalIncome(), pp.totalExpense())));
                final barMax = maxVal > 0 ? maxVal : 1;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13), overflow: TextOverflow.ellipsis)),
                      Text(kar >= 0 ? '+${formatMoney(kar)} ₺' : '${formatMoney(kar)} ₺',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: kar >= 0 ? AppColors.success : AppColors.danger)),
                    ]),
                    const SizedBox(height: 6),
                    // Gelir barı
                    Row(children: [
                      const SizedBox(width: 50, child: Text('Gelir', style: TextStyle(fontSize: 11, color: AppColors.textMid))),
                      Expanded(child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (gelir / barMax).clamp(0, 1),
                          backgroundColor: AppColors.border,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
                          minHeight: 10,
                        ),
                      )),
                      const SizedBox(width: 8),
                      SizedBox(width: 80, child: Text('${formatMoney(gelir)} ₺', style: const TextStyle(fontSize: 11, color: AppColors.success), textAlign: TextAlign.right)),
                    ]),
                    const SizedBox(height: 4),
                    // Gider barı
                    Row(children: [
                      const SizedBox(width: 50, child: Text('Gider', style: TextStyle(fontSize: 11, color: AppColors.textMid))),
                      Expanded(child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (gider / barMax).clamp(0, 1),
                          backgroundColor: AppColors.border,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.danger),
                          minHeight: 10,
                        ),
                      )),
                      const SizedBox(width: 8),
                      SizedBox(width: 80, child: Text('${formatMoney(gider)} ₺', style: const TextStyle(fontSize: 11, color: AppColors.danger), textAlign: TextAlign.right)),
                    ]),
                  ]),
                );
              }),
            ]),
          ),
          const SizedBox(height: 24),
          const Text('Proje Karlılık Analizi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          const SizedBox(height: 12),
          ...projects.map((p) {
            final bal = p.balance();
            final profitPct = p.totalIncome() > 0 ? (bal / p.totalIncome() * 100) : 0.0;
            final budgetPct = p.budget > 0 ? (p.totalExpense() / p.budget * 100).clamp(0, 999) : 0.0;
            final color = bal >= 0 ? AppColors.success : AppColors.danger;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                  _StatusBadge(status: p.status),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _MiniStat(label: 'Gelir', value: '${formatMoney(p.totalIncome())} ₺', color: AppColors.success)),
                  Expanded(child: _MiniStat(label: 'Gider', value: '${formatMoney(p.totalExpense())} ₺', color: AppColors.danger)),
                  Expanded(child: _MiniStat(label: 'Bakiye', value: '${formatMoney(bal)} ₺', color: color)),
                  Expanded(child: _MiniStat(label: 'Karlılık', value: '%${profitPct.toStringAsFixed(1)}', color: color)),
                ]),
                if (p.budget > 0) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: Text('Bütçe Kullanımı: %${budgetPct.toStringAsFixed(1)}', style: TextStyle(fontSize: 12, color: budgetPct > 100 ? AppColors.danger : AppColors.textMid, fontWeight: FontWeight.w600))),
                    Text('${formatMoney(p.totalExpense())} / ${formatMoney(p.budget)} ₺', style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
                  ]),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (budgetPct / 100).clamp(0, 1),
                      backgroundColor: AppColors.border,
                      valueColor: AlwaysStoppedAnimation<Color>(budgetPct > 100 ? AppColors.danger : budgetPct > 80 ? AppColors.warning : AppColors.success),
                      minHeight: 8,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(children: [
                  Icon(Icons.people_outlined, size: 14, color: AppColors.textLight),
                  const SizedBox(width: 4),
                  Text('${p.employees.length} personel', style: const TextStyle(fontSize: 12, color: AppColors.textMid)),
                  const SizedBox(width: 16),
                  Icon(Icons.layers_outlined, size: 14, color: AppColors.textLight),
                  const SizedBox(width: 4),
                  Text('${p.sections.length} bölüm', style: const TextStyle(fontSize: 12, color: AppColors.textMid)),
                  const Spacer(),
                  Text('${formatDate(p.startDate)} – ${formatDate(p.endDate)}', style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
                ]),
              ]),
            );
          }),
          const SizedBox(height: 24),
          const Text('Personel Maliyet Analizi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
            child: Column(children: [
              const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(children: [
                  Expanded(flex: 3, child: Text('Personel', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textMid, fontSize: 12))),
                  Expanded(flex: 2, child: Text('Proje', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textMid, fontSize: 12))),
                  Expanded(flex: 2, child: Text('Ödenen', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textMid, fontSize: 12), textAlign: TextAlign.right)),
                  Expanded(flex: 1, child: Text('Ay', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textMid, fontSize: 12), textAlign: TextAlign.right)),
                ])),
              const Divider(height: 1, color: AppColors.border),
              ...projects.expand((p) => p.employees.map((e) => Column(children: [
                Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(children: [
                    Expanded(flex: 3, child: Row(children: [
                      CircleAvatar(radius: 14, backgroundColor: AppColors.primary.withOpacity(0.1),
                        child: Text(e.name[0], style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 11))),
                      const SizedBox(width: 8),
                      Expanded(child: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis)),
                    ])),
                    Expanded(flex: 2, child: Text(p.name, style: const TextStyle(color: AppColors.textMid, fontSize: 12), overflow: TextOverflow.ellipsis)),
                    Expanded(flex: 2, child: Text('${formatMoney(e.totalPaid())} ₺', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13), textAlign: TextAlign.right)),
                    Expanded(flex: 1, child: Text('${e.paidMonthCount()}', style: const TextStyle(color: AppColors.textMid, fontSize: 12), textAlign: TextAlign.right)),
                  ])),
                const Divider(height: 1, indent: 16, color: AppColors.border),
              ]))).toList(),
            ]),
          ),
        ],
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  DIALOG YARDIMCILARI
// ══════════════════════════════════════════════════════════════

Future<bool> _confirm(BuildContext context, String title, String content) async {
  return await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Sil'),
        ),
      ],
    ),
  ) ?? false;
}

Future<ProjectData?> _showProjectDialog(BuildContext context, {ProjectData? existing}) async {
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final descCtrl = TextEditingController(text: existing?.description ?? '');
  final locationCtrl = TextEditingController(text: existing?.location ?? '');
  final clientCtrl = TextEditingController(text: existing?.client ?? '');
  DateTime start = existing?.startDate ?? DateTime.now();
  DateTime? end = existing?.endDate;
  String status = existing?.status ?? 'active';

  final result = await showDialog<ProjectData>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, ss) => AlertDialog(
        title: Text(existing == null ? 'Yeni Proje' : 'Projeyi Düzenle'),
        content: SizedBox(width: 440, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: 'Proje Adı *', prefixIcon: Icon(Icons.folder_rounded)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descCtrl,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Açıklama', prefixIcon: Icon(Icons.notes_rounded)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: clientCtrl,
            decoration: const InputDecoration(labelText: 'Müşteri / İşveren', prefixIcon: Icon(Icons.person_outline_rounded)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: locationCtrl,
            decoration: const InputDecoration(labelText: 'İş Yeri / Şantiye', prefixIcon: Icon(Icons.location_on_outlined)),
          ),
          const SizedBox(height: 12),
          _DateField(label: 'İşin Başlama Tarihi', date: start, onPicked: (d) => ss(() => start = d)),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: ctx,
                initialDate: end ?? DateTime.now().add(const Duration(days: 30)),
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) ss(() => end = picked);
            },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'İşin Bitiş Tarihi (isteğe bağlı)',
                prefixIcon: const Icon(Icons.calendar_today_rounded),
                suffixIcon: end != null
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 16),
                        onPressed: () => ss(() => end = null),
                      )
                    : null,
              ),
              child: Text(
                end != null ? formatDate(end!) : 'Seçilmedi',
                style: TextStyle(color: end != null ? AppColors.textDark : AppColors.textLight),
              ),
            ),
          ),
          if (end != null && end!.isBefore(start))
            const Padding(padding: EdgeInsets.only(top: 6),
              child: Text('⚠ Bitiş tarihi başlangıçtan önce olamaz', style: TextStyle(color: AppColors.danger, fontSize: 12))),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: status,
            decoration: const InputDecoration(labelText: 'Proje Durumu', prefixIcon: Icon(Icons.flag_outlined)),
            items: const [
              DropdownMenuItem(value: 'active', child: Text('Aktif — Devam Ediyor')),
              DropdownMenuItem(value: 'paused', child: Text('Beklemede — Durduruldu')),
              DropdownMenuItem(value: 'completed', child: Text('Tamamlandı')),
            ],
            onChanged: (v) => ss(() => status = v!),
          ),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(onPressed: () {
            if (nameCtrl.text.trim().isEmpty) return;
            if (end != null && end!.isBefore(start)) return;
            Navigator.pop(ctx, ProjectData(
              name: nameCtrl.text.trim(),
              description: descCtrl.text.trim(),
              client: clientCtrl.text.trim(),
              location: locationCtrl.text.trim(),
              startDate: start,
              endDate: end ?? start.add(const Duration(days: 365)),
              status: status,
            ));
          }, child: const Text('Kaydet')),
        ],
      ),
    ),
  );
  nameCtrl.dispose(); descCtrl.dispose(); locationCtrl.dispose(); clientCtrl.dispose();
  return result;
}

Future<IncomeEntry?> _showIncomeDialog(BuildContext context, {IncomeEntry? existing}) async {
  final fromCtrl = TextEditingController(text: existing?.from ?? '');
  final titleCtrl = TextEditingController(text: existing?.title ?? '');
  final amountCtrl = TextEditingController(text: existing != null ? formatMoney(existing.amount) : '');
  DateTime date = existing?.date ?? DateTime.now();

  final result = await showDialog<IncomeEntry>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, ss) => AlertDialog(
        title: Text(existing == null ? 'Gelir Ekle' : 'Gelir Düzenle'),
        content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: fromCtrl,
            decoration: const InputDecoration(
              labelText: 'Kimden *',
              hintText: 'Müşteri adı, firma...',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: titleCtrl,
            decoration: const InputDecoration(
              labelText: 'Açıklama',
              hintText: 'Hakediş, peşinat...',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
          const SizedBox(height: 12),
          _DateField(label: 'Tarih', date: date, onPicked: (d) => ss(() => date = d)),
          const SizedBox(height: 12),
          TextField(
            controller: amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Miktar (₺) *',
              hintText: '1.500,00',
              prefixIcon: Icon(Icons.attach_money_rounded),
            ),
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(onPressed: () {
            final from = fromCtrl.text.trim();
            final title = titleCtrl.text.trim();
            final amount = parseTrMoney(amountCtrl.text);
            if (from.isEmpty || amount <= 0) return;
            Navigator.pop(ctx, IncomeEntry(
              title: title.isNotEmpty ? title : from,
              amount: amount,
              date: date,
              from: from,
            ));
          }, child: const Text('Kaydet')),
        ],
      ),
    ),
  );
  fromCtrl.dispose(); titleCtrl.dispose(); amountCtrl.dispose();
  return result;
}

Future<AppSection?> _showSectionDialog(BuildContext context, {AppSection? existing}) async {
  final titleCtrl = TextEditingController(text: existing?.title ?? '');
  final companyCtrl = TextEditingController(text: existing?.companyTitle ?? '');
  final noteCtrl = TextEditingController(text: existing?.note ?? '');
  DateTime date = existing?.createdDate ?? DateTime.now();

  final result = await showDialog<AppSection>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, ss) => AlertDialog(
        title: Text(existing == null ? 'Yeni Gider Kategorisi' : 'Gider Kategorisini Düzenle'),
        content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: titleCtrl,
            decoration: const InputDecoration(
              labelText: 'Kategori Adı *',
              hintText: 'Malzeme, İşçilik, Ekipman...',
              prefixIcon: Icon(Icons.category_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: noteCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Açıklama',
              hintText: 'Bu kategoriye dair detay bilgisi...',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: companyCtrl,
            decoration: const InputDecoration(
              labelText: 'Ünvan / Firma (isteğe bağlı)',
              hintText: 'Taşeron, tedarikçi adı...',
              prefixIcon: Icon(Icons.business_outlined),
            ),
          ),
          const SizedBox(height: 12),
          _DateField(label: 'Tarih', date: date, onPicked: (d) => ss(() => date = d)),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(onPressed: () {
            if (titleCtrl.text.trim().isEmpty) return;
            Navigator.pop(ctx, AppSection(
              title: titleCtrl.text.trim(),
              companyTitle: companyCtrl.text.trim(),
              note: noteCtrl.text.trim(),
              createdDate: date,
            ));
          }, child: const Text('Kaydet')),
        ],
      ),
    ),
  );
  titleCtrl.dispose(); companyCtrl.dispose(); noteCtrl.dispose();
  return result;
}

Future<SectionEntry?> _showEntryDialog(BuildContext context, String sectionTitle, {SectionEntry? existing}) async {
  final titleCtrl = TextEditingController(text: existing?.title ?? '');
  final amountCtrl = TextEditingController(text: existing != null ? formatMoney(existing.amount) : '');
  final noteCtrl = TextEditingController(text: existing?.note ?? '');
  final invoiceCtrl = TextEditingController(text: existing?.invoiceNo ?? '');
  DateTime date = existing?.date ?? DateTime.now();
  String paymentType = existing?.paymentType ?? PaymentType.cash;

  final result = await showDialog<SectionEntry>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, ss) => AlertDialog(
        title: Text(existing == null ? '$sectionTitle – Kayıt Ekle' : 'Kaydı Düzenle'),
        content: SizedBox(width: 440, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: titleCtrl,
            decoration: const InputDecoration(
              labelText: 'Gider Adı / Başlık *',
              hintText: 'Beton, demir, işçilik...',
              prefixIcon: Icon(Icons.label_outline_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: noteCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Açıklama',
              hintText: 'Detay bilgisi...',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
          const SizedBox(height: 12),
          _DateField(label: 'Tarih', date: date, onPicked: (d) => ss(() => date = d)),
          const SizedBox(height: 12),
          TextField(
            controller: amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Toplam Tutar (₺) *',
              hintText: '1.500,00',
              prefixIcon: Icon(Icons.attach_money_rounded),
            ),
          ),
          const SizedBox(height: 14),
          // Ödeme tipi
          const Align(alignment: Alignment.centerLeft,
            child: Text('Ödeme / İşlem Tipi', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textMid))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              PaymentType.cash, PaymentType.check,
              PaymentType.note, PaymentType.debt, PaymentType.advance,
            ].map((t) => GestureDetector(
              onTap: () => ss(() => paymentType = t),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: paymentType == t ? AppColors.primary : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: paymentType == t ? AppColors.primary : AppColors.border),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(PaymentType.icon(t), size: 16, color: paymentType == t ? Colors.white : AppColors.textMid),
                  const SizedBox(width: 6),
                  Text(PaymentType.label(t), style: TextStyle(
                    color: paymentType == t ? Colors.white : AppColors.textDark,
                    fontWeight: paymentType == t ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                  )),
                ]),
              ),
            )).toList(),
          ),
          if (paymentType == PaymentType.cash) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.success.withOpacity(0.06), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.success.withOpacity(0.2))),
              child: const Row(children: [
                Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 16),
                SizedBox(width: 8),
                Text('Nakit — anında ödendi sayılır', style: TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
          ] else ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.06), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.warning.withOpacity(0.2))),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text('${PaymentType.label(paymentType)} — Gider kaydına ödemeler ayrıca işlenecek', style: const TextStyle(color: AppColors.warning, fontSize: 12, fontWeight: FontWeight.w600))),
              ]),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: invoiceCtrl,
            decoration: const InputDecoration(
              labelText: 'Fatura / Belge No (isteğe bağlı)',
              hintText: 'FAT-2024-001',
              prefixIcon: Icon(Icons.receipt_outlined),
            ),
          ),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(onPressed: () {
            final title = titleCtrl.text.trim();
            final amount = parseTrMoney(amountCtrl.text);
            if (title.isEmpty || amount <= 0) return;
            final entry = SectionEntry(
              title: title, amount: amount, date: date,
              note: noteCtrl.text.trim(), invoiceNo: invoiceCtrl.text.trim(),
              paymentType: paymentType,
              payments: existing?.payments ?? [],
            );
            // Nakit ise otomatik ödeme ekle
            if (paymentType == PaymentType.cash && (existing == null || existing.payments.isEmpty)) {
              entry.payments.add(EntryPayment(amount: amount, date: date, method: PaymentType.cash));
            }
            Navigator.pop(ctx, entry);
          }, child: const Text('Kaydet')),
        ],
      ),
    ),
  );
  titleCtrl.dispose(); amountCtrl.dispose(); noteCtrl.dispose(); invoiceCtrl.dispose();
  return result;
}

// EmployeeFormPage replaces the old dialog
class EmployeeFormPage extends StatefulWidget {
  final EmployeeData? existing;
  const EmployeeFormPage({super.key, this.existing});
  @override State<EmployeeFormPage> createState() => _EmployeeFormPageState();
}

class _EmployeeFormPageState extends State<EmployeeFormPage> {
  final _formKey = GlobalKey<FormState>();
  int _step = 0;

  // Kişisel
  late final TextEditingController _nameCtrl;
  late final TextEditingController _tcCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _ibanCtrl;
  late final TextEditingController _roleCtrl;
  DateTime? _birthDate;

  // Tarihler
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;

  // Maaş
  late final TextEditingController _salaryCtrl;
  late final TextEditingController _minimumWageCtrl;
  late final TextEditingController _advanceCtrl;
  late final TextEditingController _sgkCtrl;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _tcCtrl = TextEditingController(text: e?.tcNo ?? '');
    _phoneCtrl = TextEditingController(text: e?.phone ?? '');
    _ibanCtrl = TextEditingController(text: e?.iban ?? '');
    _roleCtrl = TextEditingController(text: e?.role ?? '');
    _birthDate = e?.birthDate;
    _startDate = e?.startDate ?? DateTime.now();
    _endDate = e?.endDate;
    _salaryCtrl = TextEditingController(text: e != null ? formatMoney(e.salary) : '');
    _minimumWageCtrl = TextEditingController(text: e != null ? formatMoney(e.minimumWage) : '');
    _advanceCtrl = TextEditingController(text: e != null ? formatMoney(e.advance) : '');
    _sgkCtrl = TextEditingController(text: e != null ? formatMoney(e.sgk) : '');
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _tcCtrl, _phoneCtrl, _ibanCtrl, _roleCtrl,
      _salaryCtrl, _minimumWageCtrl, _advanceCtrl, _sgkCtrl]) c.dispose();
    super.dispose();
  }

  // Hesaplanan elden
  double get _salary => parseTrMoney(_salaryCtrl.text);
  double get _minimumWage => parseTrMoney(_minimumWageCtrl.text);
  double get _advance => parseTrMoney(_advanceCtrl.text);
  double get _calculatedCash {
    final net = _salary - _minimumWage - _advance;
    return net < 0 ? 0 : net;
  }

  void _save() {
    if (_nameCtrl.text.trim().isEmpty) return;
    Navigator.pop(context, EmployeeData(
      name: _nameCtrl.text.trim(),
      role: _roleCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      tcNo: _tcCtrl.text.trim(),
      iban: _ibanCtrl.text.trim(),
      birthDate: _birthDate,
      startDate: _startDate,
      endDate: _endDate,
      salary: _salary,
      minimumWage: _minimumWage,
      advance: _advance,
      sgk: parseTrMoney(_sgkCtrl.text),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface, elevation: 0,
        title: Text(isNew ? 'Yeni Personel' : 'Personel Düzenle',
          style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textDark)),
        actions: [
          if (_step == 2)
            TextButton(onPressed: _save,
              child: const Text('Kaydet', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Adım göstergesi
            Row(children: List.generate(3, (i) {
              final labels = ['Kişisel Bilgiler', 'Çalışma Tarihleri', 'Maaş Bilgileri'];
              final active = _step == i;
              final done = _step > i;
              return Expanded(child: GestureDetector(
                onTap: () => setState(() => _step = i),
                child: Container(
                  margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : done ? AppColors.success.withOpacity(0.1) : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: active ? AppColors.primary : done ? AppColors.success : AppColors.border),
                  ),
                  child: Column(children: [
                    Container(width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: active ? Colors.white.withOpacity(0.2) : done ? AppColors.success : AppColors.bg,
                        shape: BoxShape.circle),
                      child: Center(child: done
                        ? const Icon(Icons.check_rounded, size: 16, color: AppColors.success)
                        : Text('${i+1}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13,
                            color: active ? Colors.white : AppColors.textMid)))),
                    const SizedBox(height: 6),
                    Text(labels[i], textAlign: TextAlign.center, style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: active ? Colors.white : done ? AppColors.success : AppColors.textMid)),
                  ]),
                ),
              ));
            })),

            const SizedBox(height: 24),

            // ── ADIM 0: KİŞİSEL ────────────────────────────────
            if (_step == 0) ...[
              _card(children: [
                TextFormField(
                  controller: _nameCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Ad Soyad *', prefixIcon: Icon(Icons.badge_rounded)),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Zorunlu alan' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _tcCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 11,
                  decoration: const InputDecoration(labelText: 'TC Kimlik No *', prefixIcon: Icon(Icons.credit_card_rounded), counterText: ''),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Zorunlu alan';
                    if (v.trim().length != 11) return '11 haneli olmalı';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _roleCtrl,
                  decoration: const InputDecoration(labelText: 'Görev / Unvan', prefixIcon: Icon(Icons.work_outline_rounded)),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Telefon', prefixIcon: Icon(Icons.phone_outlined)),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _ibanCtrl,
                  maxLength: 32,
                  onChanged: (v) {
                    // TR ile başlamazsa TR ekle, boşlukları 4'er grupla formatla
                    String raw = v.replaceAll(' ', '').toUpperCase();
                    if (raw.isNotEmpty && !raw.startsWith('TR')) raw = 'TR$raw';
                    // 4'er grupla formatla
                    final buffer = StringBuffer();
                    for (int i = 0; i < raw.length; i++) {
                      if (i > 0 && i % 4 == 0) buffer.write(' ');
                      buffer.write(raw[i]);
                    }
                    final formatted = buffer.toString();
                    if (formatted != v) {
                      _ibanCtrl.value = TextEditingValue(
                        text: formatted,
                        selection: TextSelection.collapsed(offset: formatted.length),
                      );
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: 'IBAN',
                    prefixIcon: Icon(Icons.account_balance_rounded),
                    hintText: 'TR00 0000 0000 0000 0000 0000 00',
                    helperText: '26 karakter (TR ile baslar)',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                // Doğum tarihi
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(context: context,
                      initialDate: _birthDate ?? DateTime(1990),
                      firstDate: DateTime(1940), lastDate: DateTime.now());
                    if (picked != null) setState(() => _birthDate = picked);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Doğum Tarihi',
                      prefixIcon: const Icon(Icons.cake_rounded),
                      suffixIcon: _birthDate != null
                        ? IconButton(icon: const Icon(Icons.close_rounded, size: 16),
                            onPressed: () => setState(() => _birthDate = null))
                        : null,
                    ),
                    child: Text(_birthDate != null ? formatDate(_birthDate!) : 'Seçiniz',
                      style: TextStyle(color: _birthDate != null ? AppColors.textDark : AppColors.textLight)),
                  ),
                ),
              ]),
              if (_nameCtrl.text.isNotEmpty) ...[
                const SizedBox(height: 16),
                Center(child: Column(children: [
                  CircleAvatar(radius: 36, backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: Text(_nameCtrl.text[0].toUpperCase(),
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.primary))),
                  const SizedBox(height: 8),
                  Text(_nameCtrl.text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  if (_roleCtrl.text.isNotEmpty)
                    Text(_roleCtrl.text, style: const TextStyle(color: AppColors.textMid)),
                ])),
              ],
              const SizedBox(height: 24),
              _nextBtn(() { if (_formKey.currentState?.validate() ?? false) setState(() => _step = 1); }),
            ],

            // ── ADIM 1: TARİHLER ────────────────────────────────
            if (_step == 1) ...[
              _card(children: [
                const Text('İşe Giriş Tarihi *', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textMid, fontSize: 13)),
                const SizedBox(height: 8),
                _bigDateBtn(context, _startDate, (d) => setState(() => _startDate = d), 'İşe Giriş'),
                const SizedBox(height: 20),
                Row(children: [
                  const Expanded(child: Text('İşten Çıkış Tarihi', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textMid, fontSize: 13))),
                  if (_endDate != null)
                    GestureDetector(
                      onTap: () => setState(() => _endDate = null),
                      child: const Text('Temizle', style: TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                ]),
                const SizedBox(height: 8),
                _bigDateBtn(context, _endDate, (d) => setState(() => _endDate = d), 'İşten Çıkış (isteğe bağlı)'),
              ]),
              const SizedBox(height: 14),
              // Çalışma süresi özeti
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  const Icon(Icons.timeline_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Çalışma Süresi', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text(
                      _endDate != null
                        ? '${_endDate!.difference(_startDate).inDays} gün'
                        : '${DateTime.now().difference(_startDate).inDays} gün (devam ediyor)',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                  ]),
                ]),
              ),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => setState(() => _step = 0), child: const Text('← Geri'))),
                const SizedBox(width: 12),
                Expanded(child: _nextBtn(() => setState(() => _step = 2))),
              ]),
            ],

            // ── ADIM 2: MAAŞ ────────────────────────────────────
            if (_step == 2) ...[
              // Giriş ayı bilgisi
              if (_startDate.day > 1) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.warning.withOpacity(0.3))),
                  child: Row(children: [
                    const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(
                      '${monthNameTr(_startDate.month)} ayında ${_startDate.day}. günden itibaren işe girdi. '
                      '${30 - _startDate.day + 1} gün çalışacak (30 gün üzerinden).',
                      style: const TextStyle(color: AppColors.warning, fontSize: 12, fontWeight: FontWeight.w600))),
                  ]),
                ),
                const SizedBox(height: 12),
              ],
              _card(children: [
                TextFormField(
                  controller: _salaryCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Aylık Maaş (₺) *',
                    prefixIcon: Icon(Icons.account_balance_wallet_rounded),
                    hintText: '80.000,00'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _minimumWageCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Asgari Ücret (₺)',
                    prefixIcon: Icon(Icons.money_outlined),
                    hintText: '22.104,00'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _advanceCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Avans (₺)',
                    prefixIcon: Icon(Icons.payments_outlined)),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _sgkCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'SGK (₺)',
                    prefixIcon: Icon(Icons.health_and_safety_outlined)),
                ),
              ]),
              const SizedBox(height: 14),

              // Otomatik hesaplama özeti
              if (_salary > 0) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border)),
                  child: Column(children: [
                    const Row(children: [
                      Icon(Icons.calculate_rounded, color: AppColors.primary, size: 18),
                      SizedBox(width: 8),
                      Text('Otomatik Hesaplama', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
                    ]),
                    const SizedBox(height: 12),
                    if (_startDate.day > 1) ...[
                      _calcRow('Günlük Maaş', '${formatMoney(_salary / 30)} ₺', AppColors.textMid),
                      _calcRow('Çalışılan Gün', '${30 - _startDate.day + 1} gün', AppColors.textMid),
                      _calcRow('${monthNameTr(_startDate.month)} Maaşı', '${formatMoney((_salary / 30) * (30 - _startDate.day + 1))} ₺', AppColors.primary),
                      const Divider(height: 16),
                    ],
                    _calcRow('Maaş', '${formatMoney(_salary)} ₺', AppColors.textDark),
                    _calcRow('- Asgari', '${formatMoney(_minimumWage)} ₺', AppColors.danger),
                    _calcRow('- Avans', '${formatMoney(_advance)} ₺', AppColors.danger),
                    const Divider(height: 16),
                    _calcRow('= Elden (Otomatik)', '${formatMoney(_calculatedCash)} ₺', AppColors.success, bold: true),
                    const Divider(height: 16),
                    _calcRow('SGK (Ayrıca)', '${formatMoney(parseTrMoney(_sgkCtrl.text))} ₺', AppColors.accent),
                  ]),
                ),
              ],

              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => setState(() => _step = 1), child: const Text('← Geri'))),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(isNew ? 'Personel Ekle' : 'Güncelle'),
                )),
              ]),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _calcRow(String label, String value, Color color, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Expanded(child: Text(label, style: TextStyle(color: AppColors.textMid, fontSize: 13))),
      Text(value, style: TextStyle(color: color, fontWeight: bold ? FontWeight.w900 : FontWeight.w600, fontSize: bold ? 15 : 13)),
    ]),
  );

  Widget _card({required List<Widget> children}) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
  );

  Widget _nextBtn(VoidCallback onTap) => ElevatedButton(
    onPressed: onTap,
    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('İleri'), SizedBox(width: 8), Icon(Icons.arrow_forward_rounded, size: 18),
    ]),
  );

  Widget _bigDateBtn(BuildContext context, DateTime? date, ValueChanged<DateTime> onPicked, String hint) =>
    InkWell(
      onTap: () async {
        final picked = await showDatePicker(context: context,
          initialDate: date ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
        if (picked != null) onPicked(picked);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: date != null ? AppColors.primary.withOpacity(0.05) : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: date != null ? AppColors.primary.withOpacity(0.3) : AppColors.border),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today_rounded, size: 18, color: date != null ? AppColors.primary : AppColors.textLight),
          const SizedBox(width: 12),
          Text(date != null ? formatDate(date) : hint,
            style: TextStyle(fontWeight: date != null ? FontWeight.w700 : FontWeight.w400,
              color: date != null ? AppColors.primary : AppColors.textLight, fontSize: 15)),
          const Spacer(),
          Icon(Icons.arrow_drop_down_rounded, color: date != null ? AppColors.primary : AppColors.textLight),
        ]),
      ),
    );
}


class _DateField extends StatefulWidget {
  final String label;
  final DateTime date;
  final ValueChanged<DateTime> onPicked;
  const _DateField({required this.label, required this.date, required this.onPicked});
  @override State<_DateField> createState() => _DateFieldState();
}

class _DateFieldState extends State<_DateField> {
  late final TextEditingController _ctrl;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _fmt(widget.date));
  }

  @override
  void didUpdateWidget(_DateField old) {
    super.didUpdateWidget(old);
    if (!_editing) _ctrl.text = _fmt(widget.date);
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  String _fmt(DateTime d) => '${d.day.toString().padLeft(2,'0')}.${d.month.toString().padLeft(2,'0')}.${d.year}';

  void _tryParse(String val) {
    final parts = val.split('.');
    if (parts.length == 3) {
      final d = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final y = int.tryParse(parts[2]);
      if (d != null && m != null && y != null &&
          d >= 1 && d <= 31 && m >= 1 && m <= 12 && y >= 2000 && y <= 2100) {
        try {
          final date = DateTime(y, m, d);
          widget.onPicked(date);
        } catch (_) {}
      }
    }
  }

  Future<void> _pickCalendar() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      widget.onPicked(picked);
      setState(() => _ctrl.text = _fmt(picked));
    }
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _ctrl,
    keyboardType: TextInputType.number,
    onTap: () => setState(() => _editing = true),
    onChanged: (v) => _tryParse(v),
    onEditingComplete: () {
      setState(() => _editing = false);
      _ctrl.text = _fmt(widget.date);
    },
    decoration: InputDecoration(
      labelText: widget.label,
      hintText: 'GG.AA.YYYY',
      prefixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
      suffixIcon: IconButton(
        icon: const Icon(Icons.calendar_month_rounded, color: AppColors.primary, size: 20),
        onPressed: _pickCalendar,
        tooltip: 'Takvimden seç',
      ),
    ),
  );
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _InfoCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textDark)),
      const SizedBox(height: 16),
      const Divider(height: 1, color: AppColors.border),
      const SizedBox(height: 12),
      ...children,
    ]),
  );
}

class _InfoRow2 extends StatelessWidget {
  final String label, value;
  const _InfoRow2({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      SizedBox(width: 130, child: Text(label, style: const TextStyle(color: AppColors.textMid, fontWeight: FontWeight.w500))),
      Expanded(child: Text(value, style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w600))),
    ]),
  );
}

class _EmptyCard extends StatelessWidget {
  final String text;
  const _EmptyCard({required this.text});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
    child: Text(text, style: const TextStyle(color: AppColors.textLight), textAlign: TextAlign.center),
  );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Widget? action;
  const _EmptyState({required this.icon, required this.title, required this.subtitle, this.action});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 80, height: 80,
        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(24)),
        child: Icon(icon, size: 40, color: AppColors.primary.withOpacity(0.5)),
      ),
      const SizedBox(height: 20),
      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
      const SizedBox(height: 8),
      Text(subtitle, style: const TextStyle(color: AppColors.textMid), textAlign: TextAlign.center),
      if (action != null) ...[const SizedBox(height: 20), action!],
    ]),
  );
}

// ══════════════════════════════════════════════════════════════
//  BÜTÇE & KDV KARTLARI
// ══════════════════════════════════════════════════════════════

class _BudgetCard extends StatelessWidget {
  final ProjectData project;
  const _BudgetCard({required this.project});

  @override
  Widget build(BuildContext context) {
    final pct = project.budgetUsagePercent();
    final over = project.isOverBudget;
    final color = over ? AppColors.danger : pct > 80 ? AppColors.warning : AppColors.success;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(over ? Icons.warning_rounded : Icons.flag_rounded, color: color, size: 20),
          const SizedBox(width: 10),
          Text(over ? 'Bütçe Aşıldı!' : 'Bütçe Durumu',
              style: TextStyle(fontWeight: FontWeight.w800, color: color)),
          const Spacer(),
          Text('%${pct.toStringAsFixed(1)}', style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 16)),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: (pct / 100).clamp(0, 1),
            backgroundColor: color.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 10,
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Harcanan', style: TextStyle(color: AppColors.textMid, fontSize: 12)),
            Text('${formatMoney(project.totalExpense())} ₺', style: TextStyle(fontWeight: FontWeight.w700, color: color)),
          ])),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text('Bütçe', style: TextStyle(color: AppColors.textMid, fontSize: 12)),
            Text('${formatMoney(project.budget)} ₺', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark)),
          ])),
        ]),
      ]),
    );
  }
}

class _KdvCard extends StatelessWidget {
  final ProjectData project;
  const _KdvCard({required this.project});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.accent.withOpacity(0.06),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.accent.withOpacity(0.3)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.percent_rounded, color: AppColors.accent, size: 20),
        const SizedBox(width: 10),
        Text('KDV Hesabı (%${project.kdvRate.toStringAsFixed(0)})', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.accent)),
      ]),
      const SizedBox(height: 12),
      _InfoRow2(label: 'Gelir (KDV Hariç)', value: '${formatMoney(project.totalIncome())} ₺'),
      _InfoRow2(label: 'KDV Tutarı', value: '${formatMoney(project.kdvAmount())} ₺'),
      _InfoRow2(label: 'Gelir (KDV Dahil)', value: '${formatMoney(project.incomeWithKdv())} ₺'),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════
//  AYARLAR SAYFASI
// ══════════════════════════════════════════════════════════════

class _SettingsPage extends StatefulWidget {
  final VoidCallback onChanged;
  const _SettingsPage({required this.onChanged});
  @override State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  late CompanyInfo _company;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _taxCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _addressCtrl;
  bool _edited = false;

  @override
  void initState() {
    super.initState();
    _company = StorageService.loadCompany();
    _nameCtrl    = TextEditingController(text: _company.name);
    _taxCtrl     = TextEditingController(text: _company.taxNo);
    _phoneCtrl   = TextEditingController(text: _company.phone);
    _emailCtrl   = TextEditingController(text: _company.email);
    _addressCtrl = TextEditingController(text: _company.address);
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _taxCtrl, _phoneCtrl, _emailCtrl, _addressCtrl]) c.dispose();
    super.dispose();
  }

  void _save() {
    final info = CompanyInfo(
      name: _nameCtrl.text.trim(),
      taxNo: _taxCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
    );
    StorageService.saveCompany(info);
    setState(() => _edited = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Şirket bilgileri kaydedildi'), backgroundColor: AppColors.success));
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final appState = EProjexApp.of(context);
    final isDark = appState?.isDark ?? false;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Ayarlar', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.textDark)),
        const SizedBox(height: 4),
        const Text('Uygulama ve şirket ayarları', style: TextStyle(color: AppColors.textMid)),
        const SizedBox(height: 28),

        // GÖRÜNÜM
        _SettingsSection(title: 'Görünüm', icon: Icons.palette_rounded, children: [
          Row(children: [
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Karanlık Mod', style: TextStyle(fontWeight: FontWeight.w700)),
              Text('Koyu renkli tema kullan', style: TextStyle(color: AppColors.textMid, fontSize: 12)),
            ])),
            Switch(
              value: isDark,
              onChanged: (_) { appState?.toggleDark(); setState(() {}); },
              activeColor: AppColors.primary,
            ),
          ]),
        ]),
        const SizedBox(height: 20),

        // ŞİRKET BİLGİLERİ
        _SettingsSection(title: 'Şirket Bilgileri', icon: Icons.business_rounded, children: [
          _settingsField(_nameCtrl, 'Şirket Adı', Icons.apartment_rounded),
          const SizedBox(height: 12),
          _settingsField(_taxCtrl, 'Vergi No', Icons.numbers_rounded),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _settingsField(_phoneCtrl, 'Telefon', Icons.phone_rounded)),
            const SizedBox(width: 12),
            Expanded(child: _settingsField(_emailCtrl, 'E-Posta', Icons.email_rounded)),
          ]),
          const SizedBox(height: 12),
          _settingsField(_addressCtrl, 'Adres', Icons.location_on_rounded),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Kaydet'),
            ),
          ),
        ]),
        const SizedBox(height: 20),

        // UYGULAMA BİLGİSİ
        _SettingsSection(title: 'Uygulama', icon: Icons.info_rounded, children: [
          _InfoRow2(label: 'Sürüm', value: 'e-Projex v1.0'),
          _InfoRow2(label: 'Platform', value: 'Web (Flutter)'),
          _InfoRow2(label: 'Depolama', value: 'Tarayıcı (localStorage)'),
        ]),
      ]),
    );
  }

  Widget _settingsField(TextEditingController ctrl, String label, IconData icon) => TextField(
    controller: ctrl,
    onChanged: (_) => setState(() => _edited = true),
    decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 20)),
  );
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _SettingsSection({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Theme.of(context).cardTheme.color ?? AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      ]),
      const SizedBox(height: 16),
      const Divider(height: 1, color: AppColors.border),
      const SizedBox(height: 16),
      ...children,
    ]),
  );
}

// ══════════════════════════════════════════════════════════════
//  PDF RAPOR ÇIKTISI — AYRI AYRI
// ══════════════════════════════════════════════════════════════

final _pdfBlue   = PdfColor.fromHex('1E40AF');
final _pdfGreen  = PdfColor.fromHex('10B981');
final _pdfRed    = PdfColor.fromHex('EF4444');
final _pdfGrey   = PdfColor.fromHex('94A3B8');
final _pdfDark   = PdfColor.fromHex('0F172A');
final _pdfBg     = PdfColor.fromHex('F0F4FF');
final _pdfCyan   = PdfColor.fromHex('06B6D4');

pw.Widget _pdfHeader(String title, String subtitle) => pw.Container(
  padding: const pw.EdgeInsets.all(18),
  decoration: pw.BoxDecoration(
    color: PdfColor.fromHex('1E40AF'),
    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
  ),
  child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text('e-Projex', style: pw.TextStyle(color: PdfColors.white, fontSize: 20, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      pw.Text(title, style: pw.TextStyle(color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold)),
      if (subtitle.isNotEmpty)
        pw.Text(subtitle, style: const pw.TextStyle(color: PdfColors.white, fontSize: 10)),
    ]),
    pw.Text(formatDate(DateTime.now()), style: const pw.TextStyle(color: PdfColors.white, fontSize: 9)),
  ]),
);

pw.Widget _pdfSection(String title) => pw.Padding(
  padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
  child: pw.Row(children: [
    pw.Container(width: 4, height: 14, color: PdfColor.fromHex('1E40AF')),
    pw.SizedBox(width: 8),
    pw.Text(title, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('1E40AF'))),
  ]),
);

pw.Widget _pdfRow(String label, String value) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(vertical: 3),
  child: pw.Row(children: [
    pw.SizedBox(width: 130, child: pw.Text(label, style: pw.TextStyle(color: PdfColor.fromHex('94A3B8'), fontSize: 10))),
    pw.Expanded(child: pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('0F172A')))),
  ]),
);

pw.Widget _pdfTable(List<String> headers, List<List<String>> rows, {List<double>? flex}) => pw.Table(
  columnWidths: flex != null ? {for (int i = 0; i < flex.length; i++) i: pw.FlexColumnWidth(flex[i])} : null,
  border: pw.TableBorder.all(color: PdfColor.fromHex('E2E8F0'), width: 0.5),
  children: [
    pw.TableRow(
      decoration: pw.BoxDecoration(color: PdfColor.fromHex('1E40AF')),
      children: headers.map((h) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: pw.Text(h, style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold)),
      )).toList(),
    ),
    ...rows.asMap().entries.map((e) => pw.TableRow(
      decoration: pw.BoxDecoration(color: e.key % 2 == 0 ? PdfColors.white : PdfColor.fromHex('F8FAFF')),
      children: e.value.map((c) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: pw.Text(c, style: const pw.TextStyle(fontSize: 8)),
      )).toList(),
    )),
  ],
);

pw.Widget _pdfStatRow(List<Map<String, dynamic>> stats) => pw.Row(
  children: stats.asMap().entries.map((entry) {
    final s = entry.value;
    return pw.Expanded(child: pw.Container(
      margin: pw.EdgeInsets.only(right: entry.key < stats.length - 1 ? 8 : 0),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: (s['bg'] as PdfColor),
        border: pw.Border.all(color: s['border'] as PdfColor, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(s['label'] as String, style: const pw.TextStyle(color: PdfColors.grey, fontSize: 8)),
        pw.SizedBox(height: 4),
        pw.Text(s['value'] as String, style: pw.TextStyle(color: s['color'] as PdfColor, fontSize: 9, fontWeight: pw.FontWeight.bold)),
      ]),
    ));
  }).toList(),
);

// ── 1. PROJE GENEL RAPORU ─────────────────────────────────────
// TL sembolü yerine TL yazısı kullan (font uyumu için)
String fmtPdf(double amount) => '${formatMoney(amount)} TL';

// Türkçe ay adı PDF uyumlu
String monthPdf(int m) => monthNameTr(m);

Future<void> exportProjectPdf(BuildContext context, ProjectData project) async {
  final company = StorageService.loadCompany();
  final font = await PdfGoogleFonts.notoSansRegular();
  final fontBold = await PdfGoogleFonts.notoSansBold();
  final pdf = pw.Document();

  pdf.addPage(pw.MultiPage(
    theme: pw.ThemeData.withFont(base: font, bold: fontBold),
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(28),
    footer: (ctx) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text('e-Projex${company.name.isNotEmpty && company.name != "Şirket Adı" ? " | ${company.name}" : ""}',
        style: pw.TextStyle(color: PdfColor.fromHex('94A3B8'), fontSize: 8)),
      pw.Text('Sayfa ${ctx.pageNumber} / ${ctx.pagesCount}',
        style: pw.TextStyle(color: PdfColor.fromHex('94A3B8'), fontSize: 8)),
    ]),
    build: (ctx) => [
      _pdfHeader('Proje Raporu', project.name),
      pw.SizedBox(height: 14),

      if (company.name.isNotEmpty && company.name != 'Şirket Adı')
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          margin: const pw.EdgeInsets.only(bottom: 10),
          decoration: pw.BoxDecoration(color: PdfColor.fromHex('F0F4FF'), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
          child: pw.Text('${company.name}${company.taxNo.isNotEmpty ? "   Vergi No: ${company.taxNo}" : ""}',
            style: const pw.TextStyle(fontSize: 9)),
        ),

      _pdfSection('Proje Bilgileri'),
      pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColor.fromHex('E2E8F0'), width: 0.5), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _pdfRow('Proje Adı', project.name),
          if (project.description.isNotEmpty) _pdfRow('Açıklama', project.description),
          _pdfRow('Başlangıç', formatDate(project.startDate)),
          _pdfRow('Bitiş', formatDate(project.endDate)),
          _pdfRow('Durum', project.status == 'active' ? 'Aktif' : project.status == 'completed' ? 'Tamamlandı' : 'Beklemede'),
          _pdfRow('Personel Sayısı', '${project.employees.length} kişi'),
          _pdfRow('Bölüm Sayısı', '${project.sections.length} adet'),
          if (project.budget > 0) _pdfRow('Bütçe Hedefi', '${formatMoney(project.budget)} TL'),
          if (project.kdvRate > 0) _pdfRow('KDV Oranı', '%${project.kdvRate.toStringAsFixed(0)}'),
        ]),
      ),

      _pdfSection('Finansal Özet'),
      _pdfStatRow([
        {'label': 'Toplam Gelir', 'value': '${formatMoney(project.totalIncome())} TL', 'color': PdfColor.fromHex('10B981'), 'bg': PdfColor.fromHex('F0FDF4'), 'border': PdfColor.fromHex('10B981')},
        {'label': 'Toplam Gider', 'value': '${formatMoney(project.totalExpense())} TL', 'color': PdfColor.fromHex('EF4444'), 'bg': PdfColor.fromHex('FFF1F2'), 'border': PdfColor.fromHex('EF4444')},
        {'label': 'Net Bakiye', 'value': '${formatMoney(project.balance())} TL', 'color': PdfColor.fromHex('1E40AF'), 'bg': PdfColor.fromHex('EFF6FF'), 'border': PdfColor.fromHex('1E40AF')},
      ]),

      if (project.kdvRate > 0) ...[
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(color: PdfColor.fromHex('F0FDFA'), border: pw.Border.all(color: PdfColor.fromHex('06B6D4'), width: 0.5), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('KDV Tutarı (%${project.kdvRate.toStringAsFixed(0)}): ${formatMoney(project.kdvAmount())} TL', style: const pw.TextStyle(fontSize: 9)),
            pw.Text('KDV Dahil: ${formatMoney(project.incomeWithKdv())} TL', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ]),
        ),
      ],

      if (project.incomeEntries.isNotEmpty) ...[
        _pdfSection('Gelir Kayıtları'),
        _pdfTable(
          ['Tarih', 'Açıklama', 'Kategori', 'Tutar'],
          project.incomeEntries.map((e) => [formatDate(e.date), e.title, e.category, '${formatMoney(e.amount)} TL']).toList(),
          flex: [1.5, 3, 1.5, 1.5],
        ),
        pw.SizedBox(height: 4),
        pw.Align(alignment: pw.Alignment.centerRight,
          child: pw.Text('Toplam Gelir: ${formatMoney(project.totalIncome())} TL',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColor.fromHex('10B981')))),
      ],

      if (project.sections.isNotEmpty) ...[
        _pdfSection('Gider Bölümleri Özeti'),
        _pdfTable(
          ['Bölüm', 'Ünvan', 'Kayıt Sayısı', 'Toplam'],
          project.sections.map((s) => [s.title, s.companyTitle.isEmpty ? '—' : s.companyTitle, '${s.entries.length}', '${formatMoney(s.total)} TL']).toList(),
          flex: [2, 2, 1, 1.5],
        ),
        pw.SizedBox(height: 4),
        pw.Align(alignment: pw.Alignment.centerRight,
          child: pw.Text('Toplam Gider: ${formatMoney(project.totalExpense())} TL',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColor.fromHex('EF4444')))),
      ],

      if (project.employees.isNotEmpty) ...[
        _pdfSection('Personel Özeti'),
        _pdfTable(
          ['Ad Soyad', 'Görev', 'Giriş Tarihi', 'Ödenen', 'Durum'],
          project.employees.map((e) => [
            e.name, e.role.isEmpty ? '—' : e.role,
            formatDate(e.startDate),
            '${formatMoney(e.totalPaid())} TL',
            e.hasExited ? 'Çıktı' : 'Aktif',
          ]).toList(),
          flex: [2, 1.5, 1.5, 1.5, 1],
        ),
      ],
    ],
  ));

  await Printing.layoutPdf(onLayout: (f) async => pdf.save());
}

// ── 2. BÖLÜM DETAY RAPORU ────────────────────────────────────
Future<void> exportSectionPdf(BuildContext context, AppSection section, String projectName) async {
  final company = StorageService.loadCompany();
  final font = await PdfGoogleFonts.notoSansRegular();
  final fontBold = await PdfGoogleFonts.notoSansBold();
  final pdf = pw.Document();

  pdf.addPage(pw.MultiPage(
    theme: pw.ThemeData.withFont(base: font, bold: fontBold),
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(28),
    footer: (ctx) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text('e-Projex | $projectName', style: pw.TextStyle(color: PdfColor.fromHex('94A3B8'), fontSize: 8)),
      pw.Text('Sayfa ${ctx.pageNumber} / ${ctx.pagesCount}', style: pw.TextStyle(color: PdfColor.fromHex('94A3B8'), fontSize: 8)),
    ]),
    build: (ctx) => [
      _pdfHeader('Bölüm Raporu', '${section.title} — $projectName'),
      pw.SizedBox(height: 14),

      _pdfSection('Bölüm Bilgileri'),
      pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColor.fromHex('E2E8F0'), width: 0.5), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _pdfRow('Kategori Adı', section.title),
          _pdfRow('Ünvan / Firma', section.companyTitle.isEmpty ? '—' : section.companyTitle),
          _pdfRow('Oluşturulma', formatDate(section.createdDate)),
          _pdfRow('Kayıt Sayısı', '${section.entries.length} adet'),
          _pdfRow('Proje', projectName),
        ]),
      ),

      _pdfSection('Finansal Özet'),
      _pdfStatRow([
        {'label': 'Toplam Gider', 'value': '${formatMoney(section.total)} TL', 'color': PdfColor.fromHex('EF4444'), 'bg': PdfColor.fromHex('FFF1F2'), 'border': PdfColor.fromHex('EF4444')},
        {'label': 'Kayıt Sayısı', 'value': '${section.entries.length}', 'color': PdfColor.fromHex('1E40AF'), 'bg': PdfColor.fromHex('EFF6FF'), 'border': PdfColor.fromHex('1E40AF')},
        {'label': 'Ortalama', 'value': section.entries.isEmpty ? '—' : '${formatMoney(section.total / section.entries.length)} TL', 'color': PdfColor.fromHex('F59E0B'), 'bg': PdfColor.fromHex('FFFBEB'), 'border': PdfColor.fromHex('F59E0B')},
      ]),

      if (section.entries.isNotEmpty) ...[
        _pdfSection('Kayıt Detayları'),
        _pdfTable(
          ['Tarih', 'Açıklama', 'Fatura No', 'Not', 'Tutar'],
          section.entries.map((e) => [
            formatDate(e.date), e.title,
            e.invoiceNo.isEmpty ? '—' : e.invoiceNo,
            e.note.isEmpty ? '—' : e.note,
            '${formatMoney(e.amount)} TL',
          ]).toList(),
          flex: [1.5, 2.5, 1.5, 2, 1.5],
        ),
        pw.SizedBox(height: 6),
        pw.Align(alignment: pw.Alignment.centerRight,
          child: pw.Text('TOPLAM: ${formatMoney(section.total)} TL',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColor.fromHex('EF4444')))),
      ] else
        pw.Center(child: pw.Padding(
          padding: const pw.EdgeInsets.all(20),
          child: pw.Text('Bu bölümde henüz kayıt yok.', style: pw.TextStyle(color: PdfColor.fromHex('94A3B8'))),
        )),
    ],
  ));

  await Printing.layoutPdf(onLayout: (f) async => pdf.save());
}

// ── 3. PERSONEL BORDRO RAPORU ─────────────────────────────────
Future<void> exportEmployeePdf(BuildContext context, EmployeeData employee, String projectName) async {
  final company = StorageService.loadCompany();
  final font = await PdfGoogleFonts.notoSansRegular();
  final fontBold = await PdfGoogleFonts.notoSansBold();
  final pdf = pw.Document();

  pdf.addPage(pw.MultiPage(
    theme: pw.ThemeData.withFont(base: font, bold: fontBold),
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(28),
    footer: (ctx) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text('e-Projex | $projectName${company.name.isNotEmpty && company.name != "Şirket Adı" ? " | ${company.name}" : ""}',
        style: pw.TextStyle(color: PdfColor.fromHex('94A3B8'), fontSize: 8)),
      pw.Text('Sayfa ${ctx.pageNumber} / ${ctx.pagesCount}', style: pw.TextStyle(color: PdfColor.fromHex('94A3B8'), fontSize: 8)),
    ]),
    build: (ctx) => [
      _pdfHeader('Personel Bordro Raporu', '${employee.name} — $projectName'),
      pw.SizedBox(height: 14),

      _pdfSection('Personel Bilgileri'),
      pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColor.fromHex('E2E8F0'), width: 0.5), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _pdfRow('Ad Soyad', employee.name),
          _pdfRow('Görev', employee.role.isEmpty ? '—' : employee.role),
          _pdfRow('Telefon', employee.phone.isEmpty ? '—' : employee.phone),
          _pdfRow('Proje', projectName),
          _pdfRow('İşe Giriş', formatDate(employee.startDate)),
          _pdfRow('İşten Çıkış', employee.endDate != null ? formatDate(employee.endDate!) : 'Devam ediyor'),
          _pdfRow('Durum', employee.hasExited ? 'İşten Ayrıldı' : 'Aktif'),
          _pdfRow('Aylık Maaş', '${formatMoney(employee.salary)} TL'),
          _pdfRow('SGK', '${formatMoney(employee.sgk)} TL'),
        ]),
      ),

      _pdfSection('Ödeme Özeti'),
      _pdfStatRow([
        {'label': 'Toplam Ödenen', 'value': '${formatMoney(employee.totalPaid())} TL', 'color': PdfColor.fromHex('1E40AF'), 'bg': PdfColor.fromHex('EFF6FF'), 'border': PdfColor.fromHex('1E40AF')},
        {'label': 'Ödenen Maaş', 'value': '${formatMoney(employee.totalPaidSalary())} TL', 'color': PdfColor.fromHex('10B981'), 'bg': PdfColor.fromHex('F0FDF4'), 'border': PdfColor.fromHex('10B981')},
        {'label': 'Ödenen SGK', 'value': '${formatMoney(employee.totalPaidSgk())} TL', 'color': PdfColor.fromHex('06B6D4'), 'bg': PdfColor.fromHex('F0FDFA'), 'border': PdfColor.fromHex('06B6D4')},
        {'label': 'Toplam Kesinti', 'value': '${formatMoney(employee.totalDeduction())} TL', 'color': PdfColor.fromHex('EF4444'), 'bg': PdfColor.fromHex('FFF1F2'), 'border': PdfColor.fromHex('EF4444')},
      ]),

      _pdfSection('Aylık Bordro Detayı'),
      _pdfTable(
        ['Ay / Yıl', 'Maaş', 'Avans', 'Asgari', 'Elden', 'SGK', 'Kesinti', 'NET'],
        employee.monthlyPayments.map((m) => [
          '${monthNameTr(m.month)} ${m.year}',
          m.salaryPaid ? '${formatMoney(m.salary)} TL' : '—',
          m.advancePaid ? '${formatMoney(m.advance)} TL' : '—',
          m.minimumWagePaid ? '${formatMoney(m.minimumWage)} TL' : '—',
          m.cashPaid ? '${formatMoney(m.calculatedCash)} TL' : '—',
          m.sgkPaid ? '${formatMoney(m.sgk)} TL' : '—',
          m.deduction > 0 ? '${formatMoney(m.deduction)} TL' : '—',
          m.totalPaid() > 0 ? '${formatMoney(m.totalPaid())} TL' : '—',
        ]).toList(),
        flex: [1.8, 1.1, 1.0, 1.0, 1.0, 1.0, 1.0, 1.1],
      ),
      pw.SizedBox(height: 6),
      pw.Align(alignment: pw.Alignment.centerRight,
        child: pw.Text('TOPLAM ÖDENEN: ${formatMoney(employee.totalPaid())} TL',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColor.fromHex('1E40AF')))),

      if (employee.leaves.isNotEmpty) ...[
        _pdfSection('İzin Kayıtları (${employee.leaves.length} adet)'),
        _pdfTable(
          ['Tarih', 'İzin Türü', 'Açıklama'],
          employee.leaves.map((l) => [formatDate(l.date), l.leaveType, l.note.isEmpty ? '—' : l.note]).toList(),
          flex: [1.5, 1.5, 3],
        ),
      ],
    ],
  ));

  await Printing.layoutPdf(onLayout: (f) async => pdf.save());
}


// ══════════════════════════════════════════════════════════════
//  E-FATURA SAYFASI
// ══════════════════════════════════════════════════════════════

class _InvoicesPage extends StatefulWidget {
  final List<ProjectData> projects;
  const _InvoicesPage({required this.projects});
  @override State<_InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<_InvoicesPage> with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<Invoice> _invoices = [];
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  String _selectedProject = 'Tümü';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _invoices = StorageService.loadInvoices();
  }
  @override void dispose() { _tab.dispose(); super.dispose(); }
  void _save() => StorageService.saveInvoices(_invoices);

  List<String> get _projectNames => ['Tümü', ...widget.projects.map((p) => p.name)];

  List<Invoice> get _filtered => _invoices.where((inv) {
    final monthMatch = inv.month == _selectedMonth && inv.year == _selectedYear;
    final projMatch = _selectedProject == 'Tümü' || inv.projectId == _selectedProject;
    return monthMatch && projMatch;
  }).toList();

  List<Invoice> get _incoming => _filtered.where((i) => i.isIncoming && i.isFatura).toList();
  List<Invoice> get _outgoing => _filtered.where((i) => i.isOutgoing && i.isFatura).toList();
  List<Invoice> get _receipts => _filtered.where((i) => i.isFis).toList();

  double _totalAmount(List<Invoice> list) => list.fold(0, (s, i) => s + i.total());
  double _totalKdv(List<Invoice> list) => list.fold(0, (s, i) => s + i.kdvAmount());

  Future<void> _add(String direction) async {
    final isReceipt = direction == 'receipt';
    final result = await Navigator.push<Invoice>(context,
      MaterialPageRoute(builder: (_) => InvoiceFormPage(
        direction: isReceipt ? 'incoming' : direction,
        docType: isReceipt ? 'receipt' : 'invoice',
        projects: widget.projects,
        initialMonth: _selectedMonth, initialYear: _selectedYear)));
    if (result != null) { setState(() => _invoices.add(result)); _save(); }
  }

  Future<void> _edit(Invoice inv) async {
    final result = await Navigator.push<Invoice>(context,
      MaterialPageRoute(builder: (_) => InvoiceFormPage(
        existing: inv, direction: inv.direction, projects: widget.projects,
        initialMonth: _selectedMonth, initialYear: _selectedYear)));
    if (result != null) {
      setState(() { final i = _invoices.indexOf(inv); if (i >= 0) _invoices[i] = result; });
      _save();
    }
  }

  Future<void> _delete(Invoice inv) async {
    final ok = await _confirm(context, 'Faturayı Sil', 'Bu fatura silinsin mi?');
    if (ok) { setState(() => _invoices.remove(inv)); _save(); }
  }

  void _togglePaid(Invoice inv) {
    setState(() {
      final i = _invoices.indexOf(inv);
      if (i >= 0) _invoices[i].status = inv.isPaid ? InvoiceStatus.unpaid : InvoiceStatus.paid;
    });
    _save();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    // BAŞLIK & FİLTRE
    Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(children: [
        Row(children: [
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('E-Fatura', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textDark)),
            Text('Gelen ve giden faturalar', style: TextStyle(color: AppColors.textMid, fontSize: 12)),
          ])),
        ]),
        const SizedBox(height: 12),
        // Ay/Yıl seçici
        Row(children: [
          Expanded(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
            child: DropdownButtonHideUnderline(child: DropdownButton<int>(
              value: _selectedMonth,
              items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(monthNameTr(i + 1)))),
              onChanged: (v) => setState(() => _selectedMonth = v!),
            )),
          )),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
            child: DropdownButtonHideUnderline(child: DropdownButton<int>(
              value: _selectedYear,
              items: [2024, 2025, 2026, 2027].map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
              onChanged: (v) => setState(() => _selectedYear = v!),
            )),
          ),
          const SizedBox(width: 8),
          Expanded(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
            child: DropdownButtonHideUnderline(child: DropdownButton<String>(
              value: _selectedProject,
              isExpanded: true,
              items: _projectNames.map((n) => DropdownMenuItem(value: n, child: Text(n, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) => setState(() => _selectedProject = v!),
            )),
          )),
        ]),
        const SizedBox(height: 10),
        TabBar(controller: _tab,
          labelColor: AppColors.primary, unselectedLabelColor: AppColors.textMid, indicatorColor: AppColors.primary,
          tabs: [
            Tab(text: 'Gelen Fatura (${_incoming.length})'),
            Tab(text: 'Giden Fatura (${_outgoing.length})'),
            Tab(text: 'Fis (${_receipts.length})'),
          ]),
      ]),
    ),

    Expanded(child: TabBarView(controller: _tab, children: [
      _buildList(_incoming, 'incoming'),
      _buildList(_outgoing, 'outgoing'),
      _buildList(_receipts, 'receipt'),
    ])),
  ]);

  Widget _buildList(List<Invoice> list, String direction) {
    final isReceipt = direction == 'receipt';
    final isIncoming = direction == 'incoming';
    final color = isReceipt ? AppColors.warning : isIncoming ? AppColors.success : AppColors.primary;
    return Column(children: [
      // TOPLAM ÖZET
      if (list.isNotEmpty)
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, color.withOpacity(0.75)]),
            borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${monthNameTr(_selectedMonth)} $_selectedYear',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  Text('${list.length} kayit', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  const Text('TOPLAM (KDV Dahil)', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  Text('${formatMoney(_totalAmount(list))} TL',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
                ]),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14))),
              child: Row(children: [
                Expanded(child: _sumItem('KDV Haric', _totalAmount(list) - _totalKdv(list), Colors.white)),
                Container(width: 1, height: 28, color: Colors.white30),
                Expanded(child: _sumItem('KDV Tutari', _totalKdv(list), Colors.white)),
                Container(width: 1, height: 28, color: Colors.white30),
                Expanded(child: _sumItem('KDV Dahil', _totalAmount(list), Colors.white, bold: true)),
              ]),
            ),
          ]),
        ),
      // Ekle butonu
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: Row(children: [
          Text(isReceipt ? 'Fisler' : isIncoming ? 'Gelen Faturalar' : 'Giden Faturalar',
            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textMid, fontSize: 13)),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () => _add(direction),
            icon: const Icon(Icons.add, size: 15),
            label: Text(isReceipt ? '+ Fis Ekle' : isIncoming ? '+ Gelen Fatura' : '+ Giden Fatura'),
            style: ElevatedButton.styleFrom(backgroundColor: color, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10))),
        ]),
      ),
      Expanded(
        child: list.isEmpty
          ? _EmptyState(icon: Icons.receipt_long_outlined,
              title: isReceipt ? 'Fis yok' : isIncoming ? 'Gelen fatura yok' : 'Giden fatura yok',
              subtitle: '+ butonu ile ekleyin.')
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final inv = list[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: inv.isPaid ? AppColors.success.withOpacity(0.3) : AppColors.border)),
                  child: Column(children: [
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        Container(width: 42, height: 42,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                          child: Icon(isIncoming ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                            color: color, size: 22)),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Text(inv.invoiceNo, style: const TextStyle(color: AppColors.textLight, fontSize: 11, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: (inv.isPaid ? AppColors.success : AppColors.warning).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6)),
                              child: Text(inv.isPaid ? 'Ödendi' : 'Ödenmedi',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                                  color: inv.isPaid ? AppColors.success : AppColors.warning))),
                          ]),
                          Text(inv.senderName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                          if (inv.senderTaxNo.isNotEmpty)
                            Text('VKN: ${inv.senderTaxNo}', style: const TextStyle(color: AppColors.textLight, fontSize: 11)),
                          Text(formatDate(inv.issueDate), style: const TextStyle(color: AppColors.textMid, fontSize: 12)),
                        ])),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('${formatMoney(inv.total())} TL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: color)),
                          Text('KDV: ${formatMoney(inv.kdvAmount())} TL', style: const TextStyle(color: AppColors.textLight, fontSize: 11)),
                        ]),
                        PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'edit') _edit(inv);
                            else if (v == 'delete') _delete(inv);
                            else if (v == 'paid') _togglePaid(inv);
                            // pdf desteği yakinda eklenecek
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                            PopupMenuItem(value: 'paid', child: Text(inv.isPaid ? 'Ödenmedi İşaretle' : 'Ödendi İşaretle',
                              style: TextStyle(color: inv.isPaid ? AppColors.warning : AppColors.success))),
                            const PopupMenuItem(value: 'pdf', child: Row(children: [
                              Icon(Icons.picture_as_pdf_rounded, size: 16, color: AppColors.danger),
                              SizedBox(width: 8), Text('PDF Oluştur')])),
                            const PopupMenuItem(value: 'delete', child: Text('Sil', style: TextStyle(color: AppColors.danger))),
                          ],
                        ),
                      ]),
                    ),
                    // Kalemler
                    if (inv.items.isNotEmpty) ...[
                      const Divider(height: 1, color: AppColors.border),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                        child: Column(children: [
                          ...inv.items.map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(children: [
                              Expanded(child: Text(item.description, style: const TextStyle(fontSize: 12))),
                              Text('${item.quantity} x ${formatMoney(item.unitPrice)} TL', style: const TextStyle(color: AppColors.textMid, fontSize: 11)),
                              const SizedBox(width: 8),
                              Text('KDV%${item.kdvRate.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.textLight, fontSize: 10)),
                              const SizedBox(width: 8),
                              Text('${formatMoney(item.total)} TL', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                            ]),
                          )),
                        ]),
                      ),
                    ],
                  ]),
                );
              },
            ),
      ),
    ]);
  }

  Widget _sumItem(String label, double amount, Color color, {bool bold = false}) => Column(children: [
    Text(label, style: TextStyle(color: color.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.w600)),
    Text('${formatMoney(amount)} TL', style: TextStyle(color: color, fontWeight: bold ? FontWeight.w900 : FontWeight.w700, fontSize: bold ? 14 : 12)),
  ]);
}

// FATURA FORM SAYFASI
class InvoiceFormPage extends StatefulWidget {
  final Invoice? existing;
  final String direction;
  final String docType;
  final List<ProjectData> projects;
  final int initialMonth, initialYear;
  const InvoiceFormPage({super.key, this.existing, required this.direction,
    this.docType = 'invoice',
    required this.projects, required this.initialMonth, required this.initialYear});
  @override State<InvoiceFormPage> createState() => _InvoiceFormPageState();
}

class _InvoiceFormPageState extends State<InvoiceFormPage> {
  late final TextEditingController _senderCtrl;
  late final TextEditingController _taxCtrl;
  late final TextEditingController _noteCtrl;
  final List<InvoiceItem> _items = [];
  late int _month, _year;
  late DateTime _issueDate;
  String _status = InvoiceStatus.unpaid;
  String _projectId = '';

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _senderCtrl = TextEditingController(text: e?.senderName ?? '');
    _taxCtrl = TextEditingController(text: e?.senderTaxNo ?? '');
    _noteCtrl = TextEditingController(text: e?.note ?? '');
    _month = e?.month ?? widget.initialMonth;
    _year = e?.year ?? widget.initialYear;
    _issueDate = e?.issueDate ?? DateTime.now();
    _status = e?.status ?? InvoiceStatus.unpaid;
    _projectId = e?.projectId ?? '';
    if (e != null) _items.addAll(e.items.map((i) => InvoiceItem(description: i.description, quantity: i.quantity, unitPrice: i.unitPrice, kdvRate: i.kdvRate)));
  }

  @override
  void dispose() { for (final c in [_senderCtrl, _taxCtrl, _noteCtrl]) c.dispose(); super.dispose(); }

  double get _subtotal => _items.fold(0, (s, i) => s + i.subtotal);
  double get _totalKdv => _items.fold(0, (s, i) => s + i.kdvAmount);
  double get _total => _subtotal + _totalKdv;

  bool get isIncoming => widget.direction == 'incoming';
  bool get isFis => (widget.existing?.docType ?? widget.docType) == 'receipt';

  Future<void> _addItem() async {
    final descCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController();
    double kdvRate = 18;

    final result = await showDialog<InvoiceItem>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => AlertDialog(
        title: const Text('Kalem Ekle'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: descCtrl, autofocus: true,
            decoration: const InputDecoration(labelText: 'Açıklama / Ürün *')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: qtyCtrl, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Miktar'))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: priceCtrl, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Birim Fiyat (₺)'))),
          ]),
          const SizedBox(height: 10),
          DropdownButtonFormField<double>(
            value: kdvRate,
            decoration: const InputDecoration(labelText: 'KDV Oranı'),
            items: const [
              DropdownMenuItem(value: 0, child: Text('KDV Yok')),
              DropdownMenuItem(value: 1, child: Text('%1')),
              DropdownMenuItem(value: 8, child: Text('%8')),
              DropdownMenuItem(value: 10, child: Text('%10')),
              DropdownMenuItem(value: 18, child: Text('%18')),
              DropdownMenuItem(value: 20, child: Text('%20')),
            ],
            onChanged: (v) => ss(() => kdvRate = v ?? 18),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(onPressed: () {
            if (descCtrl.text.trim().isEmpty) return;
            final price = parseTrMoney(priceCtrl.text);
            Navigator.pop(ctx, InvoiceItem(
              description: descCtrl.text.trim(),
              quantity: double.tryParse(qtyCtrl.text) ?? 1,
              unitPrice: price, kdvRate: kdvRate));
          }, child: const Text('Ekle')),
        ],
      )),
    );
    descCtrl.dispose(); qtyCtrl.dispose(); priceCtrl.dispose();
    if (result != null) setState(() => _items.add(result));
  }

  void _save() {
    if (_senderCtrl.text.trim().isEmpty) return;
    Navigator.pop(context, Invoice(
      id: widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      direction: widget.direction,
      docType: widget.existing?.docType ?? widget.docType,
      senderName: _senderCtrl.text.trim(),
      senderTaxNo: _taxCtrl.text.trim(),
      note: _noteCtrl.text.trim(),
      status: _status,
      projectId: _projectId,
      month: _month, year: _year,
      issueDate: _issueDate,
      items: _items,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final color = isIncoming ? AppColors.success : AppColors.primary;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface, elevation: 0,
        title: Text(widget.existing == null
          ? (isFis ? 'Fis Ekle' : isIncoming ? 'Gelen Fatura Ekle' : 'Giden Fatura Ekle')
          : (isFis ? 'Fis Düzenle' : 'Fatura Düzenle'),
          style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textDark)),
        actions: [
          TextButton(onPressed: _save,
            child: const Text('Kaydet', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Yön etiketi
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
              borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Icon(isIncoming ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Text(isIncoming ? 'GELEN FATURA' : 'GİDEN FATURA',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16,
                  letterSpacing: 1)),
            ]),
          ),
          const SizedBox(height: 16),

          // Temel bilgiler
          _card(children: [
            Text(isFis ? 'Harcama Yeri' : isIncoming ? 'Gönderen Bilgileri' : 'Alıcı / Müşteri Bilgileri',
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textMid, fontSize: 13)),
            const SizedBox(height: 10),
            TextField(controller: _senderCtrl, onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: isFis ? 'Dukkân / Magaza Adı *' : isIncoming ? 'Gönderen Firma / Kişi *' : 'Alıcı Firma / Kişi *',
                prefixIcon: const Icon(Icons.business_rounded))),
            const SizedBox(height: 10),
            TextField(controller: _taxCtrl,
              decoration: const InputDecoration(labelText: 'Vergi No', prefixIcon: Icon(Icons.numbers_rounded))),
          ]),
          const SizedBox(height: 14),

          // Tarih & dönem
          _card(children: [
            const Text('Tarih & Dönem', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textMid, fontSize: 13)),
            const SizedBox(height: 10),
            _DateField(label: 'Fatura Tarihi', date: _issueDate, onPicked: (d) => setState(() => _issueDate = d)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                child: DropdownButtonHideUnderline(child: DropdownButton<int>(
                  value: _month,
                  items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(monthNameTr(i + 1)))),
                  onChanged: (v) => setState(() => _month = v!),
                )),
              )),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                child: DropdownButtonHideUnderline(child: DropdownButton<int>(
                  value: _year,
                  items: [2024, 2025, 2026, 2027].map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                  onChanged: (v) => setState(() => _year = v!),
                )),
              ),
            ]),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _projectId.isEmpty ? null : _projectId,
              decoration: const InputDecoration(labelText: 'İlgili Proje'),
              items: [const DropdownMenuItem(value: '', child: Text('Proje Seçme')),
                ...widget.projects.map((p) => DropdownMenuItem(value: p.name, child: Text(p.name)))],
              onChanged: (v) => setState(() => _projectId = v ?? ''),
            ),
          ]),
          const SizedBox(height: 14),

          // Kalemler
          Row(children: [
            const Expanded(child: Text('Fatura Kalemleri',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textDark))),
            ElevatedButton.icon(onPressed: _addItem, icon: const Icon(Icons.add, size: 15),
              label: const Text('+ Kalem'), style: ElevatedButton.styleFrom(backgroundColor: color)),
          ]),
          const SizedBox(height: 10),
          if (_items.isEmpty)
            _EmptyCard(text: 'Kalem eklenmedi')
          else
            Container(
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
              child: Column(children: [
                // Başlık
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: const BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
                  child: const Row(children: [
                    Expanded(flex: 3, child: Text('Açıklama', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMid))),
                    Expanded(flex: 1, child: Text('Miktar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMid), textAlign: TextAlign.center)),
                    Expanded(flex: 2, child: Text('Birim Fiyat', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMid), textAlign: TextAlign.right)),
                    Expanded(flex: 1, child: Text('KDV%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMid), textAlign: TextAlign.center)),
                    Expanded(flex: 2, child: Text('Toplam', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMid), textAlign: TextAlign.right)),
                    SizedBox(width: 32),
                  ]),
                ),
                ..._items.asMap().entries.map((e) => Column(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(children: [
                      Expanded(flex: 3, child: Text(e.value.description, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                      Expanded(flex: 1, child: Text('${e.value.quantity}', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMid, fontSize: 12))),
                      Expanded(flex: 2, child: Text('${formatMoney(e.value.unitPrice)} TL', textAlign: TextAlign.right, style: const TextStyle(color: AppColors.textMid, fontSize: 12))),
                      Expanded(flex: 1, child: Text('%${e.value.kdvRate.toStringAsFixed(0)}', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.accent, fontSize: 12))),
                      Expanded(flex: 2, child: Text('${formatMoney(e.value.total)} TL', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                      IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 18),
                        onPressed: () => setState(() => _items.removeAt(e.key))),
                    ]),
                  ),
                  if (e.key < _items.length - 1) const Divider(height: 1, indent: 14, color: AppColors.border),
                ])),
                // Toplam
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.vertical(bottom: Radius.circular(14))),
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('KDV Hariç:', style: TextStyle(color: AppColors.textMid)),
                      Text('${formatMoney(_subtotal)} TL'),
                    ]),
                    const SizedBox(height: 4),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('KDV:', style: TextStyle(color: AppColors.accent)),
                      Text('${formatMoney(_totalKdv)} TL', style: const TextStyle(color: AppColors.accent)),
                    ]),
                    const Divider(height: 12),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('TOPLAM', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      Text('${formatMoney(_total)} TL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: color)),
                    ]),
                  ]),
                ),
              ]),
            ),
          const SizedBox(height: 14),
          _card(children: [
            TextField(controller: _noteCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Not', border: InputBorder.none)),
          ]),
          const SizedBox(height: 80),
        ]),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _save,
        backgroundColor: color,
        icon: const Icon(Icons.save_rounded, color: Colors.white),
        label: const Text('Kaydet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _card({required List<Widget> children}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
  );
}

class _ChecksPage extends StatefulWidget {
  final List<ProjectData> projects;
  const _ChecksPage({required this.projects});
  @override State<_ChecksPage> createState() => _ChecksPageState();
}

class _ChecksPageState extends State<_ChecksPage> with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<CheckRecord> _checks = [];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _checks = StorageService.loadChecks();
  }
  @override void dispose() { _tab.dispose(); super.dispose(); }
  void _save() => StorageService.saveChecks(_checks);

  List<CheckRecord> get _pending => _checks.where((c) => c.isPending && !c.isOverdue).toList()
    ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  List<CheckRecord> get _overdue => _checks.where((c) => c.isOverdue).toList()
    ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  List<CheckRecord> get _completed => _checks.where((c) => !c.isPending).toList()
    ..sort((a, b) => b.dueDate.compareTo(a.dueDate));

  double _total(List<CheckRecord> list) => list.fold(0, (s, c) => s + c.amount);

  Future<void> _add() async {
    final result = await _showCheckDialog(context, projects: widget.projects);
    if (result != null) { setState(() => _checks.add(result)); _save(); }
  }

  Future<void> _edit(CheckRecord c) async {
    final result = await _showCheckDialog(context, existing: c, projects: widget.projects);
    if (result != null) {
      setState(() { final i = _checks.indexOf(c); if (i >= 0) _checks[i] = result; });
      _save();
    }
  }

  Future<void> _delete(CheckRecord c) async {
    final ok = await _confirm(context, 'Sil', 'Bu kayıt silinsin mi?');
    if (ok) { setState(() => _checks.remove(c)); _save(); }
  }

  void _updateStatus(CheckRecord c, String status) {
    setState(() { final i = _checks.indexOf(c); if (i >= 0) _checks[i].status = status; });
    _save();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(children: [
        Row(children: [
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Çek & Senet Takibi', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textDark)),
            Text('Verilen çek ve senetleri takip edin', style: TextStyle(color: AppColors.textMid, fontSize: 13)),
          ])),
          ElevatedButton.icon(onPressed: _add, icon: const Icon(Icons.add, size: 16), label: const Text('+ Ekle')),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _statCard('Bekleyen', _pending.length, _total(_pending), AppColors.warning)),
          const SizedBox(width: 10),
          Expanded(child: _statCard('Vadesi Geçmiş', _overdue.length, _total(_overdue), AppColors.danger)),
          const SizedBox(width: 10),
          Expanded(child: _statCard('Tamamlanan', _completed.length, _total(_completed), AppColors.success)),
        ]),
        const SizedBox(height: 10),
        TabBar(controller: _tab,
          labelColor: AppColors.primary, unselectedLabelColor: AppColors.textMid, indicatorColor: AppColors.primary,
          tabs: [
            Tab(text: 'Bekleyen (${_pending.length})'),
            Tab(text: 'Vadesi Geçmiş (${_overdue.length})'),
            Tab(text: 'Tamamlanan (${_completed.length})'),
          ]),
      ]),
    ),
    Expanded(child: TabBarView(controller: _tab, children: [
      _buildList(_pending),
      _buildList(_overdue),
      _buildList(_completed),
    ])),
  ]);

  Widget _statCard(String label, int count, double total, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      Text('$count adet', style: TextStyle(color: color, fontSize: 12)),
      Text('${formatMoney(total)} TL', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14)),
    ]),
  );

  Widget _buildList(List<CheckRecord> list) {
    if (list.isEmpty) return const _EmptyState(icon: Icons.account_balance_outlined, title: 'Kayıt yok', subtitle: '');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final c = list[i];
        final isOverdue = c.isOverdue;
        final statusColor = c.status == CheckStatus.cashed ? AppColors.success
          : c.status == CheckStatus.bounced ? AppColors.danger
          : isOverdue ? AppColors.danger : AppColors.warning;
        final statusLabel = c.status == CheckStatus.cashed ? 'Tahsil Edildi'
          : c.status == CheckStatus.bounced ? 'Karşılıksız'
          : isOverdue ? 'Vadesi Geçmiş' : 'Bekliyor';
        final typeIcon = c.type == 'check' ? Icons.receipt_long_rounded : Icons.description_rounded;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: isOverdue && c.isPending ? AppColors.danger.withOpacity(0.03) : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isOverdue && c.isPending ? AppColors.danger.withOpacity(0.3) : AppColors.border),
          ),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Container(width: 44, height: 44,
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(typeIcon, color: statusColor, size: 22)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(c.type == 'check' ? 'ÇEK' : 'SENET',
                      style: const TextStyle(color: AppColors.textLight, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
                    const SizedBox(width: 8),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w700))),
                  ]),
                  const SizedBox(height: 4),
                  // Kime verildiği - büyük yazı
                  if (c.recipient.isNotEmpty)
                    Text(c.recipient, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textDark)),
                  // Keşideci
                  if (c.drawer.isNotEmpty && c.drawer != c.recipient)
                    Text('Keşideci: ${c.drawer}', style: const TextStyle(color: AppColors.textMid, fontSize: 12)),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${formatMoney(c.amount)} TL', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') _edit(c);
                      else if (v == 'delete') _delete(c);
                      else _updateStatus(c, v);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                      if (c.isPending) const PopupMenuItem(value: CheckStatus.cashed, child: Text('Tahsil Edildi ✓', style: TextStyle(color: AppColors.success))),
                      if (c.isPending) const PopupMenuItem(value: CheckStatus.bounced, child: Text('Karşılıksız ✗', style: TextStyle(color: AppColors.danger))),
                      const PopupMenuItem(value: 'delete', child: Text('Sil', style: TextStyle(color: AppColors.danger))),
                    ],
                  ),
                ]),
              ]),
            ),
            // Detay bilgiler
            Container(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(children: [
                const Divider(height: 12, color: AppColors.border),
                Row(children: [
                  _detailItem(Icons.tag_rounded, 'Çek No', c.no.isNotEmpty ? c.no : '—'),
                  _detailItem(Icons.account_balance_rounded, 'Banka', c.bank.isNotEmpty ? c.bank : '—'),
                  _detailItem(Icons.calendar_today_rounded, 'Verildiği Tarih', formatDate(c.issueDate)),
                  _detailItem(Icons.event_rounded, 'Vade Tarihi', formatDate(c.dueDate),
                    color: isOverdue && c.isPending ? AppColors.danger : null),
                ]),
                if (c.note.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Align(alignment: Alignment.centerLeft,
                    child: Text('Not: ${c.note}', style: const TextStyle(color: AppColors.textMid, fontSize: 12))),
                ],
              ]),
            ),
          ]),
        );
      },
    );
  }

  Widget _detailItem(IconData icon, String label, String value, {Color? color}) => Expanded(child: Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 11, color: AppColors.textLight),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: AppColors.textLight, fontSize: 10)),
      ]),
      Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12,
        color: color ?? AppColors.textDark), overflow: TextOverflow.ellipsis),
    ],
  ));
}

Future<CheckRecord?> _showCheckDialog(BuildContext context, {CheckRecord? existing, required List<ProjectData> projects}) async {
  final recipientCtrl = TextEditingController(text: existing?.recipient ?? '');
  final drawerCtrl = TextEditingController(text: existing?.drawer ?? '');
  final bankCtrl = TextEditingController(text: existing?.bank ?? '');
  final noCtrl = TextEditingController(text: existing?.no ?? '');
  final amountCtrl = TextEditingController(text: existing != null ? formatMoney(existing.amount) : '');
  final noteCtrl = TextEditingController(text: existing?.note ?? '');
  String type = existing?.type ?? 'check';
  String projectId = existing?.projectId ?? '';
  DateTime issueDate = existing?.issueDate ?? DateTime.now();
  DateTime dueDate = existing?.dueDate ?? DateTime.now().add(const Duration(days: 30));

  final result = await showDialog<CheckRecord>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, ss) => AlertDialog(
        title: Text(existing == null ? 'Çek / Senet Ekle' : 'Düzenle'),
        content: SizedBox(width: 460, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Tip seçimi
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'check', label: Text('Çek'), icon: Icon(Icons.receipt_long_rounded)),
              ButtonSegment(value: 'note', label: Text('Senet'), icon: Icon(Icons.description_rounded)),
            ],
            selected: {type},
            onSelectionChanged: (v) => ss(() => type = v.first),
          ),
          const SizedBox(height: 16),
          // Kime verildiği - en önemli alan
          TextField(controller: recipientCtrl,
            decoration: const InputDecoration(
              labelText: 'Kime Verildi *',
              hintText: 'Firma / kişi adı...',
              prefixIcon: Icon(Icons.person_outline_rounded))),
          const SizedBox(height: 10),
          TextField(controller: drawerCtrl,
            decoration: const InputDecoration(
              labelText: 'Keşideci (Düzenleyen)',
              prefixIcon: Icon(Icons.edit_outlined))),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: bankCtrl,
              decoration: const InputDecoration(labelText: 'Banka', prefixIcon: Icon(Icons.account_balance_rounded)))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: noCtrl,
              decoration: const InputDecoration(labelText: 'Çek / Senet No', prefixIcon: Icon(Icons.tag_rounded)))),
          ]),
          const SizedBox(height: 10),
          TextField(controller: amountCtrl, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Tutar (₺) *', prefixIcon: Icon(Icons.attach_money_rounded))),
          const SizedBox(height: 10),
          _DateField(label: 'Verildiği Tarih', date: issueDate, onPicked: (d) => ss(() => issueDate = d)),
          const SizedBox(height: 10),
          _DateField(label: 'Vade Tarihi', date: dueDate, onPicked: (d) => ss(() => dueDate = d)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: projectId.isEmpty ? null : projectId,
            decoration: const InputDecoration(labelText: 'İlgili Proje (isteğe bağlı)'),
            items: [const DropdownMenuItem(value: '', child: Text('Proje Seçme')),
              ...projects.map((p) => DropdownMenuItem(value: p.name, child: Text(p.name)))],
            onChanged: (v) => ss(() => projectId = v ?? ''),
          ),
          const SizedBox(height: 10),
          TextField(controller: noteCtrl, maxLines: 2,
            decoration: const InputDecoration(labelText: 'Not')),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(onPressed: () {
            if (recipientCtrl.text.trim().isEmpty) return;
            final amount = parseTrMoney(amountCtrl.text);
            if (amount <= 0) return;
            Navigator.pop(ctx, CheckRecord(
              id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
              type: type,
              recipient: recipientCtrl.text.trim(),
              drawer: drawerCtrl.text.trim(),
              bank: bankCtrl.text.trim(),
              no: noCtrl.text.trim(),
              amount: amount,
              issueDate: issueDate, dueDate: dueDate,
              status: existing?.status ?? CheckStatus.pending,
              note: noteCtrl.text.trim(),
              projectId: projectId,
            ));
          }, child: const Text('Kaydet')),
        ],
      ),
    ),
  );
  for (final c in [recipientCtrl, drawerCtrl, bankCtrl, noCtrl, amountCtrl, noteCtrl]) c.dispose();
  return result;
}

class _ProposalsPage extends StatefulWidget {
  final List<ProjectData> projects;
  const _ProposalsPage({required this.projects});
  @override State<_ProposalsPage> createState() => _ProposalsPageState();
}

class _ProposalsPageState extends State<_ProposalsPage> {
  List<Proposal> _proposals = [];

  @override
  void initState() { super.initState(); _proposals = StorageService.loadProposals(); }
  void _save() => StorageService.saveProposals(_proposals);

  Future<void> _add() async {
    final result = await Navigator.push<Proposal>(context, MaterialPageRoute(builder: (_) => ProposalFormPage(projects: widget.projects)));
    if (result != null) { setState(() => _proposals.add(result)); _save(); }
  }

  Future<void> _edit(Proposal p) async {
    final result = await Navigator.push<Proposal>(context, MaterialPageRoute(builder: (_) => ProposalFormPage(existing: p, projects: widget.projects)));
    if (result != null) {
      setState(() { final i = _proposals.indexOf(p); if (i >= 0) _proposals[i] = result; });
      _save();
    }
  }

  Future<void> _delete(Proposal p) async {
    final ok = await _confirm(context, 'Teklifi Sil', '"${p.title}" silinsin mi?');
    if (ok) { setState(() => _proposals.remove(p)); _save(); }
  }

  void _updateStatus(Proposal p, String status) {
    setState(() { final i = _proposals.indexOf(p); if (i >= 0) _proposals[i].status = status; });
    _save();
  }

  Color _statusColor(String s) => switch (s) {
    ProposalStatus.draft => AppColors.textMid,
    ProposalStatus.sent => AppColors.warning,
    ProposalStatus.accepted => AppColors.success,
    ProposalStatus.rejected => AppColors.danger,
    _ => AppColors.textMid,
  };

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Row(children: [
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Teklifler & Sözleşmeler', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textDark)),
            Text('Müşteri tekliflerinizi oluşturun ve takip edin', style: TextStyle(color: AppColors.textMid, fontSize: 13)),
          ])),
          ElevatedButton.icon(onPressed: _add, icon: const Icon(Icons.add, size: 16), label: const Text('+ Teklif Oluştur')),
        ]),
      ),
      Expanded(
        child: _proposals.isEmpty
            ? _EmptyState(icon: Icons.handshake_outlined, title: 'Teklif yok', subtitle: 'İlk teklifinizi oluşturun.')
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                itemCount: _proposals.length,
                itemBuilder: (context, i) {
                  final p = _proposals[i];
                  final sc = _statusColor(p.status);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () => _edit(p),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                        child: Column(children: [
                          Row(children: [
                            Container(width: 44, height: 44,
                              decoration: BoxDecoration(color: sc.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                              child: Icon(Icons.handshake_rounded, color: sc, size: 22)),
                            const SizedBox(width: 14),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(p.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                              Text(p.clientName.isNotEmpty ? p.clientName : 'Müşteri belirtilmedi', style: const TextStyle(color: AppColors.textMid, fontSize: 12)),
                            ])),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: sc.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                              child: Text(p.statusLabel, style: TextStyle(color: sc, fontWeight: FontWeight.w700, fontSize: 12))),
                            PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'edit') _edit(p);
                                else if (v == 'delete') _delete(p);
                                else if (v == 'pdf') exportProposalPdf(context, p);
                                else _updateStatus(p, v);
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                                const PopupMenuItem(value: 'pdf', child: Row(children: [Icon(Icons.picture_as_pdf_rounded, size: 16, color: AppColors.danger), SizedBox(width: 8), Text('PDF Oluştur')])),
                                if (p.status == ProposalStatus.draft) const PopupMenuItem(value: ProposalStatus.sent, child: Text('Gönderildi İşaretle')),
                                if (p.status == ProposalStatus.sent) ...[
                                  const PopupMenuItem(value: ProposalStatus.accepted, child: Text('Kabul Edildi ✓', style: TextStyle(color: AppColors.success))),
                                  const PopupMenuItem(value: ProposalStatus.rejected, child: Text('Reddedildi ✗', style: TextStyle(color: AppColors.danger))),
                                ],
                                const PopupMenuItem(value: 'delete', child: Text('Sil', style: TextStyle(color: AppColors.danger))),
                              ],
                            ),
                          ]),
                          const SizedBox(height: 12),
                          const Divider(height: 1, color: AppColors.border),
                          const SizedBox(height: 10),
                          Row(children: [
                            _MiniStat(label: 'Ara Toplam', value: '${formatMoney(p.subtotal())} TL', color: AppColors.textDark),
                            const SizedBox(width: 16),
                            if (p.kdvRate > 0) _MiniStat(label: 'KDV (%${p.kdvRate.toStringAsFixed(0)})', value: '${formatMoney(p.kdvAmount())} TL', color: AppColors.accent),
                            const Spacer(),
                            Text('TOPLAM: ${formatMoney(p.total())} TL', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                          ]),
                          Row(children: [
                            Text(formatDate(p.date), style: const TextStyle(color: AppColors.textLight, fontSize: 11)),
                            if (p.projectId.isNotEmpty) Text(' • ${p.projectId}', style: const TextStyle(color: AppColors.textLight, fontSize: 11)),
                            const Spacer(),
                            Text('${p.items.length} kalem', style: const TextStyle(color: AppColors.textLight, fontSize: 11)),
                          ]),
                        ]),
                      ),
                    ),
                  );
                },
              ),
      ),
    ],
  );
}

class ProposalFormPage extends StatefulWidget {
  final Proposal? existing;
  final List<ProjectData> projects;
  const ProposalFormPage({super.key, this.existing, required this.projects});
  @override State<ProposalFormPage> createState() => _ProposalFormPageState();
}

class _ProposalFormPageState extends State<ProposalFormPage> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _clientCtrl;
  late final TextEditingController _noteCtrl;
  final List<ProposalItem> _items = [];
  DateTime _date = DateTime.now();
  double _kdvRate = 0;
  String _projectId = '';
  String _status = ProposalStatus.draft;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _clientCtrl = TextEditingController(text: e?.clientName ?? '');
    _noteCtrl = TextEditingController(text: e?.note ?? '');
    if (e != null) {
      _date = e.date; _kdvRate = e.kdvRate; _projectId = e.projectId;
      _status = e.status; _items.addAll(e.items.map((i) => ProposalItem(description: i.description, quantity: i.quantity, unitPrice: i.unitPrice)));
    }
  }

  @override
  void dispose() { _titleCtrl.dispose(); _clientCtrl.dispose(); _noteCtrl.dispose(); super.dispose(); }

  double get _subtotal => _items.fold(0, (s, i) => s + i.total);
  double get _kdv => _subtotal * (_kdvRate / 100);
  double get _total => _subtotal + _kdv;

  Future<void> _addItem() async {
    final descCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController();
    final result = await showDialog<ProposalItem>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kalem Ekle'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Açıklama *')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Miktar'))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Birim Fiyat (₺)'))),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(onPressed: () {
            if (descCtrl.text.trim().isEmpty) return;
            Navigator.pop(ctx, ProposalItem(
              description: descCtrl.text.trim(),
              quantity: double.tryParse(qtyCtrl.text) ?? 1,
              unitPrice: parseTrMoney(priceCtrl.text),
            ));
          }, child: const Text('Ekle')),
        ],
      ),
    );
    descCtrl.dispose(); qtyCtrl.dispose(); priceCtrl.dispose();
    if (result != null) setState(() => _items.add(result));
  }

  void _save() {
    if (_titleCtrl.text.trim().isEmpty) return;
    Navigator.pop(context, Proposal(
      id: widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleCtrl.text.trim(), clientName: _clientCtrl.text.trim(),
      date: _date, status: _status, note: _noteCtrl.text.trim(),
      projectId: _projectId, kdvRate: _kdvRate,
      items: _items,
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(
      backgroundColor: AppColors.surface, elevation: 0,
      title: Text(widget.existing == null ? 'Yeni Teklif' : 'Teklifi Düzenle',
        style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textDark)),
      actions: [
        TextButton(onPressed: _save, child: const Text('Kaydet', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
        const SizedBox(width: 8),
      ],
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Temel bilgiler
        Container(padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
          child: Column(children: [
            TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Teklif Başlığı *', prefixIcon: Icon(Icons.title_rounded))),
            const SizedBox(height: 12),
            TextField(controller: _clientCtrl, decoration: const InputDecoration(labelText: 'Müşteri Adı', prefixIcon: Icon(Icons.person_outline_rounded))),
            const SizedBox(height: 12),
            _DateField(label: 'Teklif Tarihi', date: _date, onPicked: (d) => setState(() => _date = d)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _projectId.isEmpty ? null : _projectId,
              decoration: const InputDecoration(labelText: 'İlgili Proje'),
              items: [const DropdownMenuItem(value: '', child: Text('Proje Seçme')),
                ...widget.projects.map((p) => DropdownMenuItem(value: p.name, child: Text(p.name)))],
              onChanged: (v) => setState(() => _projectId = v ?? ''),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<double>(
              value: _kdvRate,
              decoration: const InputDecoration(labelText: 'KDV Oranı'),
              items: const [DropdownMenuItem(value: 0, child: Text('KDV Yok')), DropdownMenuItem(value: 1, child: Text('%1')), DropdownMenuItem(value: 8, child: Text('%8')), DropdownMenuItem(value: 10, child: Text('%10')), DropdownMenuItem(value: 18, child: Text('%18')), DropdownMenuItem(value: 20, child: Text('%20'))],
              onChanged: (v) => setState(() => _kdvRate = v ?? 0),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        // Kalemler
        Row(children: [
          const Text('Teklif Kalemleri', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          const Spacer(),
          ElevatedButton.icon(onPressed: _addItem, icon: const Icon(Icons.add, size: 16), label: const Text('+ Kalem')),
        ]),
        const SizedBox(height: 12),
        if (_items.isEmpty)
          _EmptyCard(text: 'Henüz kalem eklenmedi')
        else
          Container(
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
            child: Column(children: [
              ..._items.asMap().entries.map((entry) {
                final item = entry.value;
                return Column(children: [
                  ListTile(
                    title: Text(item.description),
                    subtitle: Text('${item.quantity} adet × ${formatMoney(item.unitPrice)} TL'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('${formatMoney(item.total)} TL', style: const TextStyle(fontWeight: FontWeight.w700)),
                      IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 18), onPressed: () => setState(() => _items.removeAt(entry.key))),
                    ]),
                  ),
                  if (entry.key < _items.length - 1) const Divider(height: 1, indent: 16, color: AppColors.border),
                ]);
              }),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.only(bottomLeft: Radius.circular(14), bottomRight: Radius.circular(14))),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Ara Toplam', style: TextStyle(color: AppColors.textMid)),
                    Text('${formatMoney(_subtotal)} TL'),
                  ]),
                  if (_kdvRate > 0) ...[
                    const SizedBox(height: 4),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('KDV (%${_kdvRate.toStringAsFixed(0)})', style: const TextStyle(color: AppColors.textMid)),
                      Text('${formatMoney(_kdv)} TL'),
                    ]),
                  ],
                  const Divider(height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('TOPLAM', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    Text('${formatMoney(_total)} TL', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.primary)),
                  ]),
                ]),
              ),
            ]),
          ),
        const SizedBox(height: 20),
        Container(padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
          child: TextField(controller: _noteCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Notlar / Şartlar', border: InputBorder.none))),
        const SizedBox(height: 80),
      ]),
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _save,
      backgroundColor: AppColors.primary,
      icon: const Icon(Icons.save_rounded, color: Colors.white),
      label: const Text('Kaydet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
    ),
  );
}

// Teklif PDF
Future<void> exportTaseronPdf(BuildContext context, Subcontractor sub, String projectName) async {
  final font = await PdfGoogleFonts.notoSansRegular();
  final fontBold = await PdfGoogleFonts.notoSansBold();
  final pdf = pw.Document();
  final company = StorageService.loadCompany();
  final now = DateTime.now();

  pdf.addPage(pw.MultiPage(
    theme: pw.ThemeData.withFont(base: font, bold: fontBold),
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(28),
    footer: (ctx) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text('e-Projex${company.name.isNotEmpty ? " | ${company.name}" : ""}',
        style: pw.TextStyle(color: PdfColor.fromHex('94A3B8'), fontSize: 8)),
      pw.Text('Sayfa ${ctx.pageNumber} / ${ctx.pagesCount}',
        style: pw.TextStyle(color: PdfColor.fromHex('94A3B8'), fontSize: 8)),
    ]),
    build: (ctx) => [
      // Başlık
      pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex('2563EB'),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Taseron Raporu', style: pw.TextStyle(color: PdfColors.white, fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Text(sub.name, style: pw.TextStyle(color: PdfColors.white, fontSize: 12)),
            pw.Text('Proje: $projectName', style: pw.TextStyle(color: PdfColors.white, fontSize: 10)),
          ]),
          pw.Text('${now.day.toString().padLeft(2, "0")}.${now.month.toString().padLeft(2, "0")}.${now.year}',
            style: pw.TextStyle(color: PdfColors.white, fontSize: 10)),
        ]),
      ),
      pw.SizedBox(height: 14),

      // Özet
      pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(color: PdfColor.fromHex('F0F4FF'), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            if (sub.phone.isNotEmpty) pw.Text('Tel: ${sub.phone}', style: const pw.TextStyle(fontSize: 10)),
            if (sub.taxNo.isNotEmpty) pw.Text('VKN: ${sub.taxNo}', style: const pw.TextStyle(fontSize: 10)),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('Sozlesme: ${fmtPdf(sub.totalContractAmount)}', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('Odenen: ${fmtPdf(sub.totalPaid)}', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('Kalan: ${fmtPdf(sub.remaining)}',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('2563EB'))),
          ]),
        ]),
      ),
      pw.SizedBox(height: 14),

      // İş kalemleri
      if (sub.works.isNotEmpty) ...[
        pw.Text('Is Kalemleri', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColor.fromHex('E2E8F0'), width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(1.5),
            2: const pw.FlexColumnWidth(1.5),
            3: const pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColor.fromHex('2563EB')),
              children: ['Is Kalemi', 'Miktar', 'Birim Fiyat', 'Toplam'].map((h) =>
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: pw.Text(h, style: pw.TextStyle(color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold)))).toList(),
            ),
            ...sub.works.asMap().entries.map((e) {
              final w = e.value;
              final bg = e.key % 2 == 0 ? PdfColors.white : PdfColor.fromHex('F8FAFC');
              return pw.TableRow(
                decoration: pw.BoxDecoration(color: bg),
                children: [
                  w.description, '${w.quantity} ${w.unit}',
                  fmtPdf(w.unitPrice), fmtPdf(w.total),
                ].map((v) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: pw.Text(v, style: const pw.TextStyle(fontSize: 9)))).toList(),
              );
            }),
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColor.fromHex('EFF6FF')),
              children: [
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: pw.Text('TOPLAM', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                pw.SizedBox(), pw.SizedBox(),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: pw.Text(fmtPdf(sub.works.fold(0, (s, w) => s + w.total)),
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('2563EB')))),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 14),
      ],

      // Ödemeler
      if (sub.payments.isNotEmpty) ...[
        pw.Text('Odemeler', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColor.fromHex('E2E8F0'), width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(1.5),
            1: const pw.FlexColumnWidth(1.2),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(2),
            4: const pw.FlexColumnWidth(1.5),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColor.fromHex('2563EB')),
              children: ['Tarih', 'Is Kalemi', 'Yontem', 'Tur', 'Tutar'].map((h) =>
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  child: pw.Text(h, style: pw.TextStyle(color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold)))).toList(),
            ),
            ...sub.payments.asMap().entries.map((e) {
              final p = e.value;
              final bg = e.key % 2 == 0 ? PdfColors.white : PdfColor.fromHex('F8FAFC');
              final typeLabel = p.type == 'advance' ? 'Avans' : p.type == 'progress' ? 'Hakediş' : 'Kesin';
              return pw.TableRow(
                decoration: pw.BoxDecoration(color: bg),
                children: [
                  '${p.date.day.toString().padLeft(2, "0")}.${p.date.month.toString().padLeft(2, "0")}.${p.date.year}',
                  p.workItem.isNotEmpty ? p.workItem : '-',
                  p.payMethod == 'check' ? 'Cek' : 'Nakit',
                  typeLabel,
                  fmtPdf(p.amount),
                ].map((v) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  child: pw.Text(v, style: const pw.TextStyle(fontSize: 9)))).toList(),
              );
            }),
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColor.fromHex('EFF6FF')),
              children: [
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  child: pw.Text('TOPLAM', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                pw.SizedBox(),
                pw.SizedBox(),
                pw.SizedBox(),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  child: pw.Text(fmtPdf(sub.totalPaid),
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('2563EB')))),
              ],
            ),
          ],
        ),
      ],
    ],
  ));

  await Printing.layoutPdf(onLayout: (fmt) => pdf.save());
}

Future<void> exportFirmaMalzemePdf(BuildContext context, ProjeMalzeme firma) async {
  final font = await PdfGoogleFonts.notoSansRegular();
  final fontBold = await PdfGoogleFonts.notoSansBold();
  final pdf = pw.Document();
  final company = StorageService.loadCompany();
  final now = DateTime.now();

  pdf.addPage(pw.MultiPage(
    theme: pw.ThemeData.withFont(base: font, bold: fontBold),
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(28),
    footer: (ctx) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text('e-Projex${company.name.isNotEmpty ? " | ${company.name}" : ""}',
        style: pw.TextStyle(color: PdfColor.fromHex('94A3B8'), fontSize: 8)),
      pw.Text('Sayfa ${ctx.pageNumber} / ${ctx.pagesCount}',
        style: pw.TextStyle(color: PdfColor.fromHex('94A3B8'), fontSize: 8)),
    ]),
    build: (ctx) => [
      pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex('2563EB'),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Malzeme Raporu', style: pw.TextStyle(color: PdfColors.white, fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Text(firma.firmaAdi, style: pw.TextStyle(color: PdfColors.white, fontSize: 12)),
            if (firma.firmaTel.isNotEmpty)
              pw.Text(firma.firmaTel, style: pw.TextStyle(color: PdfColors.white, fontSize: 10)),
          ]),
          pw.Text('${now.day.toString().padLeft(2, "0")}.${now.month.toString().padLeft(2, "0")}.${now.year}',
            style: pw.TextStyle(color: PdfColors.white, fontSize: 10)),
        ]),
      ),
      pw.SizedBox(height: 16),
      pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(color: PdfColor.fromHex('F0F4FF'), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Toplam Kalem: ${firma.kalemler.length}', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('Odenen: ${firma.kalemler.where((k) => k.odendi).length} kalem', style: const pw.TextStyle(fontSize: 10)),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('KDV Haric: ${fmtPdf(firma.toplamKdvsiz)}', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('KDV (%20): ${fmtPdf(firma.toplamKdv)}', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('KDV Dahil: ${fmtPdf(firma.toplamKdvli)}',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('2563EB'))),
          ]),
        ]),
      ),
      pw.SizedBox(height: 16),
      if (firma.kalemler.isNotEmpty) ...[
        pw.Text('Malzeme Listesi', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColor.fromHex('E2E8F0'), width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(1.2),
            1: const pw.FlexColumnWidth(1.8),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(1),
            4: const pw.FlexColumnWidth(1.1),
            5: const pw.FlexColumnWidth(1.1),
            6: const pw.FlexColumnWidth(1.2),
            7: const pw.FlexColumnWidth(0.6),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColor.fromHex('2563EB')),
              children: ['Tarih', 'Malzeme', 'Miktar', 'Birim', 'Birim TL', 'KDV Haric', 'KDV Dahil', 'Odendi'].map((h) =>
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                  child: pw.Text(h, style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold)))).toList(),
            ),
            ...firma.kalemler.asMap().entries.map((e) {
              final k = e.value;
              final bg = e.key % 2 == 0 ? PdfColors.white : PdfColor.fromHex('F8FAFC');
              return pw.TableRow(
                decoration: pw.BoxDecoration(color: bg),
                children: [
                  '${k.tarih.day.toString().padLeft(2, "0")}.${k.tarih.month.toString().padLeft(2, "0")}.${k.tarih.year}',
                  k.ad,
                  '${k.miktar}',
                  k.birim,
                  k.birimTutar > 0 ? fmtPdf(k.birimTutar) : '-',
                  k.birimTutar > 0 ? fmtPdf(k.kdvsizToplam) : '-',
                  k.birimTutar > 0 ? fmtPdf(k.kdvliToplam) : '-',
                  k.odendi ? 'Evet' : 'Hayir',
                ].map((v) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                  child: pw.Text(v, style: const pw.TextStyle(fontSize: 8)))).toList(),
              );
            }),
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColor.fromHex('EFF6FF')),
              children: [
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                  child: pw.Text('TOPLAM', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                pw.SizedBox(), pw.SizedBox(), pw.SizedBox(), pw.SizedBox(),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                  child: pw.Text(fmtPdf(firma.toplamKdvsiz), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                  child: pw.Text(fmtPdf(firma.toplamKdvli), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('2563EB')))),
                pw.SizedBox(),
              ],
            ),
          ],
        ),
      ],
    ],
  ));

  await Printing.layoutPdf(onLayout: (fmt) => pdf.save());
}

Future<void> exportProposalPdf(BuildContext context, Proposal proposal) async {
  final company = StorageService.loadCompany();
  final pdf = pw.Document();

  pdf.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(28),
    footer: (ctx) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text('e-Projex${company.name.isNotEmpty && company.name != "Şirket Adı" ? " | ${company.name}" : ""}', style: pw.TextStyle(color: PdfColor.fromHex('94A3B8'), fontSize: 8)),
      pw.Text('Sayfa ${ctx.pageNumber} / ${ctx.pagesCount}', style: pw.TextStyle(color: PdfColor.fromHex('94A3B8'), fontSize: 8)),
    ]),
    build: (ctx) => [
      _pdfHeader('TEKLİF', proposal.title),
      pw.SizedBox(height: 14),

      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          if (company.name.isNotEmpty && company.name != 'Şirket Adı') ...[
            pw.Text('GÖNDEREN', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('94A3B8'))),
            pw.Text(company.name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            if (company.phone.isNotEmpty) pw.Text(company.phone, style: const pw.TextStyle(fontSize: 9)),
            if (company.email.isNotEmpty) pw.Text(company.email, style: const pw.TextStyle(fontSize: 9)),
          ],
        ])),
        pw.SizedBox(width: 20),
        pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('ALICI', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('94A3B8'))),
          pw.Text(proposal.clientName.isNotEmpty ? proposal.clientName : '—', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
          pw.SizedBox(height: 8),
          pw.Text('Teklif No: ${proposal.id.substring(proposal.id.length - 6)}', style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Tarih: ${formatDate(proposal.date)}', style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Durum: ${proposal.statusLabel}', style: const pw.TextStyle(fontSize: 9)),
        ])),
      ]),
      pw.SizedBox(height: 20),

      _pdfSection('Teklif Kalemleri'),
      pw.Table(
        border: pw.TableBorder.all(color: PdfColor.fromHex('E2E8F0'), width: 0.5),
        columnWidths: {0: const pw.FlexColumnWidth(4), 1: const pw.FlexColumnWidth(1.2), 2: const pw.FlexColumnWidth(1.5), 3: const pw.FlexColumnWidth(1.5)},
        children: [
          pw.TableRow(
            decoration: pw.BoxDecoration(color: PdfColor.fromHex('1E40AF')),
            children: ['Açıklama', 'Miktar', 'Birim Fiyat', 'Toplam'].map((h) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: pw.Text(h, style: pw.TextStyle(color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold)))).toList(),
          ),
          ...proposal.items.asMap().entries.map((e) => pw.TableRow(
            decoration: pw.BoxDecoration(color: e.key % 2 == 0 ? PdfColors.white : PdfColor.fromHex('F8FAFF')),
            children: [
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(e.value.description, style: const pw.TextStyle(fontSize: 9))),
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${e.value.quantity}', style: const pw.TextStyle(fontSize: 9))),
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${formatMoney(e.value.unitPrice)} TL', style: const pw.TextStyle(fontSize: 9))),
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${formatMoney(e.value.total)} TL', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
            ],
          )),
        ],
      ),
      pw.SizedBox(height: 12),
      pw.Align(alignment: pw.Alignment.centerRight,
        child: pw.Container(
          width: 200,
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(color: PdfColor.fromHex('F0F4FF'), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))),
          child: pw.Column(children: [
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('Ara Toplam:', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('${formatMoney(proposal.subtotal())} TL', style: const pw.TextStyle(fontSize: 10)),
            ]),
            if (proposal.kdvRate > 0) ...[
              pw.SizedBox(height: 4),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('KDV (%${proposal.kdvRate.toStringAsFixed(0)}):', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('${formatMoney(proposal.kdvAmount())} TL', style: const pw.TextStyle(fontSize: 10)),
              ]),
            ],
            pw.Divider(color: PdfColor.fromHex('1E40AF')),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('TOPLAM:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('1E40AF'))),
              pw.Text('${formatMoney(proposal.total())} TL', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('1E40AF'))),
            ]),
          ]),
        )),

      if (proposal.note.isNotEmpty) ...[
        _pdfSection('Notlar & Şartlar'),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(color: PdfColor.fromHex('FFFBEB'), border: pw.Border.all(color: PdfColor.fromHex('F59E0B'), width: 0.5), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
          child: pw.Text(proposal.note, style: const pw.TextStyle(fontSize: 10)),
        ),
      ],
    ],
  ));

  await Printing.layoutPdf(onLayout: (f) async => pdf.save());
}

class _ComingSoonPage extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  const _ComingSoonPage({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 64, color: AppColors.primary.withOpacity(0.3)),
      const SizedBox(height: 20),
      Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textDark)),
      const SizedBox(height: 8),
      Text(subtitle, style: const TextStyle(color: AppColors.textMid, fontSize: 16)),
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
        child: const Text('🚧  Geliştirme aşamasında', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
      ),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════
//  YÖNETİCİ PANELİ
// ══════════════════════════════════════════════════════════════

class _AdminPanelPage extends StatefulWidget {
  final VoidCallback onChanged;
  const _AdminPanelPage({required this.onChanged});
  @override State<_AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<_AdminPanelPage> with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<Map<String, dynamic>> _users = [];
  final _brevoCtrl = TextEditingController();
  bool _brevoSaved = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadUsers();
    _brevoCtrl.text = StorageService.loadBrevoKey();
  }

  @override
  void dispose() { _tab.dispose(); _brevoCtrl.dispose(); super.dispose(); }

  void _loadUsers() => setState(() => _users = StorageService.loadUsers());

  Future<void> _toggleRole(Map<String, dynamic> user) async {
    final newRole = user['role'] == 'admin' ? 'user' : 'admin';
    StorageService.updateUser(user['id'], {'role': newRole});
    _loadUsers();
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kullanıcıyı Sil'),
        content: Text('${user['name']} adlı kullanıcıyı silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Sil')),
        ],
      ),
    );
    if (ok == true) {
      StorageService.deleteUser(user['id']);
      _loadUsers();
    }
  }

  Future<void> _addUserDialog() async {
    final nameCtrl  = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl  = TextEditingController();
    String role = 'user';
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => AlertDialog(
        title: const Text('Kullanıcı Ekle'),
        content: SizedBox(
          width: 360,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Ad Soyad', prefixIcon: Icon(Icons.person_outline))),
            const SizedBox(height: 12),
            TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-posta', prefixIcon: Icon(Icons.email_outlined))),
            const SizedBox(height: 12),
            TextField(controller: passCtrl, obscureText: true,
              decoration: const InputDecoration(labelText: 'Şifre', prefixIcon: Icon(Icons.lock_outline))),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: role,
              items: const [
                DropdownMenuItem(value: 'user',  child: Text('Kullanıcı')),
                DropdownMenuItem(value: 'admin', child: Text('Yönetici')),
              ],
              onChanged: (v) => ss(() => role = v!),
              decoration: const InputDecoration(labelText: 'Rol', prefixIcon: Icon(Icons.badge_outlined)),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty || !emailCtrl.text.contains('@') || passCtrl.text.length < 6) return;
              final users = StorageService.loadUsers();
              users.add({
                'id': DateTime.now().millisecondsSinceEpoch.toString(),
                'name': nameCtrl.text.trim(),
                'email': emailCtrl.text.trim().toLowerCase(),
                'password': passCtrl.text,
                'role': role,
                'verified': true,
                'createdAt': DateTime.now().toIso8601String(),
              });
              StorageService.saveUsers(users);
              Navigator.pop(ctx);
              _loadUsers();
            },
            child: const Text('Ekle'),
          ),
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surf = AppColors.surfaceOf(context);
    final bord = AppColors.borderOf(context);
    final me = StorageService.currentUser;

    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      appBar: AppBar(
        title: const Text('Yönetici Paneli', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: surf,
        elevation: 0,
        bottom: TabBar(
          controller: _tab,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMid,
          indicatorColor: AppColors.primary,
          tabs: const [Tab(text: 'Kullanıcılar'), Tab(text: 'Sistem')],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addUserDialog,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Kullanıcı Ekle'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          // ── Kullanıcılar Tab ────────────────────────────────
          _users.isEmpty
              ? const Center(child: Text('Henüz kullanıcı yok'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _users.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final u = _users[i];
                    final isMe = u['id'] == me?['id'];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: surf,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: bord),
                      ),
                      child: Row(children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: u['role'] == 'admin'
                              ? AppColors.primary.withOpacity(0.15)
                              : AppColors.accent.withOpacity(0.15),
                          child: Text(
                            (u['name'] as String).isNotEmpty ? (u['name'] as String)[0].toUpperCase() : '?',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: u['role'] == 'admin' ? AppColors.primary : AppColors.accent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Text(u['name'] ?? '', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDarkOf(context))),
                            if (isMe) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                child: const Text('Siz', style: TextStyle(fontSize: 10, color: AppColors.success, fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ]),
                          Text(u['email'] ?? '', style: TextStyle(fontSize: 12, color: AppColors.textLightOf(context))),
                        ])),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: u['role'] == 'admin' ? AppColors.primary.withOpacity(0.1) : AppColors.accent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              u['role'] == 'admin' ? 'Yönetici' : 'Kullanıcı',
                              style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700,
                                color: u['role'] == 'admin' ? AppColors.primary : AppColors.accent,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (u['verified'] == true ? AppColors.success : AppColors.warning).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              u['verified'] == true ? 'Doğrulandı' : 'Doğrulanmadı',
                              style: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w600,
                                color: u['verified'] == true ? AppColors.success : AppColors.warning,
                              ),
                            ),
                          ),
                        ]),
                        const SizedBox(width: 8),
                        if (!isMe)
                          PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'role') _toggleRole(u);
                              if (v == 'verify') { StorageService.updateUser(u['id'], {'verified': true}); _loadUsers(); }
                              if (v == 'delete') _deleteUser(u);
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(value: 'role', child: Row(children: [
                                const Icon(Icons.swap_horiz_rounded, size: 18),
                                const SizedBox(width: 8),
                                Text(u['role'] == 'admin' ? 'Kullanıcı Yap' : 'Yönetici Yap'),
                              ])),
                              if (u['verified'] != true)
                                const PopupMenuItem(value: 'verify', child: Row(children: [
                                  Icon(Icons.check_circle_outline, size: 18, color: AppColors.success),
                                  SizedBox(width: 8),
                                  Text('Manuel Doğrula'),
                                ])),
                              const PopupMenuItem(value: 'delete', child: Row(children: [
                                Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                                SizedBox(width: 8),
                                Text('Sil', style: TextStyle(color: AppColors.danger)),
                              ])),
                            ],
                          ),
                      ]),
                    );
                  },
                ),

          // ── Sistem Tab ──────────────────────────────────────
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _AdminSysCard(
                icon: Icons.people_rounded,
                title: 'Toplam Kullanıcı',
                value: '${_users.length}',
                color: AppColors.primary,
                surf: surf, bord: bord, context: context,
              ),
              const SizedBox(height: 12),
              _AdminSysCard(
                icon: Icons.verified_user_rounded,
                title: 'Doğrulanmış',
                value: '${_users.where((u) => u['verified'] == true).length}',
                color: AppColors.success,
                surf: surf, bord: bord, context: context,
              ),
              const SizedBox(height: 12),
              _AdminSysCard(
                icon: Icons.admin_panel_settings_rounded,
                title: 'Yönetici Sayısı',
                value: '${_users.where((u) => u['role'] == 'admin').length}',
                color: AppColors.warning,
                surf: surf, bord: bord, context: context,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surf,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: bord),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.email_outlined, color: AppColors.primary, size: 18),
                    const SizedBox(width: 8),
                    Text('Brevo E-posta API Ayarı',
                        style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDarkOf(context))),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                    'Ücretsiz hesap: app.brevo.com → API Keys → Create API key',
                    style: TextStyle(fontSize: 12, color: AppColors.textMidOf(context), height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _brevoCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Brevo API Key',
                      hintText: 'xkeysib-...',
                      border: const OutlineInputBorder(),
                      suffixIcon: _brevoSaved
                          ? const Icon(Icons.check_circle, color: AppColors.success)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save_rounded, size: 18),
                      label: const Text('Kaydet'),
                      onPressed: () {
                        StorageService.saveBrevoKey(_brevoCtrl.text);
                        setState(() => _brevoSaved = true);
                        Future.delayed(const Duration(seconds: 2), () {
                          if (mounted) setState(() => _brevoSaved = false);
                        });
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Brevo API anahtarı kaydedildi.'),
                          backgroundColor: AppColors.success,
                        ));
                      },
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminSysCard extends StatelessWidget {
  final IconData icon;
  final String title, value;
  final Color color;
  final Color surf, bord;
  final BuildContext context;
  const _AdminSysCard({required this.icon, required this.title, required this.value, required this.color, required this.surf, required this.bord, required this.context});

  @override
  Widget build(BuildContext _) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: surf, borderRadius: BorderRadius.circular(12), border: Border.all(color: bord)),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 22),
      ),
      const SizedBox(width: 14),
      Text(title, style: TextStyle(color: AppColors.textMidOf(context))),
      const Spacer(),
      Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
    ]),
  );
}
