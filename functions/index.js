const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const nodemailer = require("nodemailer");
const logger = require("firebase-functions/logger");

initializeApp();

const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: "kkukupo0@gmail.com", // <-- 여기에 본인 Gmail 주소 입력
    pass: "bbmeatmwbclzapca",           // <-- 이전에 생성한 16자리 앱 비밀번호
  },
});

exports.sendAttendanceEmail = onDocumentCreated("mail/{docId}", async (event) => {
  const mailData = event.data.data();

  const mailOptions = {
    from: "kkukupo0@gmail.com", // <-- 여기에도 본인 Gmail 주소 입력
    to: mailData.to,
    subject: mailData.subject,
    html: mailData.html,
  };

  try {
    await transporter.sendMail(mailOptions);
    logger.info("Email sent successfully to:", mailData.to);
    // 성공 후 문서 삭제
    return getFirestore().collection("mail").doc(event.params.docId).delete();
  } catch (error) {
    logger.error("There was an error while sending the email:", error);
    return null;
  }
});