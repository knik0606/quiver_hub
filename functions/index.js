const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onRequest } = require("firebase-functions/v2/https"); // HTTP 요청을 위해 추가
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const nodemailer = require("nodemailer");
const logger = require("firebase-functions/logger");

initializeApp();

const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: "kkukupo0@gmail.com",
    pass: "bbmeatmwbclzapca",
  },
});

// --- 기능 1: 출석 상태 변경 알림 ---
exports.sendAttendanceEmail = onDocumentCreated("mail/{docId}", async (event) => {
  const mailData = event.data.data();

  const mailOptions = {
    from: "kkukupo0@gmail.com",
    to: mailData.to,
    subject: mailData.subject,
    html: mailData.html,
  };

  try {
    await transporter.sendMail(mailOptions);
    logger.info("Attendance email sent successfully to:", mailData.to);
    return getFirestore().collection("mail").doc(event.params.docId).delete();
  } catch (error) {
    logger.error("Error sending the attendance email:", error);
    return null;
  }
});

// --- 기능 2: 새 메시지 도착 알림 (삭제 링크 포함) ---
exports.sendNewMessageEmail = onDocumentCreated("chats/main_thread/messages/{messageId}", async (event) => {
  const messageData = event.data.data();

  if (messageData.senderType !== 'PLAYER') {
    logger.info("Message from ADMIN, no email sent.");
    return null;
  }

  try {
    const settingsDoc = await getFirestore().collection('settings').doc('admin_settings').get();
    const recipientEmail = settingsDoc.data()?.notificationEmail;

    if (recipientEmail) {
      const now = new Date();
      const timeString = `${now.getHours()}:${now.getMinutes()}`;

      const adminWebUrl = "https://quiver-hub.web.app";
      
      // 삭제를 위한 비밀 키와 URL 생성
      // 중요: quiver-hub가 본인 프로젝트 ID가 맞는지 확인하세요.
      const deleteKey = process.env.DELETE_SECRET_KEY || "your_default_secret"; // 비밀 키 가져오기
      const deleteUrl = `https://us-central1-quiver-hub.cloudfunctions.net/deleteChatHistory?key=${deleteKey}`;

      const mailOptions = {
        from: "kkukupo0@gmail.com",
        to: recipientEmail,
        subject: `[Quiver Hub] - (${timeString})`,
        html: `
          <p>${messageData.text}</p>
          <br>
          <p><a href="${adminWebUrl}">Click here to reply</a></p>
          <hr>
          <p style="font-size:12px;"><a href="${deleteUrl}">Delete all chat history</a></p>
        `,
      };

      await transporter.sendMail(mailOptions);
      logger.info("New message notification sent successfully to:", recipientEmail);
    } else {
      logger.warn("Notification email address is not set.");
    }
    return null;
  } catch (error) {
    logger.error("Error sending new message email:", error);
    return null;
  }
});

// --- 기능 3: 채팅 기록 삭제 (HTTP 요청) ---
exports.deleteChatHistory = onRequest(async (req, res) => {
  // 간단한 보안 확인: 올바른 비밀 키가 URL에 포함되었는지 확인
  const secretKey = process.env.DELETE_SECRET_KEY || "your_default_secret";
  if (req.query.key !== secretKey) {
    logger.error("Unauthorized attempt to delete chat history.");
    res.status(401).send("Unauthorized");
    return;
  }

  try {
    const firestore = getFirestore();
    const messagesRef = firestore.collection('chats/main_thread/messages');
    const snapshot = await messagesRef.get();

    if (snapshot.empty) {
      res.status(200).send("Chat history is already empty.");
      return;
    }

    const batch = firestore.batch();
    snapshot.docs.forEach(doc => {
      batch.delete(doc.ref);
    });
    await batch.commit();

    logger.info("Chat history successfully deleted.");
    res.status(200).send("Chat history has been successfully deleted.");
  } catch (error) {
    logger.error("Error deleting chat history:", error);
    res.status(500).send("An error occurred while deleting chat history.");
  }
});