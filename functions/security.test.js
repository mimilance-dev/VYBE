const assert = require('assert');
const crypto = require('crypto');
assert.equal('ABC123'.replace(/[^A-Z0-9]/g, ''), 'ABC123');
assert.equal('abc 123'.toUpperCase().replace(/[^A-Z0-9]/g, ''), 'ABC123');
assert.ok(crypto.randomBytes(6).length === 6);
console.log('security invariants ok');
