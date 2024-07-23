// https://hexdocs.pm/phoenix/js/#socket

export default class InMemoryStorage {
  constructor() {
    this.storage = {};
  }
  getItem(keyName) {
    return this.storage[keyName] || null;
  }
  removeItem(keyName) {
    delete this.storage[keyName];
  }
  setItem(keyName, keyValue) {
    this.storage[keyName] = keyValue;
  }
}
