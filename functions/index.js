const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const { google } = require("googleapis");
const nodemailer = require("nodemailer");

admin.initializeApp();

const GOOGLE_SERVICE_ACCOUNT_KEY = defineSecret("GOOGLE_SERVICE_ACCOUNT_KEY");
const GMAIL_APP_PASSWORD = defineSecret("GMAIL_APP_PASSWORD");
const SPREADSHEET_ID = "1C_jy4xH6TqCbYF1BfICAPRnhJQsN_JZ8IkXS77mZfcU";

function convertGoogleDriveUrl(url) {
    if (!url || !url.includes("drive.google.com")) return "";
    const regex = /drive\.google\.com\/file\/d\/([a-zA-Z0-9_-]+)/;
    const match = url.match(regex);
    if (match && match[1]) {
        const fileId = match[1];
        return `https://drive.google.com/uc?export=view&id=${fileId}`;
    }
    return "";
}

exports.sendAttendanceEmail = onDocumentCreated({
    document: "mail/{mailId}",
    region: "us-central1",
    secrets: [GMAIL_APP_PASSWORD],
}, async (event) => {
    const mailData = event.data.data();
    const { name, status } = mailData;

    const settingsDoc = await admin.firestore().collection("settings").doc("admin_settings").get();
    const recipientEmail = settingsDoc.data()?.notificationEmail;

    if (!recipientEmail) {
        console.error("수신자 이메일이 설정되지 않았습니다.");
        return;
    }

    const now = new Date();
    const kstDate = new Date(now.getTime() + (9 * 60 * 60 * 1000));
    const timeString = kstDate.toTimeString().split(" ")[0].substring(0, 5);
    const dateString = kstDate.toISOString().split("T")[0].replace(/-/g, "/").substring(2);

    const emailSubject = `[${status}] - ${name} (${timeString}) - ${dateString}`;
    const emailBody = `
        <p><b>${name}</b> - [${status}]</p>
        <p><b>Time:</b> ${timeString} - ${dateString}</p>
    `;

    const transporter = nodemailer.createTransport({
        service: "gmail",
        auth: {
            user: "kkukupo0@gmail.com",
            pass: GMAIL_APP_PASSWORD.value(),
        },
    });

    try {
        await transporter.sendMail({
            from: `"Quiver Hub" <kkukupo0@gmail.com>`,
            to: recipientEmail,
            subject: emailSubject,
            html: emailBody,
        });
        console.log("Email sent successfully to:", recipientEmail);
    } catch (error) {
        console.error("Error sending email:", error);
    }
});

exports.logAttendanceToSheet = onDocumentCreated({
    document: "attendance_logs/{logId}",
    secrets: [GOOGLE_SERVICE_ACCOUNT_KEY],
    region: "us-central1",
    maxInstances: 1,
}, async (event) => {
    const snap = event.data;
    if (!snap) {
        console.error("No data associated with the event");
        return;
    }
    const logData = snap.data();
    const credentials = JSON.parse(GOOGLE_SERVICE_ACCOUNT_KEY.value());
    const auth = new google.auth.GoogleAuth({
        credentials,
        scopes: ["https://www.googleapis.com/auth/spreadsheets"],
    });
    const sheets = google.sheets({ version: "v4", auth });
    const kstDate = new Date(logData.timestamp.toMillis());
    const dateString = kstDate.toLocaleDateString("ko-KR", {
        year: "2-digit",
        month: "2-digit",
        day: "2-digit",
        timeZone: "Asia/Seoul",
    }).replace(/\. /g, ".").slice(0, -1);
    const timeString = kstDate.toLocaleTimeString("ko-KR", {
        hour12: false,
        timeZone: "Asia/Seoul",
    });
    const values = [[dateString, timeString, logData.name, logData.status]];
    try {
        await sheets.spreadsheets.values.append({
            spreadsheetId: SPREADSHEET_ID,
            range: "Attendance!A:D",
            valueInputOption: "USER_ENTERED",
            resource: { values },
        });
        console.log("Successfully wrote to sheet:", values);
    } catch (err) {
        console.error("Error writing to sheet:", err);
    }
});

exports.syncSheetsToFirestore = onCall({
    region: "us-central1",
    secrets: [GOOGLE_SERVICE_ACCOUNT_KEY],
}, async (request) => {
    console.log("syncSheetsToFirestore 함수가 호출되었습니다.");
    const credentials = JSON.parse(GOOGLE_SERVICE_ACCOUNT_KEY.value());
    const auth = new google.auth.GoogleAuth({
        credentials,
        scopes: ["https://www.googleapis.com/auth/spreadsheets"],
    });
    const sheets = google.sheets({ version: "v4", auth });
    const db = admin.firestore();

    try {
        const noticesPromise = sheets.spreadsheets.values.get({
            spreadsheetId: SPREADSHEET_ID,
            range: "Notices!A2:C",
        });
        const schedulesPromise = sheets.spreadsheets.values.get({
            spreadsheetId: SPREADSHEET_ID,
            range: "Schedules!A2:C",
        });

        const [noticesResponse, schedulesResponse] = await Promise.all([
            noticesPromise,
            schedulesPromise,
        ]);
        const notices = noticesResponse.data.values || [];
        const schedules = schedulesResponse.data.values || [];

        const noticesSnapshot = await db.collection("notices").get();
        const noticesBatch = db.batch();
        noticesSnapshot.docs.forEach((doc) => noticesBatch.delete(doc.ref));
        await noticesBatch.commit();
        const schedulesSnapshot = await db.collection("schedules").get();
        const schedulesBatch = db.batch();
        schedulesSnapshot.docs.forEach((doc) => schedulesBatch.delete(doc.ref));
        await schedulesBatch.commit();

        const noticesWriteBatch = db.batch();
        notices.forEach((row, index) => {
            const docRef = db.collection("notices").doc();
            noticesWriteBatch.set(docRef, {
                pageNumber: row[0] || "",
                content: row[1] || "",
                imageUrl: convertGoogleDriveUrl(row[2] || ""),
                order: index,
            });
        });
        await noticesWriteBatch.commit();

        const schedulesWriteBatch = db.batch();
        schedules.forEach((row, index) => {
            const docRef = db.collection("schedules").doc();
            schedulesWriteBatch.set(docRef, {
                page: row[1] || "",
                imageUrl: convertGoogleDriveUrl(row[2] || ""),
                order: index,
            });
        });
        await schedulesWriteBatch.commit();

        console.log(`Notices ${notices.length}개, Schedules ${schedules.length}개 동기화 완료.`);
        return {
            status: "success",
            noticesCount: notices.length,
            schedulesCount: schedules.length,
        };
    } catch (err) {
        console.error("시트 동기화 오류:", err);
        throw new HttpsError("internal", "시트를 동기화하는 도중 에러가 발생했습니다.");
    }
});