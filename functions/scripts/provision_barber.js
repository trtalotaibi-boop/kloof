const {applicationDefault, initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore} = require("firebase-admin/firestore");
const {provisionBarberCore} = require("../lib/booking");

const projectId = process.env.KLOOF_FIREBASE_PROJECT_ID;
const uid = process.env.KLOOF_BARBER_UID;
const fullName = process.env.KLOOF_BARBER_FULL_NAME;
const phone = process.env.KLOOF_BARBER_PHONE || "";

if (projectId !== "kloof-1cfcd") {
  throw new Error("KLOOF_FIREBASE_PROJECT_ID must be exactly kloof-1cfcd.");
}
if (!uid || !fullName) {
  throw new Error("KLOOF_BARBER_UID and KLOOF_BARBER_FULL_NAME are required.");
}

initializeApp({credential: applicationDefault(), projectId});

provisionBarberCore({
  db: getFirestore(),
  auth: getAuth(),
  isAdmin: true,
  data: {uid, fullName, phone},
}).then(() => {
  console.log(`Provisioned barber UID ${uid}.`);
}).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
