import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EmailService {
  final String _username = 'kkukupo0@gmail.com'; // Your Gmail address

  String get _password {
    final password = dotenv.env['GMAIL_APP_PASSWORD'];
    if (password == null || password.isEmpty) {
      throw Exception('GMAIL_APP_PASSWORD is not set in .env');
    }
    return password;
  }

  SmtpServer get _smtpServer => gmail(_username, _password);

  Future<void> sendAttendanceEmail({
    required String recipientEmail,
    required String name,
    required String status,
  }) async {
    final now = DateTime.now();
    final timeString =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final dateString =
        '${now.year.toString().substring(2)}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';

    final emailSubject = '[$status] - $name ($timeString) - $dateString';
    final emailBody = '''
        <p><b>$name</b> - [$status]</p>
        <p><b>Time:</b> $timeString - $dateString</p>
    ''';

    final message = Message()
      ..from = Address(_username, 'Quiver Hub')
      ..recipients.add(recipientEmail)
      ..subject = emailSubject
      ..html = emailBody;

    try {
      final sendReport = await send(message, _smtpServer);
      print('Attendance email sent successfully: $sendReport');
    } on MailerException catch (e) {
      print('Error sending attendance email: ${e.message}');
      for (var p in e.problems) {
        print('Problem: ${p.code}: ${p.msg}');
      }
    }
  }

  Future<void> sendNewMessageEmail({
    required String recipientEmail,
    required String senderType,
    required String messageText,
    required String messageId,
  }) async {
    final now = DateTime.now();
    final timeString =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final dateString =
        '${now.year.toString().substring(2)}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';

    final emailSubject =
        '[$senderType] New Chat Message ($timeString) - $dateString';

    // TODO: update with real links
    const deleteLink = 'YOUR_DELETE_FUNCTION_URL';
    const webAppLink = 'YOUR_CHAT_WEB_APP_URL';

    final emailBody = '''
        <p><b>Sender:</b> $senderType</p>
        <p><b>Message:</b> $messageText</p>
        <p><b>Time:</b> $timeString - $dateString</p>
        <hr>
        <p><a href="$deleteLink?messageId=$messageId">Delete this message</a></p>
        <p><a href="$webAppLink">Open Chat Web App</a></p>
    ''';

    final message = Message()
      ..from = Address(_username, 'Quiver Hub Chat')
      ..recipients.add(recipientEmail)
      ..subject = emailSubject
      ..html = emailBody;

    try {
      final sendReport = await send(message, _smtpServer);
      print('Chat notification email sent successfully: $sendReport');
    } on MailerException catch (e) {
      print('Error sending chat email: ${e.message}');
      for (var p in e.problems) {
        print('Problem: ${p.code}: ${p.msg}');
      }
    }
  }
}
