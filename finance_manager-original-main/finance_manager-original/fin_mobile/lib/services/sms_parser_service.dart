// lib/services/sms_parser_service.dart
import 'api_service.dart';

class SmsParserService {
  final ApiService api = ApiService();

  // Bank sender IDs to monitor
  static const List<String> bankSenders = [
    'HDFCBK', 'SBIINB', 'ICICIB', 'AXISBK', 'KOTAKB',
    'PNBSMS', 'BOISMS', 'CBSSBI', 'UNIONB', 'YESBNK',
    'INDBNK', 'IDFCFB', 'SCBANK', 'CITIBK', 'HSBC',
    'RBLBNK', 'FEDBK', 'KVBBANK', 'SBMBK', 'DCBBNK',
    'VM-', 'BM-', 'TX-', 'AD-', 'AX-' // Generic prefixes
  ];

  // Keywords indicating debit transactions
  static const List<String> debitKeywords = [
    'debited', 'debit', 'spent', 'withdrawn', 'paid',
    'purchase', 'txn', 'transaction', 'payment', 'transferred'
  ];

  // Keywords indicating credit transactions
  static const List<String> creditKeywords = [
    'credited', 'credit', 'received', 'deposited', 'refund',
    'salary', 'cashback', 'reversed'
  ];

  /// Check if SMS is from a bank
  bool isBankSms(String sender, String message) {
    String senderUpper = sender.toUpperCase();
    String messageUpper = message.toUpperCase();

    // Check sender ID
    for (String bankSender in bankSenders) {
      if (senderUpper.contains(bankSender)) {
        return true;
      }
    }

    // Check message content for banking keywords
    if (messageUpper.contains('A/C') ||
        messageUpper.contains('ACCOUNT') ||
        messageUpper.contains('CARD') ||
        messageUpper.contains('UPI') ||
        messageUpper.contains('NEFT') ||
        messageUpper.contains('IMPS')) {
      return true;
    }

    return false;
  }

  /// Parse SMS and extract transaction details
  Future<Map<String, dynamic>?> parseSms(String sender, String message) async {
    if (!isBankSms(sender, message)) {
      return null;
    }

    String msgUpper = message.toUpperCase();

    // Determine transaction type
    bool isDebit = false;
    bool isCredit = false;

    for (String keyword in debitKeywords) {
      if (msgUpper.contains(keyword.toUpperCase())) {
        isDebit = true;
        break;
      }
    }

    for (String keyword in creditKeywords) {
      if (msgUpper.contains(keyword.toUpperCase())) {
        isCredit = true;
        break;
      }
    }

    if (!isDebit && !isCredit) {
      return null; // Not a transaction SMS
    }

    // Extract amount
    double? amount = _extractAmount(message);
    if (amount == null || amount == 0) {
      return null; // No valid amount found
    }

    // Extract merchant/description
    String merchant = _extractMerchant(message, sender);

    // Extract date/time (use current time if not found)
    DateTime transactionDate = DateTime.now();

    // Build transaction object
    return {
      'amount': amount,
      'merchant': merchant,
      'notes': 'Auto-detected from SMS',
      'transaction_date': transactionDate.toIso8601String(),
      'raw_sms': message, // Store original SMS for reference
      'sender': sender,
      'type': isDebit ? 'expense' : 'income'
    };
  }

  /// Extract amount from SMS text
  double? _extractAmount(String message) {
    // Common patterns:
    // Rs.1500, Rs 1500, INR 1,500.00, ₹1500, 1500.00, 1,500

    // Pattern 1: Rs.XXXX or Rs XXXX or INR XXXX
    RegExp pattern1 = RegExp(r'(?:Rs\.?|INR|₹)\s?([0-9,]+(?:\.[0-9]{2})?)', caseSensitive: false);
    Match? match1 = pattern1.firstMatch(message);
    if (match1 != null) {
      String amountStr = match1.group(1)!.replaceAll(',', '');
      return double.tryParse(amountStr);
    }

    // Pattern 2: Amount before "debited" or "credited"
    RegExp pattern2 = RegExp(r'([0-9,]+(?:\.[0-9]{2})?)\s?(?:debited|credited|spent|paid|received)', caseSensitive: false);
    Match? match2 = pattern2.firstMatch(message);
    if (match2 != null) {
      String amountStr = match2.group(1)!.replaceAll(',', '');
      return double.tryParse(amountStr);
    }

    // Pattern 3: Look for any number with optional decimal
    RegExp pattern3 = RegExp(r'([0-9,]+\.[0-9]{2}|[0-9,]{4,})');
    Iterable<Match> matches = pattern3.allMatches(message);
    for (Match match in matches) {
      String amountStr = match.group(1)!.replaceAll(',', '');
      double? amt = double.tryParse(amountStr);
      if (amt != null && amt >= 1 && amt <= 1000000) { // Reasonable range
        return amt;
      }
    }

    return null;
  }

