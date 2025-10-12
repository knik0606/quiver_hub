module.exports = {
    root: true,
    env: {
        es6: true,
        node: true,
    },
    extends: [
        "eslint:recommended",
        "google",
    ],
    parserOptions: {
        ecmaVersion: 2020, // 최신 JS 문법을 이해하도록 설정
    },
    rules: {
        "quotes": ["error", "double"],
        "indent": ["error", 4], // 들여쓰기를 4칸으로 강제
        "max-len": "off", // 최대 길이 제한 해제
        "require-jsdoc": "off", // <-- 이 줄을 추가하세요.

    },
};
