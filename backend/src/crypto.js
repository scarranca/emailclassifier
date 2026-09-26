import { randomBytes, createCipheriv, createDecipheriv, createHmac } from 'node:crypto';
export const context = (account, id, kind) => JSON.stringify(['cove-cloud-v1', account, id, kind]);
export function seal(key, value, aad) {
  const nonce = randomBytes(12);
  const cipher = createCipheriv('aes-256-gcm', key, nonce);
  cipher.setAAD(Buffer.from(aad));
  const data = Buffer.from(JSON.stringify(value));
  return Buffer.concat([Buffer.from([1]), nonce, cipher.update(data), cipher.final(), cipher.getAuthTag()]);
}
export function open(key, value, aad) {
  const data = Buffer.from(value);
  if (data.length < 30 || data[0] !== 1) throw new Error('Invalid encrypted record');
  const cipher = createDecipheriv('aes-256-gcm', key, data.subarray(1, 13));
  cipher.setAAD(Buffer.from(aad));
  cipher.setAuthTag(data.subarray(-16));
  return JSON.parse(Buffer.concat([cipher.update(data.subarray(13, -16)), cipher.final()]).toString());
}
export function digest(key, value) {
  return createHmac('sha256', key).update(JSON.stringify(value)).digest('hex');
}
export function newKey() { return randomBytes(32); }
