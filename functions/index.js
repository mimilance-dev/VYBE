const {onCall, HttpsError} = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
admin.initializeApp();
const db = admin.firestore();

function uid(request) {
  if (!request.auth?.uid) throw new HttpsError('unauthenticated', 'Sign in first.');
  return request.auth.uid;
}
function text(value, max = 100) {
  return typeof value === 'string' ? value.trim().slice(0, max) : undefined;
}
function normalizeCode(value) {
  return String(value || '').toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 12);
}
function roomCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const bytes = require('crypto').randomBytes(6);
  return Array.from(bytes, byte => chars[byte % chars.length]).join('').slice(0, 6);
}
async function rateLimit(uidValue, action, max = 30, windowMs = 60000) {
  const ref = db.collection('rateLimits').doc(`${uidValue}_${action}`);
  await db.runTransaction(async tx => {
    const snap = await tx.get(ref);
    const now = Date.now();
    const data = snap.exists ? snap.data() : {};
    const reset = typeof data.reset === 'number' ? data.reset : now + windowMs;
    let count = now < reset ? (data.count || 0) : 0;
    if (count >= max) throw new HttpsError('resource-exhausted', 'Please slow down and try again shortly.');
    tx.set(ref, {count: count + 1, reset: now < reset ? reset : now + windowMs, updatedAt: admin.firestore.FieldValue.serverTimestamp()});
  });
}
async function activeParticipantIds(roomRef, room) {
  const ids = new Set((room.participants || []).slice(0, 2));
  const participantReads = await Promise.all([...ids].map(id => roomRef.collection('participants').doc(id).get()));
  const cutoff = admin.firestore.Timestamp.fromMillis(Date.now() - 45000);
  const active = new Set();
  participantReads.forEach(snap => {
    const p = snap.data();
    if (snap.exists && p.isOnline && p.lastSeenAt?.toMillis >= cutoff.toMillis()) active.add(snap.id);
  });
  return active;
}

exports.createRoom = onCall(async request => {
  const userId = uid(request);
  await rateLimit(userId, 'createRoom', 8);
  const name = text(request.data?.name, 80) || 'Listening room';
  const displayName = text(request.data?.displayName, 100) || 'Listener';
  const avatarUrl = text(request.data?.avatarUrl, 2048);
  let roomRef;
  for (let attempt = 0; attempt < 8; attempt++) {
    const code = roomCode();
    const codeRef = db.collection('roomInvites').doc(code);
    roomRef = db.collection('rooms').doc();
    const created = await db.runTransaction(async tx => {
      const collision = await tx.get(codeRef);
      if (collision.exists) return false;
      const now = admin.firestore.FieldValue.serverTimestamp();
      tx.set(codeRef, {roomId: roomRef.id, createdAt: now});
      tx.set(roomRef, {
        id: roomRef.id, code, hostId: userId, participants: [userId], createdAt: now, updatedAt: now,
        currentTrack: null, playbackState: {provider: null, trackId: null, isPlaying: false, positionMs: 0,
          serverTimestamp: now, revision: 0}, queue: [],
        settings: {visibility: 'invite', maxParticipants: 2, name}
      });
      tx.set(roomRef.collection('participants').doc(userId), {
        userId, displayName, avatarUrl: avatarUrl || null,
        joinedAt: now, lastSeenAt: now, isOnline: true
      });
      return true;
    });
    if (created) return {roomId: roomRef.id, code};
  }
  throw new HttpsError('resource-exhausted', 'A room could not be created. Try again.');
});

exports.resolveRoomInvite = onCall(async request => {
  const userId = uid(request);
  await rateLimit(userId, 'resolveInvite', 60);
  const code = normalizeCode(request.data?.code);
  if (code.length < 4) throw new HttpsError('invalid-argument', 'Enter a valid room code.');
  const invite = await db.collection('roomInvites').doc(code).get();
  return {exists: invite.exists};
});

