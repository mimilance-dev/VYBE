const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const rules = fs.readFileSync(
  path.join(__dirname, '..', 'firestore.rules'),
  'utf8',
);
assert.ok(!/allow\s+(read|write|create|update|delete)[^:]*:\s*if\s+true/.test(rules));
assert.ok(rules.includes("match /users/{userId}"));
assert.ok(rules.includes('request.auth.uid == userId'));
assert.ok(rules.includes('match /rooms/{roomId}'));
assert.ok(rules.includes('allow list: if false'));
assert.ok(rules.includes('match /participants/{participantId}'));
assert.ok(rules.includes('allow create, update, delete: if false'));
assert.ok(rules.includes('match /playbackCommands/{commandId}'));
console.log('Firestore rules invariants ok');
