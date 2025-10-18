const CryptoJS = require('crypto-js');

/**
 * Encrypts data using AES encryption
 * @param {string} data - The data to encrypt
 * @param {string} key - The encryption key
 * @returns {string} - The encrypted data
 */
function encrypt(data, key) {
  return CryptoJS.AES.encrypt(data, key).toString();
}

/**
 * Decrypts data using AES encryption
 * @param {string} encryptedData - The encrypted data
 * @param {string} key - The encryption key
 * @returns {string} - The decrypted data
 */
function decrypt(encryptedData, key) {
  const bytes = CryptoJS.AES.decrypt(encryptedData, key);
  return bytes.toString(CryptoJS.enc.Utf8);
}

/**
 * Generates a unique device key based on device identifiers
 * @param {string} deviceId - The device identifier
 * @param {string} salt - A salt value
 * @returns {string} - The generated key
 */
function generateDeviceKey(deviceId, salt) {
  return CryptoJS.SHA256(deviceId + salt).toString();
}

module.exports = {
  encrypt,
  decrypt,
  generateDeviceKey
};
