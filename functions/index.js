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
        console.log("Step 1: Fetching data from Google Sheets...");
        console.log(`Spreadsheet ID: ${SPREADSHEET_ID}`);

        const noticesPromise = sheets.spreadsheets.values.get({
            spreadsheetId: SPREADSHEET_ID,
            range: "Notices!A2:C",
        });
        const schedulesPromise = sheets.spreadsheets.values.get({
            spreadsheetId: SPREADSHEET_ID,
            range: "Schedules!A2:C",
        });
        const adminNotesPromise = sheets.spreadsheets.values.get({
            spreadsheetId: SPREADSHEET_ID,
            range: "AdminNote!A1:C12",
        });

        console.log("Step 2: Awaiting Sheet API responses...");
        const [noticesResponse, schedulesResponse, adminNotesResponse] = await Promise.all([
            noticesPromise,
            schedulesPromise,
            adminNotesPromise,
        ]);

        console.log("Step 3: Data received from Sheets.");
        const notices = noticesResponse.data.values || [];
        const schedules = schedulesResponse.data.values || [];
        const adminNotesAll = adminNotesResponse.data.values || [];

        console.log(`Counts: Notices=${notices.length}, Schedules=${schedules.length}, AdminNotesRaw=${adminNotesAll.length}`);

        // AdminNote Parsing
        let boardNameFromSheet = "";
        let adminNotesData = [];

        if (adminNotesAll.length > 0) {
            if (adminNotesAll[0] && adminNotesAll[0].length >= 3) {
                boardNameFromSheet = adminNotesAll[0][2] || "";
            }
            if (adminNotesAll.length > 2) {
                adminNotesData = adminNotesAll.slice(2);
            }
        }
        console.log(`Parsed AdminNotes: ${adminNotesData.length} items. BoardName: ${boardNameFromSheet}`);

        console.log("Step 4: Clearing old Firestore collections...");
        const noticesSnapshot = await db.collection("notices").get();
        const noticesBatch = db.batch();
        noticesSnapshot.docs.forEach((doc) => noticesBatch.delete(doc.ref));
        await noticesBatch.commit();
        console.log("Notices cleared.");

        const schedulesSnapshot = await db.collection("schedules").get();
        const schedulesBatch = db.batch();
        schedulesSnapshot.docs.forEach((doc) => schedulesBatch.delete(doc.ref));
        await schedulesBatch.commit();
        console.log("Schedules cleared.");

        const adminNotesSnapshot = await db.collection("admin_notes").get();
        const adminNotesBatch = db.batch();
        adminNotesSnapshot.docs.forEach((doc) => adminNotesBatch.delete(doc.ref));
        await adminNotesBatch.commit();
        console.log("AdminNotes cleared.");

        console.log("Step 5: Writing new data to Firestore...");

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
        console.log("Notices written.");

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
        console.log("Schedules written.");

        const adminNotesWriteBatch = db.batch();
        adminNotesData.forEach((row, index) => {
            const content = row[1] || "";
            const imageUrl = row[2] || "";
            if (content || imageUrl) {
                const docRef = db.collection("admin_notes").doc();
                adminNotesWriteBatch.set(docRef, {
                    content: content,
                    imageUrl: convertGoogleDriveUrl(imageUrl),
                    order: index,
                });
            }
        });
        await adminNotesWriteBatch.commit();
        console.log("AdminNotes written.");

        if (boardNameFromSheet) {
            await db.collection("settings").doc("admin_settings").set({
                boardName: boardNameFromSheet
            }, { merge: true });
        }

        console.log("Sync completed successfully.");
        return {
            status: "success",
            noticesCount: notices.length,
            schedulesCount: schedules.length,
            adminNotesCount: adminNotesData.length,
        };
    } catch (err) {
        console.error("FATAL ERROR in syncSheetsToFirestore:", err);
        throw new HttpsError("internal", `Sync Error: ${err.message || err}`);
    }
});

// ▼▼▼ [새로 추가할 부분] 채팅 알림 이메일 발송 함수 ▼▼▼
exports.sendNewMessageEmail = onDocumentCreated({
    document: "chats/main_thread/messages/{messageId}", // 채팅 메시지 컬렉션을 감시
    region: "us-central1",
    secrets: [GMAIL_APP_PASSWORD], // Gmail 앱 비밀번호 시크릿 재사용
}, async (event) => {
    const messageData = event.data.data();
    const messageId = event.params.messageId; // 메시지 문서 ID 가져오기

    // Firestore에서 관리자 이메일 주소를 가져옵니다.
    const settingsDoc = await admin.firestore().collection("settings").doc("admin_settings").get();
    const recipientEmail = settingsDoc.data()?.notificationEmail;

    if (!recipientEmail) {
        console.error("수신자 이메일(채팅)이 설정되지 않았습니다.");
        return;
    }

    // 새 메시지 정보
    const senderType = messageData.senderType || "PLAYER";
    const messageText = messageData.text || "";

    // 서버 시간 기준 (한국 시간)
    const now = new Date();
    const kstDate = new Date(now.getTime() + (9 * 60 * 60 * 1000));
    const timeString = kstDate.toTimeString().split(" ")[0].substring(0, 5); // HH:mm
    const dateString = kstDate.toISOString().split("T")[0].replace(/-/g, "/").substring(2); // yy/MM/dd

    // 이메일 제목과 내용 생성
    const emailSubject = `[${senderType}] New Chat Message (${timeString}) - ${dateString}`;

    // TODO: 삭제 링크와 웹앱 링크를 실제 URL로 변경해야 합니다.
    const deleteLink = `YOUR_DELETE_FUNCTION_URL?messageId=${messageId}`; // 예시: 삭제 처리 함수 URL
    const webAppLink = `YOUR_CHAT_WEB_APP_URL`; // 예시: 채팅 웹앱 URL

    const emailBody = `
        <p><b>Sender:</b> ${senderType}</p>
        <p><b>Message:</b> ${messageText}</p>
        <p><b>Time:</b> ${timeString} - ${dateString}</p>
        <hr>
        <p><a href="${deleteLink}">Delete this message</a></p>
        <p><a href="${webAppLink}">Open Chat Web App</a></p>
    `;

    const transporter = nodemailer.createTransport({
        service: "gmail",
        auth: {
            user: "kkukupo0@gmail.com", // 사용자님의 Gmail 주소
            pass: GMAIL_APP_PASSWORD.value(), // Gmail 앱 비밀번호 시크릿 값
        },
    });

    try {
        await transporter.sendMail({
            from: `"Quiver Hub Chat" <kkukupo0@gmail.com>`, // 보내는 사람 이름 변경
            to: recipientEmail,
            subject: emailSubject,
            html: emailBody,
        });
        console.log("Chat notification email sent successfully to:", recipientEmail);
    } catch (error) {
        console.error("Error sending chat email:", error);
    }
});
// ▲▲▲ 여기까지 새로 추가 ▲▲▲