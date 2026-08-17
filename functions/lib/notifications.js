const {FieldValue} = require("firebase-admin/firestore");

async function writeNotification(db, {id, recipientId, message, bookingId}) {
  if (!recipientId) return;
  await db.collection("notifications").doc(id).set({
    recipientId,
    message,
    bookingId,
    isRead: false,
    createdAt: FieldValue.serverTimestamp(),
  }, {merge: false});
}

async function writeBookingCreatedNotifications(db, bookingId, booking) {
  await Promise.all([
    writeNotification(db, {
      id: `booking_${bookingId}_customer_submitted`,
      recipientId: String(booking.customerId || ""),
      message: "تم إرسال طلب حجزك.",
      bookingId,
    }),
    writeNotification(db, {
      id: `booking_${bookingId}_barber_new`,
      recipientId: String(booking.barberId || ""),
      message: "لديك طلب حجز جديد.",
      bookingId,
    }),
  ]);
}

async function writeBookingStatusNotification(db, bookingId, booking) {
  const messages = {
    accepted: "تم قبول حجزك.",
    rejected: "تم رفض حجزك.",
    completed: "اكتمل موعدك.",
  };
  const message = messages[booking.status];
  if (!message) return;
  await writeNotification(db, {
    id: `booking_${bookingId}_status_${booking.status}`,
    recipientId: String(booking.customerId || ""),
    message,
    bookingId,
  });
}

module.exports = {
  writeBookingCreatedNotifications,
  writeBookingStatusNotification,
  writeNotification,
};
