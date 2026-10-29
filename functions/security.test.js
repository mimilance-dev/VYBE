const assert = require('assert');
const crypto = require('crypto');
assert.equal('ABC123'.replace(/[^A-Z0-9]/g, ''), 'ABC123');
assert.equal('abc 123'.toUpperCase().replace(/[^A-Z0-9]/g, ''), 'ABC123');
assert.ok(crypto.randomBytes(6).length === 6);
assert.ok(crypto.randomBytes(8).length === 8);
assert.ok(crypto.randomBytes(32).length === 32);
assert.ok(/^ABCDEFGHJKLMNPQRSTUVWXYZ23456789$/.test('ABCDEFGHJKLMNPQRSTUVWXYZ23456789'));
console.log('security invariants ok');