exports.joinRoom = onCall(async request => {
  const userId = uid(request);
  await rateLimit(userId, 'joinRoom', 20);
  const displayName = text(request.data?.displayName, 100) || 'Listener';
  const avatarUrl = text(request.data?.avatarUrl, 2048);
  let roomId = text(request.data?.roomId, 128);
  if (!roomId) {
    const code = normalizeCode(request.data?.code);
    const invite = await db.collection('roomInvites').doc(code).get();
    if (!invite.exists) throw new HttpsError('not-found', 'That room could not be found.');
    roomId = invite.data().roomId;
  }
  const roomRef = db.collection('rooms').doc(roomId);
  await db.runTransaction(async tx => {
    const snap = await tx.get(roomRef);
    if (!snap.exists) throw new HttpsError('not-found', 'That room could not be found.');
    const room = snap.data();
    const participantSnaps = await Promise.all((room.participants || []).map(id => tx.get(roomRef.collection('participants').doc(id))));
    const cutoff = admin.firestore.Timestamp.fromMillis(Date.now() - 45000);
    const active = new Set();
    participantSnaps.forEach(p => { const d=p.data(); if(p.exists && d.isOnline && d.lastSeenAt?.toMillis() >= cutoff.toMillis()) active.add(p.id); });
    if (!active.has(userId) && active.size >= 2) throw new HttpsError('failed-precondition', 'This room is already vibing with two people.');
    if (!active.has(userId)) active.add(userId);
    const participantRef = roomRef.collection('participants').doc(userId);
    const previous = await tx.get(participantRef);
    const joinedAt = previous.exists ? previous.data().joinedAt : admin.firestore.FieldValue.serverTimestamp();
    tx.set(participantRef, {userId, displayName, avatarUrl: avatarUrl || null, joinedAt, lastSeenAt: admin.firestore.FieldValue.serverTimestamp(), isOnline: true});
    tx.update(roomRef, {participants: [...active].slice(0, 2), updatedAt: admin.firestore.FieldValue.serverTimestamp()});
  });
  return {roomId};
});

async function requireParticipant(roomId, userId) {
  const roomRef = db.collection('rooms').doc(roomId);
  const snap = await roomRef.get();
  if (!snap.exists || !(snap.data().participants || []).includes(userId)) throw new HttpsError('permission-denied', 'You are not in this room.');
  return roomRef;
}

exports.heartbeatRoom = onCall(async request => {
  const userId = uid(request);
  await rateLimit(userId, 'heartbeat', 120);
  const roomRef = await requireParticipant(request.data?.roomId, userId);
  await roomRef.collection('participants').doc(userId).update({isOnline: true, lastSeenAt: admin.firestore.FieldValue.serverTimestamp()});
});

exports.leaveRoom = onCall(async request => {
  const userId = uid(request);
  await rateLimit(userId, 'leave', 60);
  const roomRef = await requireParticipant(request.data?.roomId, userId);
  await db.runTransaction(async tx => {
    const snap = await tx.get(roomRef);
    const room = snap.data();
    tx.update(roomRef, {participants: (room.participants || []).filter(id => id !== userId), updatedAt: admin.firestore.FieldValue.serverTimestamp()});
    tx.update(roomRef.collection('participants').doc(userId), {isOnline: request.data?.offline === true, lastSeenAt: admin.firestore.FieldValue.serverTimestamp()});
  });
});

const commandTypes = new Set(['play','pause','seek','next','previous','addToQueue','removeFromQueue','clearQueue','setTrack','setShuffle','setRepeat','checkpoint']);
function validQueueItem(item) {
  if (!item || typeof item !== 'object') return false;
  return typeof item.id === 'string' && item.id.length <= 200 && ['spotify','youtube'].includes(item.provider) &&
    typeof item.title === 'string' && item.title.length <= 300 && typeof item.artist === 'string' && item.artist.length <= 300;
}

