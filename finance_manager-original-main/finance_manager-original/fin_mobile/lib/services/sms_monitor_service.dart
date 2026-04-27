// lib/services/sms_monitor_service.dart
import 'package:telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';
import 'sms_parser_service.dart';

class SmsMonitorService {
  static final Telephony telephony = Telephony.instance;
  static final SmsParserService parser = SmsParserService();

  /// Request SMS permissions from user
  static Future<bool> requestPermissions() async {
    PermissionStatus status = await Permission.sms.status;

    if (status.isGranted) {
      return true;
    }

    if (status.isDenied) {
      status = await Permission.sms.request();
      return status.isGranted;
    }

    if (status.isPermanentlyDenied) {
      // User permanently denied - open app settings
      await openAppSettings();
      return false;
    }

    return false;
  }

  /// Start listening to incoming SMS
  static Future<void> startListening() async {
    bool hasPermission = await requestPermissions().timeout(
      const Duration(seconds: 4),
      onTimeout: () => false,
    );

    if (!hasPermission) {
      print('❌ SMS permission not granted');
      return;
    }

    print('✅ SMS monitoring started');

    // Listen to incoming SMS
    telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) {
        _handleIncomingSms(message);
      },
      onBackgroundMessage: backgroundMessageHandler,
      listenInBackground: true,
    );
  }

  /// Handle incoming SMS
  static void _handleIncomingSms(SmsMessage message) {
    String sender = message.address ?? '';
    String body = message.body ?? '';

    print('📱 New SMS from: $sender');

    // Check if it's a bank SMS
    if (parser.isBankSms(sender, body)) {
      print('🏦 Bank SMS detected!');
      parser.processAndCreateTransaction(sender, body);
    }
  }

  /// Read existing SMS (last 30 days) - for initial sync
  static Future<void> syncExistingSms() async {
    bool hasPermission = await requestPermissions();

    if (!hasPermission) {
      print('❌ SMS permission not granted for sync');
      return;
    }

    print('🔄 Syncing existing SMS...');

    // Get SMS from last 30 days
    DateTime thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    int startTimestamp = thirtyDaysAgo.millisecondsSinceEpoch;

    List<SmsMessage> messages = await telephony.getInboxSms(
      columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
      filter: SmsFilter.where(SmsColumn.DATE)
          .greaterThan(startTimestamp.toString()),
      sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
    );

    print('📥 Found ${messages.length} SMS to process');

    int transactionsCreated = 0;

    for (SmsMessage message in messages) {
      String sender = message.address ?? '';
      String body = message.body ?? '';

      if (parser.isBankSms(sender, body)) {
        bool success = await parser.processAndCreateTransaction(sender, body);
        if (success) {
          transactionsCreated++;
        }
      }
    }

    print('✅ Sync complete! Created $transactionsCreated transactions');
  }

  /// Stop listening to SMS
  static void stopListening() {
    print('🛑 SMS monitoring stopped');
    // Note: Telephony package doesn't have explicit stop method
    // It stops when app is closed
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
void backgroundMessageHandler(SmsMessage message) {
  String sender = message.address ?? '';
  String body = message.body ?? '';

  print('📱 Background SMS from: $sender');

  // Parse and create transaction in background
  SmsParserService parser = SmsParserService();
  if (parser.isBankSms(sender, body)) {
    print('🏦 Bank SMS detected in background!');
    parser.processAndCreateTransaction(sender, body);
  }
}
