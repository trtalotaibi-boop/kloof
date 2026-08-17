import {after, before, beforeEach, describe, test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {assertFails, assertSucceeds, initializeTestEnvironment} from '@firebase/rules-unit-testing';
import {Timestamp, collection, doc, getDoc, getDocs, query, serverTimestamp, setDoc, updateDoc, where} from 'firebase/firestore';

const projectId = 'demo-kloof-rules';
const rulesPath = fileURLToPath(new URL('../firestore.rules', import.meta.url));
const customerId = 'customer-one';
const otherCustomerId = 'customer-two';
const barberId = 'barber-one';
const otherBarberId = 'barber-two';
const slotId = `${barberId}--20300102--1000`;
const slotStart = Timestamp.fromDate(new Date('2030-01-02T07:00:00Z'));
let testEnv;

const dbFor = (uid) => testEnv.authenticatedContext(uid).firestore();

async function seedBaseData() {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    const createdAt = Timestamp.now();
    await Promise.all([
      setDoc(doc(db, 'users', customerId), {fullName: 'Customer One', role: 'customer', createdAt}),
      setDoc(doc(db, 'users', otherCustomerId), {fullName: 'Customer Two', role: 'customer', createdAt}),
      setDoc(doc(db, 'users', barberId), {fullName: 'Barber One', role: 'barber', createdAt}),
      setDoc(doc(db, 'users', otherBarberId), {fullName: 'Barber Two', role: 'barber', createdAt}),
      setDoc(doc(db, 'barbers', barberId), {
        uid: barberId, ownerUid: barberId, fullName: 'Barber One',
        services: [{name: 'Haircut', price: 50, duration: 30}],
        workingHours: {workingDays: ['Wed'], openingTime: '8:00 AM', closingTime: '5:00 PM', appointmentDuration: 15},
        isOnline: true, createdAt,
      }),
      setDoc(doc(db, 'barbers', otherBarberId), {uid: otherBarberId, ownerUid: otherBarberId, fullName: 'Barber Two', isOnline: true, createdAt}),
      setDoc(doc(db, 'barberPrivate', barberId), {phone: '+966500000001', updatedAt: createdAt}),
      setDoc(doc(db, 'bookings', 'booking-one'), {
        barberId, barberName: 'Barber One', customerId,
        customerName: 'Customer One', service: 'Haircut', servicePrice: 50,
        status: 'pending', slotId, slotIds: [slotId], slotStart,
        bookingDate: Timestamp.fromDate(new Date('2030-01-01T21:00:00Z')),
        createdAt,
      }),
      setDoc(doc(db, 'bookingSlots', slotId), {slotId, barberId, slotStart, bookingId: 'booking-one', createdAt}),
      setDoc(doc(db, 'notifications', 'customer-notification'), {recipientId: customerId, message: 'Booking accepted', bookingId: 'booking-one', isRead: false, createdAt}),
    ]);
  });
}

