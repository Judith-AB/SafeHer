// Give one Firebase Auth account the admin claim so it can call rollbackRiskModel.
// Usage: cd functions && node ../scripts/set_admin.js USER_UID
const admin = require("firebase-admin");
admin.initializeApp();
const uid = process.argv[2];
if (!uid) { console.error("Usage: node scripts/set_admin.js USER_UID"); process.exit(1); }
admin.auth().setCustomUserClaims(uid, { admin: true })
  .then(() => console.log(`admin claim set for ${uid}`))
  .catch((e) => { console.error(e.message); process.exit(1); });
