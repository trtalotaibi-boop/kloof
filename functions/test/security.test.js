const {before, beforeEach, describe, test} = require("node:test");
const assert = require("node:assert/strict");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, Timestamp} = require("firebase-admin/firestore");
const {
  createBookingCore,
  createSlotId,
  provisionBarberCore,
  updateBookingStatusCore,
} = require("../lib/booking");
const {
  writeBookingCreatedNotifications,
  writeBookingStatusNotification,
} = require("../lib/notifications");

const projectId = "demo-kloof-functions";
const barberId = "barber-one";
const customerId = "customer-one";
const otherCustomerId = "customer-two";
const slotStartMillis = Date.parse("2030-01-02T07:00:00Z");
let db;
let requestCounter;

function nextClientRequestId() {
  requestCounter += 1;
  return requestCounter.toString(16).padStart(32, "0");
}

async function clearFirestore() {
  if (!process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error("FIRESTORE_EMULATOR_HOST is required; refusing production access.");
  }
  const response = await fetch(
      `http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/` +
      `${projectId}/databases/(default)/documents`,
      {method: "DELETE"},
  );
  assert.equal(response.ok, true);
}

async function seedCustomer(uid, name) {
  await db.collection("users").doc(uid).set({
    fullName: name,
    role: "customer",
    createdAt: Timestamp.now(),
  });
}

async function seedBookingData() {
  await Promise.all([
    seedCustomer(customerId, "Customer One"),
    seedCustomer(otherCustomerId, "Customer Two"),
    db.collection("users").doc(barberId).set({
      fullName: "Barber One",
      role: "barber",
      createdAt: Timestamp.now(),
    }),
    db.collection("barbers").doc(barberId).set({
      uid: barberId,
      ownerUid: barberId,
      fullName: "Barber One",
      isOnline: true,
      services: [{name: "Haircut", price: 50, duration: 30}],
      workingHours: {
        workingDays: ["Wed"],
        openingTime: "8:00 AM",
        closingTime: "5:00 PM",
        appointmentDuration: 15,
        breakStart: "12:00 PM",
        breakEnd: "1:00 PM",
      },
      createdAt: Timestamp.now(),
    }),
  ]);
}

async function create(uid = customerId, overrides = {}) {
  const clientRequestId = Object.hasOwn(overrides, "clientRequestId") ?
    overrides.clientRequestId : nextClientRequestId();
  return createBookingCore({
    db,
    uid,
    nowMillis: Date.parse("2029-01-01T00:00:00Z"),
    data: {
      barberId,
      service: "Haircut",
      slotStartMillis,
      ...overrides,
      clientRequestId,
    },
  });
}

