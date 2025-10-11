const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {defineSecret} = require("firebase-functions/params");
const admin = require("firebase-admin");
const {google} = require("googleapis");

admin.initializeApp();

const GOOGLE_SERVICE_ACCOUNT_KEY = defineSecret("GOOGLE_SERVICE_ACCOUNT_KEY");
const SPREADSHEET_ID = "1C_jy4xH6TqCbYF1BfICAPRnhJQsN_JZ8IkXS77mZfcU";

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

    // JSON.parse()를 사용하지 않고, 전체 키를 사용하도록 수정
    const credentials = JSON.parse(GOOGLE_SERVICE_ACCOUNT_KEY.value());

    const auth = new google.auth.GoogleAuth({
        credentials, // 파싱된 전체 객체를 전달
        scopes: ["https://www.googleapis.com/auth/spreadsheets"],
    });

    const sheets = google.sheets({version: "v4", auth});

    const kstDate = new Date(logData.timestamp.toMillis());
    const dateString = kstDate.toLocaleDateString("ko-KR", {year: "2-digit", month: "2-digit", day: "2-digit", timeZone: "Asia/Seoul"}).replace(/\. /g, ".").slice(0, -1);
    const timeString = kstDate.toLocaleTimeString("ko-KR", {hour12: false, timeZone: "Asia/Seoul"});

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