exports.submitPlaybackCommand = onCall(async request => {
  const userId = uid(request);
  await rateLimit(userId, 'commands', 120);
  const roomId = text(request.data?.roomId, 128);
  const roomRef = await requireParticipant(roomId, userId);
  const command = request.data?.command || {};
  const commandId = text(command.commandId, 160);
  const type = command.type;
  if (!commandId || !commandTypes.has(type)) throw new HttpsError('invalid-argument', 'Invalid playback command.');
  if (!Number.isInteger(command.revision) || command.revision < 0) throw new HttpsError('invalid-argument', 'Invalid playback revision.');
  if (command.queueItem != null && !validQueueItem(command.queueItem)) throw new HttpsError('invalid-argument', 'Invalid queue item.');
  if (command.positionMs != null && (!Number.isInteger(command.positionMs) || command.positionMs < 0 || command.positionMs > 864000000)) throw new HttpsError('invalid-argument', 'Invalid position.');
  if (command.queueIndex != null && (!Number.isInteger(command.queueIndex) || command.queueIndex < 0)) throw new HttpsError('invalid-argument', 'Invalid queue position.');
  const commandRef = roomRef.collection('playbackCommands').doc(commandId);
  await db.runTransaction(async tx => {
    const existing = await tx.get(commandRef);
    if (existing.exists) return;
    const roomSnap = await tx.get(roomRef);
    const room = roomSnap.data();
    const state = room.playbackState || {};
    if (command.revision !== state.revision) return;
    const queue = [...(room.queue || [])];
    let currentTrack = room.currentTrack || null;
    let nextState = {...state};
    const serverNow = admin.firestore.Timestamp.now();
    const projected = state.isPlaying && state.serverTimestamp?.toMillis ? state.positionMs + Math.max(0, serverNow.toMillis() - state.serverTimestamp.toMillis()) : state.positionMs;
    const revision = state.revision + 1;
    if (type === 'play') { nextState = {...state, isPlaying:true, positionMs:state.positionMs || 0, serverTimestamp:serverNow, revision}; }
    if (type === 'pause') { nextState = {...state, isPlaying:false, positionMs:projected, serverTimestamp:serverNow, revision}; }
    if (type === 'seek') { nextState = {...state, positionMs:command.positionMs || 0, serverTimestamp:serverNow, revision}; }
    if (type === 'setTrack') { currentTrack = command.queueItem || {id:command.trackId, provider:command.provider}; nextState={...state,trackId:command.trackId||null,provider:command.provider||null,isPlaying:false,positionMs:0,serverTimestamp:serverNow,revision}; }
    if (type === 'addToQueue' && command.queueItem && queue.length < 200) queue.push(command.queueItem);
    if (type === 'removeFromQueue' && command.queueIndex < queue.length) queue.splice(command.queueIndex, 1);
    if (type === 'clearQueue') queue.length = 0;
    if (type === 'setShuffle' || type === 'setRepeat') room.settings[type === 'setShuffle' ? 'shuffle' : 'repeat'] = command.enabled === true;
    tx.set(commandRef, {commandId, senderId:userId, timestamp:admin.firestore.FieldValue.serverTimestamp(), revision:command.revision, type, accepted:true});
    tx.update(roomRef, {playbackState:nextState, queue, currentTrack, settings:room.settings, updatedAt:admin.firestore.FieldValue.serverTimestamp()});
  });
});

exports.submitPlaybackCheckpoint = onCall(async request => {
  const userId = uid(request);
  await rateLimit(userId, 'checkpoints', 120);
  const roomRef = await requireParticipant(request.data?.roomId, userId);
  const positionMs = request.data?.positionMs;
  if (!Number.isInteger(positionMs) || positionMs < 0 || positionMs > 864000000) throw new HttpsError('invalid-argument', 'Invalid position.');
  await db.runTransaction(async tx => {
    const snap = await tx.get(roomRef); const state = snap.data().playbackState || {}; 
    tx.update(roomRef, {'playbackState.positionMs': positionMs, 'playbackState.serverTimestamp': admin.firestore.FieldValue.serverTimestamp(), 'playbackState.revision': state.revision, updatedAt: admin.firestore.FieldValue.serverTimestamp()});
  });
});