  /// Extract merchant name from SMS
  String _extractMerchant(String message, String sender) {
    String msgUpper = message.toUpperCase();

    // Pattern 1: "at MERCHANT" or "to MERCHANT"
    RegExp pattern1 = RegExp(r'(?:AT|TO|VIA)\s+([A-Z0-9\s\-\.]+?)(?:\s+ON|\s+UPI|\s+REF|\.|\s+A/C)', caseSensitive: false);
    Match? match1 = pattern1.firstMatch(message);
    if (match1 != null) {
      return _cleanMerchantName(match1.group(1)!);
    }

    // Pattern 2: UPI transactions - "UPI/MERCHANT/..."
    if (msgUpper.contains('UPI')) {
      RegExp upiPattern = RegExp(r'UPI/([A-Z0-9\s]+?)/', caseSensitive: false);
      Match? upiMatch = upiPattern.firstMatch(message);
      if (upiMatch != null) {
        return _cleanMerchantName(upiMatch.group(1)!);
      }
    }

    // Pattern 3: POS transactions
    if (msgUpper.contains('POS')) {
      RegExp posPattern = RegExp(r'POS\s+([A-Z0-9\s]+?)(?:\s+ON|\s+REF)', caseSensitive: false);
      Match? posMatch = posPattern.firstMatch(message);
      if (posMatch != null) {
        return _cleanMerchantName(posMatch.group(1)!);
      }
    }

    // Fallback: Use bank name from sender
    return _getBankName(sender);
  }

  /// Clean merchant name
  String _cleanMerchantName(String raw) {
    String cleaned = raw.trim();
    // Remove extra whitespaces
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    // Remove special characters at end
    cleaned = cleaned.replaceAll(RegExp(r'[\.\,\-]+$'), '');
    // Capitalize first letter of each word
    List<String> words = cleaned.split(' ');
    cleaned = words.map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');

    return cleaned.isEmpty ? 'Unknown Merchant' : cleaned;
  }

  /// Get bank name from sender ID
  String _getBankName(String sender) {
    String senderUpper = sender.toUpperCase();
    if (senderUpper.contains('HDFC')) return 'HDFC Bank';
    if (senderUpper.contains('ICICI')) return 'ICICI Bank';
    if (senderUpper.contains('SBI')) return 'State Bank of India';
    if (senderUpper.contains('AXIS')) return 'Axis Bank';
    if (senderUpper.contains('KOTAK')) return 'Kotak Mahindra Bank';
    if (senderUpper.contains('PNB')) return 'Punjab National Bank';
    if (senderUpper.contains('BOI')) return 'Bank of India';
    if (senderUpper.contains('UNION')) return 'Union Bank';
    if (senderUpper.contains('YES')) return 'Yes Bank';
    if (senderUpper.contains('IDFC')) return 'IDFC First Bank';
    if (senderUpper.contains('CITI')) return 'Citi Bank';
    if (senderUpper.contains('HSBC')) return 'HSBC Bank';
    if (senderUpper.contains('RBL')) return 'RBL Bank';
    return 'Bank Transaction';
  }

  /// Process and create transaction from SMS
  Future<bool> processAndCreateTransaction(String sender, String message) async {
    try {
      Map<String, dynamic>? txnData = await parseSms(sender, message);

      if (txnData == null) {
        return false; // Not a transaction SMS
      }

      // Send to backend API
      final response = await api.post('/api/transactions/', txnData, auth: true);

      if (response.statusCode == 201) {
        print('✅ Transaction auto-created from SMS: ${txnData['merchant']} - ₹${txnData['amount']}');
        return true;
      } else {
        print('❌ Failed to create transaction: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error processing SMS: $e');
      return false;
    }
  }

  /// Test SMS parser with sample messages
  static void testParser() {
    SmsParserService parser = SmsParserService();

    List<String> testMessages = [
      'Rs.1500 debited from A/C XX1234 on 15-Nov at SWIGGY UPI Ref:12345',
      'Your A/c XX5678 is debited by Rs1500.00 at AMAZON on 15/11/24',
      'INR 2,500.00 spent on HDFC Credit Card XX9012 at Flipkart',
      'UPI/ZOMATO/payment of Rs 450 debited from A/c',
      'Rs 50,000 credited to your A/c XX1234 - Salary for Nov 2024',
    ];

    print('🧪 Testing SMS Parser:\n');
    for (String msg in testMessages) {
      parser.parseSms('HDFCBK', msg).then((result) {
        if (result != null) {
          print('✅ Parsed: ${result['merchant']} - ₹${result['amount']}');
        } else {
          print('❌ Failed to parse');
        }
      });
    }
  }
}
