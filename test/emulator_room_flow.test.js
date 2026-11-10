// Two independently authenticated clients create/join a room and receive live updates.
// Run: firebase emulators:exec --only auth,firestore,database,functions "node test/emulator_room_flow.test.js"
// Requires the `firebase` client package (NODE_PATH may point at it).
const assert = require('assert');
const {initializeApp} = require('firebase/app');
const {getAuth, connectAuthEmulator, createUserWithEmailAndPassword} = require('firebase/auth');
const {getFunctions, connectFunctionsEmulator, httpsCallable} = require('firebase/functions');
const {getFirestore, connectFirestoreEmulator, doc, collection, onSnapshot} = require('firebase/firestore');
const {getDatabase, connectDatabaseEmulator, ref, set, onDisconnect, onValue, goOffline} = require('firebase/database');
const functionsRequire = require('module').createRequire(require('path').join(__dirname, '../functions/package.json'));
const {initializeApp: initializeAdmin} = functionsRequire('firebase-admin/app');
const {getFirestore: getAdminFirestore, Timestamp} = functionsRequire('firebase-admin/firestore');

const projectId = process.env.GCLOUD_PROJECT || 'vybe-music-9c998';
const emulatorPort = (name, fallback) => Number(process.env[name] || fallback);

async function client(name) {
  const app = initializeApp({
    projectId, apiKey: 'fake-key',
    databaseURL: `https://${process.env.VYBE_DATABASE_INSTANCE || `${projectId}-default-rtdb`}.firebaseio.com`
  }, name);
  const auth = getAuth(app);
  connectAuthEmulator(auth, `http://127.0.0.1:${emulatorPort('VYBE_AUTH_EMULATOR_PORT', 9099)}`, {disableWarnings: true});
  const functions = getFunctions(app);
  connectFunctionsEmulator(functions, '127.0.0.1', emulatorPort('VYBE_FUNCTIONS_EMULATOR_PORT', 5001));
  const firestore = getFirestore(app);
  connectFirestoreEmulator(firestore, '127.0.0.1', emulatorPort('VYBE_FIRESTORE_EMULATOR_PORT', 8080));
  const database = getDatabase(app);
  connectDatabaseEmulator(database, '127.0.0.1', emulatorPort('VYBE_DATABASE_EMULATOR_PORT', 9000));
  const cred = await createUserWithEmailAndPassword(auth, `${name}-${Date.now()}@example.com`, 'password123');
  return {uid: cred.user.uid, functions, firestore, database};
}

function waitFor(label, register, predicate, timeoutMs = 15000) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      unsub();
      reject(new Error(`Timed out waiting for ${label}`));
    }, timeoutMs);
    const unsub = register(snap => {
      if (predicate(snap)) {
        clearTimeout(timer);
        setTimeout(() => unsub(), 0);
        resolve(snap);
      }
    }, err => { clearTimeout(timer); reject(err); });
  });
}

(async () => {
  const a = await client('alice');
  const b = await client('bob');
  assert.notStrictEqual(a.uid, b.uid, 'sessions must be distinct users');

  const {data: created} = await httpsCallable(a.functions, 'createRoom')({name: 'Test room'});
  assert.ok(created.roomId && created.code, 'room created with id and code');

  // A listens to the room and participants before B joins.
  const roomUpdate = waitFor('A to see B in room',
    (next, err) => onSnapshot(doc(a.firestore, 'rooms', created.roomId), next, err),
    s => s.exists() && s.data().participants.includes(b.uid));
  const participantsUpdate = waitFor('A to see 2 participants',
    (next, err) => onSnapshot(collection(a.firestore, 'rooms', created.roomId, 'participants'), next, err),
    s => s.size === 2);

  await httpsCallable(b.functions, 'joinRoom')({code: created.code});

  await Promise.all([roomUpdate, participantsUpdate]);

  // B can read the room and then observes real-time updates too.
  const bView = await waitFor('B to read room',
    (next, err) => onSnapshot(doc(b.firestore, 'rooms', created.roomId), next, err),
    s => s.exists());
  assert.deepStrictEqual([...bView.data().participants].sort(), [a.uid, b.uid].sort());
  // A backgrounded browser may stop heartbeats, but a live managed connection
  // must still occupy its seat and prevent a third listener from evicting it.
  const presence = ref(a.database, `presence/${created.roomId}/${a.uid}`);
  await onDisconnect(presence).remove();
  await set(presence, {roomId: created.roomId, connected: true,
    connectedAt: Date.now() - 60000, managed: true});
  const admin = initializeAdmin({projectId});
  await getAdminFirestore(admin).doc(`rooms/${created.roomId}/participants/${a.uid}`)
    .update({lastSeenAt: Timestamp.fromMillis(Date.now() - 60000)});
  const c = await client('charlie');
  await assert.rejects(httpsCallable(c.functions, 'joinRoom')({code: created.code}),
    error => error.code === 'functions/failed-precondition');
  const after = await waitFor('room retains both connected listeners',
    (next, err) => onSnapshot(doc(a.firestore, 'rooms', created.roomId), next, err),
    s => s.exists());
  assert.deepStrictEqual([...after.data().participants].sort(), [a.uid, b.uid].sort());
  const disconnected = waitFor('A presence to be removed after disconnect',
    (next, err) => onValue(ref(b.database, `presence/${created.roomId}/${a.uid}`), next, err),
    s => !s.exists());
  goOffline(a.database);
  await disconnected;
  await httpsCallable(c.functions, 'joinRoom')({code: created.code});
  const replacement = await waitFor('C to take the disconnected seat',
    (next, err) => onSnapshot(doc(b.firestore, 'rooms', created.roomId), next, err),
    s => s.exists() && s.data().participants.includes(c.uid));
  assert.deepStrictEqual([...replacement.data().participants].sort(), [b.uid, c.uid].sort());
  console.log('PASS: connected background listener retains their seat; disconnected seat is reclaimable');
  process.exit(0);
})().catch(e => { console.error('FAIL:', e); process.exit(1); });
