import { KeyManagementServiceClient } from '@google-cloud/kms';
import { Storage } from '@google-cloud/storage';
export function cloudProviders({kmsKey, bucketName}) {
  const kms = new KeyManagementServiceClient();
  const bucket = new Storage().bucket(bucketName);
  return {
    keys: {
      async wrap(key, account) {
        const [r] = await kms.encrypt({name: kmsKey, plaintext: key, additionalAuthenticatedData: Buffer.from(account)});
        return Buffer.from(r.ciphertext);
      },
      async unwrap(wrapped, account) {
        const [r] = await kms.decrypt({name: kmsKey, ciphertext: wrapped, additionalAuthenticatedData: Buffer.from(account)});
        return Buffer.from(r.plaintext);
      }
    },
    bodies: {
      async put(name, bytes) {
        await bucket.file(name).save(bytes, {resumable: false, contentType: 'application/octet-stream',
          preconditionOpts: {ifGenerationMatch: 0}, metadata: {cacheControl: 'no-store'}});
      },
      async get(name) { return (await bucket.file(name).download())[0]; },
      async remove(name) { await bucket.file(name).delete({ignoreNotFound: true}); }
    }
  };
}