describe("trusted booking and barber provisioning", () => {
  before(() => {
    if (!process.env.FIRESTORE_EMULATOR_HOST) {
      throw new Error("Run tests through firebase emulators:exec.");
    }
    initializeApp({projectId});
    db = getFirestore();
  });
  beforeEach(async () => {
    requestCounter = 0;
    await clearFirestore();
    await seedBookingData();
  });

  test("secure callable derives identity, price, duration, and customer name", async () => {
    const result = await create(customerId, {
      customerId: otherCustomerId,
      servicePrice: 1,
      duration: 5,
    });
    const booking = (await db.collection("bookings").doc(result.bookingId).get()).data();
    assert.equal(booking.customerId, customerId);
    assert.equal(booking.customerName, "Customer One");
    assert.equal(booking.servicePrice, 50);
    assert.equal(booking.serviceDuration, 30);
    assert.equal(booking.status, "pending");
    assert.equal(booking.clientRequestId.length, 32);
    assert.equal(result.reused, false);
    assert.equal(booking.slotIds.length, 2);
    assert.equal((await db.collection("bookingSlots").get()).size, 2);
  });

  test("working hours and service duration are validated", async () => {
    await assert.rejects(
        create(customerId, {slotStartMillis: Date.parse("2030-01-02T15:00:00Z")}),
        (error) => error.code === "failed-precondition",
    );
    await db.collection("barbers").doc(barberId).update({
      services: [{name: "Haircut", price: 50}],
    });
    await assert.rejects(
        create(),
        (error) => error.code === "failed-precondition",
    );
  });

  test("Backend slot id uses the same Riyadh yyyyMMdd and HHmm", () => {
    assert.equal(
        createSlotId("barber", Date.parse("2026-08-20T17:00:00Z")),
        "barber--20260820--2000",
    );
  });

  test("45-minute service creates three 15-minute Riyadh locks", async () => {
    await db.collection("barbers").doc(barberId).update({
      services: [{name: "Haircut", price: 50, duration: 45}],
    });
    const booking = await create();
    const data = (await db.collection("bookings").doc(booking.bookingId).get())
        .data();
    assert.deepEqual(data.slotIds, [
      `${barberId}--20300102--1000`,
      `${barberId}--20300102--1015`,
      `${barberId}--20300102--1030`,
    ]);
  });

  test("60-minute service creates four 15-minute Riyadh locks", async () => {
    await db.collection("barbers").doc(barberId).update({
      services: [{name: "Haircut", price: 50, duration: 60}],
    });
    const booking = await create();
    const data = (await db.collection("bookings").doc(booking.bookingId).get())
        .data();
    assert.deepEqual(data.slotIds, [
      `${barberId}--20300102--1000`,
      `${barberId}--20300102--1015`,
      `${barberId}--20300102--1030`,
      `${barberId}--20300102--1045`,
    ]);
  });

  test("overlapping concurrent bookings cannot double book", async () => {
    const results = await Promise.allSettled([
      create(customerId),
      create(otherCustomerId),
    ]);
    assert.equal(results.filter((result) => result.status === "fulfilled").length, 1);
    const rejected = results.find((result) => result.status === "rejected");
    assert.equal(rejected.reason.code, "already-exists");
    assert.equal((await db.collection("bookings").get()).size, 1);
  });

  test("a successful retry returns the same booking without duplicates", async () => {
    const clientRequestId = "a".repeat(32);
    const first = await create(customerId, {clientRequestId});
    const retry = await create(customerId, {clientRequestId});

    assert.equal(first.bookingId, retry.bookingId);
    assert.equal(first.reused, false);
    assert.equal(retry.reused, true);
    assert.equal((await db.collection("bookings").get()).size, 1);
    assert.equal((await db.collection("bookingSlots").get()).size, 2);
  });

  test("concurrent requests with the same id create one booking", async () => {
    const clientRequestId = "b".repeat(32);
    const results = await Promise.all([
      create(customerId, {clientRequestId}),
      create(customerId, {clientRequestId}),
    ]);

    assert.equal(results[0].bookingId, results[1].bookingId);
    assert.equal(results.filter((result) => result.reused === false).length, 1);
    assert.equal(results.filter((result) => result.reused === true).length, 1);
    assert.equal((await db.collection("bookings").get()).size, 1);
  });

  test("different request ids for one slot still cannot double book", async () => {
    await create(customerId, {clientRequestId: "c".repeat(32)});
    await assert.rejects(
        create(customerId, {clientRequestId: "d".repeat(32)}),
        (error) => error.code === "already-exists",
    );
    assert.equal((await db.collection("bookings").get()).size, 1);
  });

  test("request ids are scoped to the authenticated customer", async () => {
    const clientRequestId = "e".repeat(32);
    const first = await create(customerId, {clientRequestId});
    const second = await create(otherCustomerId, {
      clientRequestId,
      slotStartMillis: slotStartMillis + (30 * 60 * 1000),
    });

    assert.notEqual(first.bookingId, second.bookingId);
    assert.equal((await db.collection("bookings").get()).size, 2);
    assert.equal(
        (await db.collection("bookings").doc(first.bookingId).get())
            .data().customerId,
        customerId,
    );
    assert.equal(
        (await db.collection("bookings").doc(second.bookingId).get())
            .data().customerId,
        otherCustomerId,
    );
  });

  test("invalid request ids are rejected", async () => {
    for (const clientRequestId of ["", "short", "A".repeat(32), "g".repeat(32)]) {
      await assert.rejects(
          create(customerId, {clientRequestId}),
          (error) => error.code === "invalid-argument",
      );
    }
  });

  test("one request id cannot be reused for different booking input", async () => {
    const clientRequestId = "f".repeat(32);
    await create(customerId, {clientRequestId});
    await assert.rejects(
        create(customerId, {
          clientRequestId,
          slotStartMillis: slotStartMillis + (60 * 60 * 1000),
        }),
        (error) => error.code === "already-exists",
    );
  });

  test("only the assigned barber changes status and rejection releases all locks", async () => {
    const booking = await create();
    await assert.rejects(
        updateBookingStatusCore({db, uid: "barber-two", data: {bookingId: booking.bookingId, status: "rejected"}}),
        (error) => error.code === "permission-denied",
    );
    await updateBookingStatusCore({
      db,
      uid: barberId,
      data: {bookingId: booking.bookingId, status: "rejected"},
    });
    assert.equal((await db.collection("bookingSlots").get()).empty, true);
  });

  test("assigned barber accepts and completes a pending booking", async () => {
    const booking = await create();
    const accepted = await updateBookingStatusCore({
      db,
      uid: barberId,
      data: {bookingId: booking.bookingId, status: "accepted"},
    });
    assert.equal(accepted.updated, true);
    assert.equal(
        (await db.collection("bookings").doc(booking.bookingId).get())
            .data().status,
        "accepted",
    );

    const completed = await updateBookingStatusCore({
      db,
      uid: barberId,
      data: {bookingId: booking.bookingId, status: "completed"},
    });
    assert.equal(completed.updated, true);
    assert.equal(
        (await db.collection("bookings").doc(booking.bookingId).get())
            .data().status,
        "completed",
    );
    assert.equal((await db.collection("bookingSlots").get()).size, 2);
  });

  test("invalid and repeated status transitions are rejected", async () => {
    const booking = await create();
    const update = (status) => updateBookingStatusCore({
      db,
      uid: barberId,
      data: {bookingId: booking.bookingId, status},
    });

    await assert.rejects(
        update("completed"),
        (error) => error.code === "failed-precondition",
    );
    await update("accepted");
    await assert.rejects(
        update("accepted"),
        (error) => error.code === "failed-precondition",
    );
    await assert.rejects(
        update("rejected"),
        (error) => error.code === "failed-precondition",
    );
    await update("completed");
    await assert.rejects(
        update("completed"),
        (error) => error.code === "failed-precondition",
    );
  });

  test("trusted provisioning separates private phone and rejects non-admin callers", async () => {
    const auth = {
      getUser: async (uid) => ({uid, email: "barber@example.com", customClaims: {}}),
      setCustomUserClaims: async () => {},
    };
    await assert.rejects(
        provisionBarberCore({db, auth, isAdmin: false, data: {uid: "new-barber", fullName: "New Barber"}}),
        (error) => error.code === "permission-denied",
    );
    await provisionBarberCore({
      db,
      auth,
      isAdmin: true,
      data: {uid: "new-barber", fullName: "New Barber", phone: "+966500000099"},
    });
    const publicData = (await db.collection("barbers").doc("new-barber").get()).data();
    const privateData = (await db.collection("barberPrivate").doc("new-barber").get()).data();
    assert.equal(publicData.phone, undefined);
    assert.equal(privateData.phone, "+966500000099");
    assert.equal((await db.collection("users").doc("new-barber").get()).data().role, "barber");
  });

  test("Admin notification flow creates idempotent recipient-owned documents", async () => {
    const booking = await create();
    const bookingData = (await db.collection("bookings").doc(booking.bookingId).get()).data();
    await writeBookingCreatedNotifications(db, booking.bookingId, bookingData);
    await writeBookingCreatedNotifications(db, booking.bookingId, bookingData);
    assert.equal((await db.collection("notifications").get()).size, 2);
    await writeBookingStatusNotification(db, booking.bookingId, {
      ...bookingData,
      status: "accepted",
    });
    const notifications = await db.collection("notifications").get();
    assert.equal(notifications.size, 3);
    assert.equal(notifications.docs.every((doc) => Boolean(doc.data().recipientId)), true);
  });
});
