// Needs the Firestore emulator (Java). Run: npm install && npm test
const { test, before, after } = require("node:test");
const fs = require("node:fs");
const path = require("node:path");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");
const { addDoc, collection, getDocs, serverTimestamp } = require("firebase/firestore");

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-safeher",
    firestore: { rules: fs.readFileSync(path.join(__dirname, "..", "firestore.rules"), "utf8") },
  });
});
after(async () => env.cleanup());

const user = () => env.authenticatedContext("anon-user").firestore();
const guest = () => env.unauthenticatedContext().firestore();
const report = (o = {}) => ({ latitude: 9.931, longitude: 76.267, type: "Stalking", timestamp: serverTimestamp(), ...o });

test("signed-in user can create a rounded report", () => assertSucceeds(addDoc(collection(user(), "incidents"), report())));
test("unauthenticated create is rejected", () => assertFails(addDoc(collection(guest(), "incidents"), report())));
test("6-decimal coordinate is rejected", () => assertFails(addDoc(collection(user(), "incidents"), report({ latitude: 9.931234 }))));
test("unknown category is rejected", () => assertFails(addDoc(collection(user(), "incidents"), report({ type: "Theft" }))));
test("user id field is rejected", () => assertFails(addDoc(collection(user(), "incidents"), report({ anonymous_uid: "abc" }))));
test("long description is rejected", () => assertFails(addDoc(collection(user(), "incidents"), report({ description: "x".repeat(281) }))));
test("location outside India is rejected", () => assertFails(addDoc(collection(user(), "incidents"), report({ latitude: 51.5, longitude: -0.12 }))));
test("client cannot read incidents", () => assertFails(getDocs(collection(user(), "incidents"))));
test("client cannot read SOS events", () => assertFails(getDocs(collection(user(), "sos_events"))));
test("client cannot read legal queries", () => assertFails(getDocs(collection(user(), "unresolved_legal_queries"))));
test("unrounded SOS location is rejected", () =>
  assertFails(addDoc(collection(user(), "sos_events"), { latitude: 9.9312345, longitude: 76.2673, timestamp: serverTimestamp() })));
test("app can read aggregates", () => assertSucceeds(getDocs(collection(guest(), "analytics"))));
test("client cannot read heatmap buckets", () => assertFails(getDocs(collection(guest(), "heatmap_buckets"))));
