const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");

initializeApp();

const REGION = "me-central2";

function arabicServiceName(value) {
  const service = String(value || "").trim();
  const localized = {
    "haircut": "حلاقة الرأس",
    "beard trim": "حلاقة الدقن",
    "haircut + beard": "حلاقة الرأس والدقن",
    "kids haircut": "حلاقة أطفال",
    "full head shave (zero cut)": "حلاقة الرأس بالمكينة",
    "beard machine shave": "حلاقة الدقن بالمكينة",
  };
  return localized[service.toLowerCase()] || service;
}

async function sendToUser({uid, title, body, bookingId, target}) {
  if (!uid) return;

  const tokensSnapshot = await getFirestore()
      .collection("users")
      .doc(uid)
      .collection("pushTokens")
      .get();
  if (tokensSnapshot.empty) return;

  const tokenDocs = tokensSnapshot.docs.filter((doc) => {
    const token = doc.data().token;
    return typeof token === "string" && token.length > 0;
  });
  if (tokenDocs.length === 0) return;

  const response = await getMessaging().sendEachForMulticast({
    tokens: tokenDocs.map((doc) => doc.data().token),
    notification: {title, body},
    data: {
      bookingId,
      recipientId: uid,
      target,
    },
    apns: {
      payload: {
        aps: {sound: "default"},
      },
    },
  });

  const invalidCodes = new Set([
    "messaging/invalid-registration-token",
    "messaging/registration-token-not-registered",
  ]);
  const deletions = [];
  response.responses.forEach((result, index) => {
    if (!result.success && invalidCodes.has(result.error?.code)) {
      deletions.push(tokenDocs[index].ref.delete());
    }
  });
  await Promise.all(deletions);
}

exports.notifyBarberOfNewBooking = onDocumentCreated(
    {document: "bookings/{bookingId}", region: REGION},
    async (event) => {
      const booking = event.data?.data();
      if (!booking) return;

      const service = arabicServiceName(booking.service);
      const selectedTime = String(booking.selectedTime || "").trim();
      const details = [service, selectedTime].filter(Boolean).join(" • ");

      await sendToUser({
        uid: String(booking.barberId || ""),
        title: "لديك طلب حجز جديد",
        body: details || "افتح KLOOF لمراجعة طلب الحجز.",
        bookingId: event.params.bookingId,
        target: "barberBookings",
      });
    },
);

exports.notifyCustomerOfBookingStatus = onDocumentUpdated(
    {document: "bookings/{bookingId}", region: REGION},
    async (event) => {
      const before = event.data?.before.data();
      const after = event.data?.after.data();
      if (!before || !after || before.status === after.status) return;

      const statusMessages = {
        accepted: "تم قبول حجزك",
        rejected: "تم رفض حجزك",
      };
      const title = statusMessages[after.status];
      if (!title) return;

      await sendToUser({
        uid: String(after.customerId || ""),
        title,
        body: "افتح KLOOF للاطلاع على تفاصيل الحجز.",
        bookingId: event.params.bookingId,
        target: "myBookings",
      });
    },
);
