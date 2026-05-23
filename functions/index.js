const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');
require('dotenv').config();

admin.initializeApp();

// ── Email (Gmail) ──────────────────────────────────────────
const gmailEmail = process.env.GMAIL_ADDRESS;
const gmailPassword = process.env.GMAIL_APP_PASSWORD;

const mailTransport = nodemailer.createTransport({
  service: 'gmail',
  auth: { user: gmailEmail, pass: gmailPassword },
});

// ── Telegram ───────────────────────────────────────────────
const telegramSecrets = [];

async function sendTelegramMessage(text, token, chatId) {
  const url = `https://api.telegram.org/bot${token}/sendMessage`;
  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ chat_id: chatId, text, parse_mode: 'HTML' }),
  });
  const result = await response.json();
  if (!result.ok) throw new Error(`Telegram API error: ${result.description}`);
  return result;
}

// ── Shared helpers ─────────────────────────────────────────
async function getAdminSettings() {
  const doc = await admin.firestore().collection('settings').doc('admin_settings').get();
  return doc.exists ? doc.data() : {};
}

function formatDateTime(dateObj) {
  const date = (dateObj && dateObj.toDate) ? dateObj.toDate() : (dateObj || new Date());
  const timeString = `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`;
  const dateString = `${String(date.getFullYear()).substring(2)}/${String(date.getMonth() + 1).padStart(2, '0')}/${String(date.getDate()).padStart(2, '0')}`;
  return { timeString, dateString };
}

// ── 선수 채팅 메시지 알림 ────────────────────────────────────
exports.sendNotificationOnNewMessage = functions.firestore
  .document('chats/main_thread/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const messageData = snap.data();

    if (messageData.senderType !== 'PLAYER') {
      console.log('Sender is not PLAYER, skipping notification');
      return null;
    }

    try {
      const settings = await getAdminSettings();
      const method = settings.notificationMethod || 'telegram';
      const { timeString, dateString } = formatDateTime(messageData.timestamp);
      const messageText = messageData.text || '';

      if (method === 'telegram') {
        const token = settings.telegramBotToken;
        const chatId = settings.telegramChatId;
        if (!token || !chatId) { console.log('Telegram credentials not configured'); return null; }
        const text = `💬 <b>[선수 메시지]</b>\n${messageText}\n<i>${dateString} ${timeString}</i>`;
        await sendTelegramMessage(text, token, chatId);
        console.log('Telegram message notification sent');
      } else {
        const recipientEmail = settings.notificationEmail;
        if (!recipientEmail) { console.log('No email configured'); return null; }
        await mailTransport.sendMail({
          from: `Quiver Hub <${gmailEmail}>`,
          to: recipientEmail,
          subject: `[PLAYER] New Chat Message (${timeString}) - ${dateString}`,
          html: `<p><b>Message:</b> ${messageText}</p><p><b>Time:</b> ${timeString} - ${dateString}</p>`,
        });
        console.log('Email message notification sent to:', recipientEmail);
      }
      return null;
    } catch (error) {
      console.error('Error sending message notification:', error);
      return null;
    }
  });

// ── 출석 IN/OUT 알림 ─────────────────────────────────────────
exports.sendNotificationOnAttendance = functions.firestore
  .document('attendance_logs/{logId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();

    try {
      const settings = await getAdminSettings();
      const method = settings.notificationMethod || 'telegram';
      const { timeString, dateString } = formatDateTime(data.timestamp);
      const name = data.name || 'Unknown';
      const status = data.status || 'UNKNOWN';

      if (method === 'telegram') {
        const token = settings.telegramBotToken;
        const chatId = settings.telegramChatId;
        if (!token || !chatId) { console.log('Telegram credentials not configured'); return null; }
        const emoji = status === 'IN' ? '🟢' : '🔴';
        const text = `${emoji} <b>[${status}]</b> ${name}\n<i>${dateString} ${timeString}</i>`;
        await sendTelegramMessage(text, token, chatId);
        console.log('Telegram attendance notification sent');
      } else {
        const recipientEmail = settings.notificationEmail;
        if (!recipientEmail) { console.log('No email configured'); return null; }
        await mailTransport.sendMail({
          from: `Quiver Hub <${gmailEmail}>`,
          to: recipientEmail,
          subject: `[${status}] - ${name} (${timeString}) - ${dateString}`,
          html: `<p><b>Athlete:</b> ${name}</p><p><b>Status:</b> ${status}</p><p><b>Time:</b> ${timeString} - ${dateString}</p>`,
        });
        console.log('Email attendance notification sent to:', recipientEmail);
      }
      return null;
    } catch (error) {
      console.error('Error sending attendance notification:', error);
      return null;
    }
  });

// ── 스케줄 정리 (매일 새벽 3시 KST) ────────────────────────
exports.scheduledCleanup = functions.pubsub
  .schedule('0 18 * * *')
  .timeZone('UTC')
  .onRun(async (context) => {
    const db = admin.firestore();
    const now = new Date();
    const twoDaysAgo = new Date(now.getTime() - (2 * 24 * 60 * 60 * 1000));
    const cutoff = admin.firestore.Timestamp.fromDate(twoDaysAgo);

    console.log(`Cleanup started. Deleting records older than: ${twoDaysAgo.toISOString()}`);
    let totalDeleted = 0;

    async function batchDelete(query, label) {
      let deleted = 0;
      let snapshot = await query.limit(500).get();
      while (!snapshot.empty) {
        const batch = db.batch();
        snapshot.docs.forEach((doc) => batch.delete(doc.ref));
        await batch.commit();
        deleted += snapshot.size;
        console.log(`  [${label}] Deleted batch of ${snapshot.size}`);
        snapshot = await query.limit(500).get();
      }
      console.log(`  [${label}] Total deleted: ${deleted}`);
      return deleted;
    }

    totalDeleted += await batchDelete(
      db.collection('attendance_logs').where('timestamp', '<', cutoff),
      'attendance_logs'
    );
    totalDeleted += await batchDelete(
      db.collection('chats').doc('main_thread').collection('messages').where('timestamp', '<', cutoff),
      'chat_messages'
    );

    console.log(`Cleanup complete. Total documents deleted: ${totalDeleted}`);
    return null;
  });
