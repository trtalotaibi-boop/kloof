const {Timestamp, FieldValue} = require("firebase-admin/firestore");
const {HttpsError} = require("firebase-functions/v2/https");

const RIYADH_TIME_ZONE = "Asia/Riyadh";
const DAY_CODES = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

function parseClock(value) {
  const match = String(value || "").trim().match(
      /^(\d{1,2}):(\d{2})(?:\s*([AP]M))?$/i,
  );
  if (!match) return null;
  let hour = Number(match[1]);
  const minute = Number(match[2]);
  const period = match[3]?.toUpperCase();
  if (period) {
    if (hour < 1 || hour > 12) return null;
    if (period === "PM" && hour !== 12) hour += 12;
    if (period === "AM" && hour === 12) hour = 0;
  }
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return (hour * 60) + minute;
}

function riyadhParts(milliseconds) {
  const formatter = new Intl.DateTimeFormat("en-US", {
    timeZone: RIYADH_TIME_ZONE,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hourCycle: "h23",
  });
  const values = Object.fromEntries(
      formatter.formatToParts(new Date(milliseconds))
          .filter((part) => part.type !== "literal")
          .map((part) => [part.type, Number(part.value)]),
  );
  const localDateUtc = Date.UTC(values.year, values.month - 1, values.day);
  return {
    ...values,
    minutes: (values.hour * 60) + values.minute,
    dayCode: DAY_CODES[new Date(localDateUtc).getUTCDay()],
  };
}

function createSlotId(barberId, milliseconds) {
  const parts = riyadhParts(milliseconds);
  const date = `${parts.year}${String(parts.month).padStart(2, "0")}` +
    `${String(parts.day).padStart(2, "0")}`;
  const time = `${String(parts.hour).padStart(2, "0")}` +
    `${String(parts.minute).padStart(2, "0")}`;
  return `${barberId}--${date}--${time}`;
}

function requireString(value, field) {
  const result = typeof value === "string" ? value.trim() : "";
  if (!result) {
    throw new HttpsError("invalid-argument", `${field} is required.`);
  }
  return result;
}

function findService(services, requestedName) {
  if (!Array.isArray(services)) return null;
  const normalized = requestedName.toLocaleLowerCase("en-US");
  return services.find((item) => item && typeof item === "object" &&
    String(item.name || "").trim().toLocaleLowerCase("en-US") === normalized);
}

async function createBookingCore({db, uid, data, nowMillis = Date.now()}) {
  if (!uid) throw new HttpsError("unauthenticated", "Sign-in is required.");

  const barberId = requireString(data?.barberId, "barberId");
  const requestedService = requireString(data?.service, "service");
  const slotStartMillis = Number(data?.slotStartMillis);
  if (!Number.isSafeInteger(slotStartMillis) || slotStartMillis % 60000 !== 0) {
    throw new HttpsError("invalid-argument", "slotStartMillis is invalid.");
  }
  if (slotStartMillis <= nowMillis) {
    throw new HttpsError("invalid-argument", "The slot must be in the future.");
  }

  const customerRef = db.collection("users").doc(uid);
  const barberUserRef = db.collection("users").doc(barberId);
  const barberRef = db.collection("barbers").doc(barberId);
  const bookingRef = db.collection("bookings").doc();

  await db.runTransaction(async (transaction) => {
    const [customerSnapshot, barberUserSnapshot, barberSnapshot] =
      await transaction.getAll(customerRef, barberUserRef, barberRef);
    const customer = customerSnapshot.data();
    const barber = barberSnapshot.data();
    if (!customer || customer.role !== "customer") {
      throw new HttpsError("permission-denied", "Customer account required.");
    }
    if (barberUserSnapshot.data()?.role !== "barber" || !barber ||
        barber.uid !== barberId || barber.ownerUid !== barberId) {
      throw new HttpsError("not-found", "Barber not found.");
    }
    if (barber.isOnline !== true) {
      throw new HttpsError("failed-precondition", "Barber is unavailable.");
    }

    const service = findService(barber.services, requestedService);
    const serviceDuration = service?.duration;
    const servicePrice = service?.price;
    if (!service || !Number.isInteger(serviceDuration) || serviceDuration <= 0 ||
        typeof servicePrice !== "number" || !Number.isFinite(servicePrice) ||
        servicePrice < 0) {
      throw new HttpsError(
          "failed-precondition",
          "The selected service is not fully configured.",
      );
    }

    const hours = barber.workingHours;
    const opening = parseClock(hours?.openingTime);
    const closing = parseClock(hours?.closingTime);
    const interval = Number(hours?.appointmentDuration);
    const workingDays = Array.isArray(hours?.workingDays) ?
      hours.workingDays.map(String) : [];
    if (opening === null || closing === null || opening >= closing ||
        !Number.isInteger(interval) || interval <= 0 ||
        !workingDays.length) {
      throw new HttpsError(
          "failed-precondition",
          "Barber working hours are not configured.",
      );
    }

    const parts = riyadhParts(slotStartMillis);
    if (parts.second !== 0 || !workingDays.includes(parts.dayCode) ||
        parts.minutes < opening || parts.minutes + serviceDuration > closing ||
        (parts.minutes - opening) % interval !== 0) {
      throw new HttpsError(
          "failed-precondition",
          "The requested time is outside working hours.",
      );
    }

    const breakStart = parseClock(hours.breakStart);
    const breakEnd = parseClock(hours.breakEnd);
    if (breakStart !== null && breakEnd !== null &&
        parts.minutes < breakEnd &&
        parts.minutes + serviceDuration > breakStart) {
      throw new HttpsError(
          "failed-precondition",
          "The requested time overlaps the barber break.",
      );
    }

    const segmentMillis = [];
    for (let offset = 0; offset < serviceDuration; offset += interval) {
      segmentMillis.push(slotStartMillis + (offset * 60 * 1000));
    }
    const slotRefs = segmentMillis.map((milliseconds) =>
      db.collection("bookingSlots").doc(createSlotId(barberId, milliseconds)),
    );
    const locks = await transaction.getAll(...slotRefs);
    if (locks.some((snapshot) => snapshot.exists)) {
      throw new HttpsError("already-exists", "The slot is already booked.");
    }

    const slotIds = slotRefs.map((ref) => ref.id);
    const slotStart = Timestamp.fromMillis(slotStartMillis);
    const bookingEnd = Timestamp.fromMillis(
        slotStartMillis + (serviceDuration * 60 * 1000),
    );
    const bookingDate = Timestamp.fromMillis(
        Date.UTC(parts.year, parts.month - 1, parts.day) - (3 * 60 * 60 * 1000),
    );
    const customerName = String(
        customer.fullName || customer.displayName || customer.name || "",
    ).trim();
    const barberName = String(
        barber.fullName || barber.name || barber.shopName || "",
    ).trim();

    transaction.set(bookingRef, {
      barberId,
      barberName,
      customerId: uid,
      customerName,
      service: String(service.name).trim(),
      servicePrice,
      serviceDuration,
      selectedTime: `${String(parts.hour).padStart(2, "0")}:` +
        `${String(parts.minute).padStart(2, "0")}`,
      selectedTimeMinutes: parts.minutes,
      status: "pending",
      slotId: slotIds[0],
      slotIds,
      slotStart,
      bookingEnd,
      bookingDate,
      createdAt: FieldValue.serverTimestamp(),
    });
    slotRefs.forEach((ref, index) => {
      transaction.set(ref, {
        slotId: ref.id,
        barberId,
        slotStart: Timestamp.fromMillis(segmentMillis[index]),
        bookingStart: slotStart,
        bookingEnd,
        bookingId: bookingRef.id,
        createdAt: FieldValue.serverTimestamp(),
      });
    });
  });

  return {bookingId: bookingRef.id};
}