describe('KLOOF Firestore security rules', () => {
  before(async () => {
    testEnv = await initializeTestEnvironment({
      projectId,
      firestore: {host: '127.0.0.1', port: 8080, rules: readFileSync(rulesPath, 'utf8')},
    });
  });
  beforeEach(async () => { await testEnv.clearFirestore(); await seedBaseData(); });
  after(async () => testEnv.cleanup());

  test('profiles are private and role escalation is denied', async () => {
    const db = dbFor(customerId);
    await assertSucceeds(getDoc(doc(db, 'users', customerId)));
    await assertSucceeds(updateDoc(doc(db, 'users', customerId), {fullName: 'Updated'}));
    await assertFails(getDoc(doc(db, 'users', otherCustomerId)));
    await assertFails(updateDoc(doc(db, 'users', customerId), {role: 'barber'}));
    await assertFails(updateDoc(doc(db, 'users', otherCustomerId), {fullName: 'Tampered'}));
  });

  test('customer profile creation works but privileged roles do not', async () => {
    const db = dbFor('new-customer');
    await assertSucceeds(setDoc(doc(db, 'users', 'new-customer'), {fullName: 'New', role: 'customer', createdAt: serverTimestamp()}));
    const attackerDb = dbFor('attacker');
    await assertFails(setDoc(doc(attackerDb, 'users', 'attacker'), {fullName: 'Attacker', role: 'admin', createdAt: serverTimestamp()}));
    await assertFails(setDoc(doc(attackerDb, 'barbers', 'attacker'), {uid: 'attacker', ownerUid: 'attacker', createdAt: serverTimestamp()}));
  });

  test('public barber data is readable but customer edits are denied', async () => {
    const db = dbFor(customerId);
    const snapshot = await assertSucceeds(getDoc(doc(db, 'barbers', barberId)));
    assert.equal(snapshot.data().phone, undefined);
    await assertSucceeds(getDocs(collection(db, 'barbers')));
    await assertFails(updateDoc(doc(db, 'barbers', barberId), {isOnline: false}));
  });

  test('barber edits own public profile but cannot put phone there', async () => {
    const db = dbFor(barberId);
    await assertSucceeds(updateDoc(doc(db, 'barbers', barberId), {shopName: 'Updated Shop'}));
    await assertFails(updateDoc(doc(db, 'barbers', barberId), {phone: '+966511111111'}));
  });

  test('barber private phone is owner-only', async () => {
    await assertFails(getDoc(doc(dbFor(customerId), 'barberPrivate', barberId)));
    await assertSucceeds(getDoc(doc(dbFor(barberId), 'barberPrivate', barberId)));
    await assertSucceeds(updateDoc(doc(dbFor(barberId), 'barberPrivate', barberId), {
      phone: '+966522222222',
      updatedAt: serverTimestamp(),
    }));
    await assertFails(getDoc(doc(dbFor(otherBarberId), 'barberPrivate', barberId)));
  });

  test('availability uses slots without exposing foreign bookings', async () => {
    const db = dbFor(otherCustomerId);
    await assertSucceeds(getDoc(doc(db, 'bookingSlots', slotId)));
    await assertSucceeds(getDocs(query(collection(db, 'bookingSlots'), where('barberId', '==', barberId))));
    await assertFails(getDocs(query(collection(db, 'bookings'), where('barberId', '==', barberId))));
  });

  test('clients cannot create bookings, slots, or change status', async () => {
    const customerDb = dbFor(customerId);
    await assertFails(setDoc(doc(customerDb, 'bookings', 'forged'), {customerId, barberId, status: 'pending'}));
    await assertFails(setDoc(doc(customerDb, 'bookingSlots', 'forged'), {barberId}));
    await assertFails(updateDoc(doc(dbFor(barberId), 'bookings', 'booking-one'), {status: 'accepted'}));
  });

  test('booking ownership and minimal customer name snapshot are enforced', async () => {
    await assertSucceeds(getDoc(doc(dbFor(customerId), 'bookings', 'booking-one')));
    await assertSucceeds(getDocs(query(
      collection(dbFor(customerId), 'bookings'),
      where('customerId', '==', customerId),
    )));
    const barberBooking = await assertSucceeds(getDoc(doc(dbFor(barberId), 'bookings', 'booking-one')));
    await assertSucceeds(getDocs(query(
      collection(dbFor(barberId), 'bookings'),
      where('barberId', '==', barberId),
    )));
    assert.equal(barberBooking.data().customerName, 'Customer One');
    assert.equal(barberBooking.data().phone, undefined);
    assert.equal(barberBooking.data().email, undefined);
    await assertFails(getDoc(doc(dbFor(otherCustomerId), 'bookings', 'booking-one')));
    await assertFails(getDoc(doc(dbFor(otherBarberId), 'bookings', 'booking-one')));
  });

  test('notifications are own-read-only and cannot be forged', async () => {
    const db = dbFor(customerId);
    const ref = doc(db, 'notifications', 'customer-notification');
    await assertSucceeds(getDoc(ref));
    await assertSucceeds(getDocs(query(
      collection(db, 'notifications'),
      where('recipientId', '==', customerId),
    )));
    await assertSucceeds(updateDoc(ref, {isRead: true}));
    await assertFails(setDoc(doc(db, 'notifications', 'forged'), {recipientId: customerId, message: 'Forged', isRead: false, createdAt: serverTimestamp()}));
    await assertFails(getDoc(doc(dbFor(otherCustomerId), 'notifications', 'customer-notification')));
  });

  test('push tokens are owner-only', async () => {
    await assertSucceeds(setDoc(doc(dbFor(customerId), 'users', customerId, 'pushTokens', 'one'), {token: 'valid', platform: 'ios', updatedAt: serverTimestamp()}));
    await assertFails(setDoc(doc(dbFor(customerId), 'users', otherCustomerId, 'pushTokens', 'forged'), {token: 'forged', platform: 'ios', updatedAt: serverTimestamp()}));
  });

  test('unauthenticated and unknown collection access is denied', async () => {
    const anonymous = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(anonymous, 'barbers', barberId)));
    await assertFails(setDoc(doc(anonymous, 'unknown', 'document'), {value: true}));
    await assertFails(setDoc(doc(dbFor(customerId), 'unknown', 'document'), {value: true}));
  });
});
