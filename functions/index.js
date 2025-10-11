const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onCall} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const admin = require("firebase-admin");
const {google} = require("googleapis");
const functions = require("firebase-functions");

admin.initializeApp();

const GOOGLE_SERVICE_ACCOUNT_KEY = defineSecret("GOOGLE_SERVICE_ACCOUNT_KEY");
const SPREADSHEET_ID = "1C_jy4xH6TqCbYF1BfICAPRnhJQsN_JZ8IkXS77mZfcU";

// 기존 출석 기록 함수
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
    const sheets = google.sheets({version: "v4", auth});
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
            resource: {values},
        });
        console.log("Successfully wrote to sheet:", values);
    } catch (err) {
        console.error("Error writing to sheet:", err);
    }
});

// Notices와 Schedules 동기화 함수
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
    const sheets = google.sheets({version: "v4", auth});

    try {
        const noticesPromise = sheets.spreadsheets.values.get({
            spreadsheetId: SPREADSHEET_ID,
            range: "Notices!A2:B",
        });

        const schedulesPromise = sheets.spreadsheets.values.get({
            spreadsheetId: SPREADSHEET_ID,
            range: "Schedules!A2:B",
        });

        const [noticesResponse, schedulesResponse] = await Promise.all([
            noticesPromise,
            schedulesPromise,
        ]);

        const notices = noticesResponse.data.values || [];
        const schedules = schedulesResponse.data.values || [];

        console.log("읽어온 공지사항:", JSON.stringify(notices, null, 2));
        console.log("읽어온 스케줄:", JSON.stringify(schedules, null, 2));

        return {
            status: "success",
            noticesCount: notices.length,
            schedulesCount: schedules.length,
        };
    } catch (err) {
        console.error("시트 읽기 오류:", err);
        throw new functions.https.HttpsError("internal", "시트를 읽는 도중 에러가 발생했습니다.");
    }
});
