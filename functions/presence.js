const PENDING_PRESENCE_TIMEOUT_MS = 45000;

function isActivePresence(value, now = Date.now()) {
  return value?.connected === true && (value.managed === true ||
    (typeof value.connectedAt === 'number' &&
      value.connectedAt >= now - PENDING_PRESENCE_TIMEOUT_MS));
}

module.exports = {isActivePresence};