async function provisionBarberCore({
  db,
  auth,
  isAdmin,
  data,
}) {
  if (!isAdmin) {
    throw new HttpsError("permission-denied", "Admin authorization required.");
  }
  const uid = requireString(data?.uid, "uid");
  const fullName = requireString(data?.fullName, "fullName");
  const phone = typeof data?.phone === "string" ? data.phone.trim() : "";
  const authUser = await auth.getUser(uid);
  const userRef = db.collection("users").doc(uid);
  const barberRef = db.collection("barbers").doc(uid);
  const privateRef = db.collection("barberPrivate").doc(uid);

  await db.runTransaction(async (transaction) => {
    transaction.set(userRef, {
      fullName,
      email: authUser.email || "",
      role: "barber",
      createdAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    transaction.set(barberRef, {
      uid,
      ownerUid: uid,
      fullName,
      name: fullName,
      profileImage: "",
      imageUrl: "",
      isOnline: false,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    transaction.set(privateRef, {
      phone,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
  });
  await auth.setCustomUserClaims(uid, {
    ...(authUser.customClaims || {}),
    role: "barber",
  });
  return {uid};
}

async function updateBookingStatusCore({db, uid, data}) {
  if (!uid) throw new HttpsError("unauthenticated", "Sign-in is required.");
  const bookingId = requireString(data?.bookingId, "bookingId");
  const requestedStatus = requireString(data?.status, "status").toLowerCase();
  const bookingRef = db.collection("bookings").doc(bookingId);
  const userRef = db.collection("users").doc(uid);

  return db.runTransaction(async (transaction) => {
    const [bookingSnapshot, userSnapshot] = await transaction.getAll(
        bookingRef,
        userRef,
    );
    const booking = bookingSnapshot.data();
    if (!booking) throw new HttpsError("not-found", "Booking not found.");
    if (userSnapshot.data()?.role !== "barber" || booking.barberId !== uid) {
      throw new HttpsError("permission-denied", "Assigned barber required.");
    }
    const currentStatus = String(booking.status || "pending").toLowerCase();
    const allowed =
      (currentStatus === "pending" &&
        ["accepted", "rejected"].includes(requestedStatus)) ||
      (currentStatus === "accepted" && requestedStatus === "completed");
    if (!allowed) {
      throw new HttpsError("failed-precondition", "Invalid status transition.");
    }

    let slotIds = Array.isArray(booking.slotIds) ?
      booking.slotIds.map(String).filter(Boolean) : [];
    if (!slotIds.length && booking.slotId) slotIds = [String(booking.slotId)];
    const slotRefs = slotIds.map((slotId) =>
      db.collection("bookingSlots").doc(slotId),
    );
    const slots = requestedStatus === "rejected" && slotRefs.length ?
      await transaction.getAll(...slotRefs) : [];

    transaction.update(bookingRef, {status: requestedStatus});
    slots.forEach((slot, index) => {
      if (slot.data()?.bookingId === bookingId) {
        transaction.delete(slotRefs[index]);
      }
    });
    return {updated: true};
  });
}

module.exports = {
  createBookingCore,
  createSlotId,
  parseClock,
  provisionBarberCore,
  riyadhParts,
  updateBookingStatusCore,
};
