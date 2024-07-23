import { getRandomValues, createHash } from "crypto";

export const WORKER_SALT_LENGTH = 16;
export const HASH_ALGORITHM = "sha256";

export function generateRandomString(length: number) {
  let array = new Uint8Array(length);
  array = getRandomValues(array);
  return array.toString();
}

export function generateWorkerSalt(
  length: number = WORKER_SALT_LENGTH
): string {
  const input = generateRandomString(length);
  return createHash(HASH_ALGORITHM).update(input).digest("hex");
}

export function calculateWorkerID(key: string, salt: string) {
  const input = key + salt;
  return createHash(HASH_ALGORITHM).update(input).digest("hex");
}
