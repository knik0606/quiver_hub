const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');
require('dotenv').config();

admin.initializeApp();

const gmailEmail = process.env.GMAIL_ADDRESS;
const gmailPassword = process.env.GMAIL_APP_PASSWORD;

const mailTransport = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: gmailEmail,
    pass: gmailPassword,
  },
});

/** Helper to fetch admin email */
async function getAdminEmail() {
  const settingsDoc = await admin.firestore().collection('settings').doc('admin_settings').get();
  if (settingsDoc.exists && settingsDoc.data().notificationEmail) {
    return settingsDoc.data().notificationEmail;
  }
  return null;
}

/** Formats a firestore timestamp or date object */
function formatDateTime(dateObj) {
  const date = (dateObj && dateObj.toDate) ? dateObj.toDate() : (dateObj || new Date());
  const timeString = `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`;
  const dateString = `${String(date.getFullYear()).substring(2)}/${String(date.getMonth() + 1).padStart(2, '0')}/${String(date.getDate()).padStart(2, '0')}`;
  return { timeString, dateString };
}

exports.sendEmailOnNewMessage = functions.firestore
  .document('chats/main_thread/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const messageData = snap.data();

    // Only send email for messages sent by PLAYER
    if (messageData.senderType !== 'PLAYER') {
      console.log('Sender is not PLAYER, skipping email');
      return null;
    }

    try {
      const recipientEmail = await getAdminEmail();
      if (!recipientEmail) {
        console.log('Recipient email is not configured, skipping');
        return null;
      }

      const { timeString, dateString } = formatDateTime(messageData.timestamp);
      const messageText = messageData.text || '';
      const emailSubject = `[PLAYER] New Chat Message (${timeString}) - ${dateString}`;
      
      const webAppLink = 'https://quiver-hub.web.app';
      const deleteLink = `${webAppLink}/#/delete_all_messages`;

      const mailOptions = {
        from: `Quiver Hub <${gmailEmail}>`,
        to: recipientEmail,
        subject: emailSubject,
        html: `
          <p><b>Sender:</b> PLAYER</p>
          <p><b>Message:</b> ${messageText}</p>
          <p><b>Time:</b> ${timeString} - ${dateString}</p>
          <hr>
          <p><a href="${webAppLink}">Open Quiver Hub Web App to Reply</a></p>
          <p><a href="${deleteLink}">Delete All Messages from Server</a> (Admin Only)</p>
        `,
      };

      await mailTransport.sendMail(mailOptions);
      console.log('New message email sent to:', recipientEmail);
      return null;
    } catch (error) {
      console.error('Error sending email:', error);
      return null;
    }
  });

/**
 * This function is temporarily disabled to avoid duplicate notifications.
 * The Flutter app now calls a Google Apps Script (GAS) directly to handle 
 * email notifications and sheet logging in the correct timezone (KST).
 */
// exports.sendEmailOnAttendance = functions.firestore
//   .document('attendance_logs/{logId}')
//   .onCreate(async (snap, context) => {
//     const data = snap.data();
//     
//     try {
//       const recipientEmail = await getAdminEmail();
//       if (!recipientEmail) {
//         console.log('Recipient email is not configured, skipping');
//         return null;
//       }
// 
//       const { timeString, dateString } = formatDateTime(data.timestamp);
//       const name = data.name || 'Unknown Athlete';
//       const status = data.status || 'UNKNOWN';
// 
//       const emailSubject = `[${status}] - ${name} (${timeString}) - ${dateString}`;
//       
//       const mailOptions = {
//         from: `Quiver Hub <${gmailEmail}>`,
//         to: recipientEmail,
//         subject: emailSubject,
//         html: `
//           <p><b>Athlete:</b> ${name}</p>
//           <p><b>Status:</b> ${status}</p>
//           <p><b>Time:</b> ${timeString} - ${dateString}</p>
//         `,
//       };
// 
//       await mailTransport.sendMail(mailOptions);
//       console.log('Attendance email sent to:', recipientEmail);
//       return null;
//     } catch (error) {
//       console.error('Error sending attendance email:', error);
//       return null;
//     }
//   });

// ============================================================
// SCHEDULED CLEANUP: Delete records older than 2 days
// Runs every day at 3:00 AM KST (= 18:00 UTC previous day)
// ============================================================
exports.scheduledCleanup = functions.pubsub
  .schedule('0 18 * * *')  // 18:00 UTC = 03:00 KST next day
  .timeZone('UTC')
  .onRun(async (context) => {
    const db = admin.firestore();
    const now = new Date();
    const twoDaysAgo = new Date(now.getTime() - (2 * 24 * 60 * 60 * 1000));
    const cutoff = admin.firestore.Timestamp.fromDate(twoDaysAgo);

    console.log(`Cleanup started. Deleting records older than: ${twoDaysAgo.toISOString()}`);

    let totalDeleted = 0;

    // Helper: batch-delete documents from a query
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

    // 1. Clean attendance_logs
    const attendanceQuery = db.collection('attendance_logs')
      .where('timestamp', '<', cutoff);
    totalDeleted += await batchDelete(attendanceQuery, 'attendance_logs');

    // 2. Clean chat messages
    const messagesQuery = db.collection('chats').doc('main_thread')
      .collection('messages')
      .where('timestamp', '<', cutoff);
    totalDeleted += await batchDelete(messagesQuery, 'chat_messages');

    console.log(`Cleanup complete. Total documents deleted: ${totalDeleted}`);
    return null;
  });
