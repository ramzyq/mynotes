'use strict';

// Runs against the Firestore emulator:
//   firebase emulators:exec --only firestore "npm --prefix functions test"
const assert = require('assert');
const { initializeApp, deleteApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { cleanupDeletedNote } = require('../cleanup');

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  throw new Error('Run these tests with the Firestore emulator (firebase emulators:exec).');
}

let app;
let db;

before(() => {
  app = initializeApp({ projectId: 'mynotes-test' }, 'cleanup-test');
  db = getFirestore(app);
});

after(async () => {
  await deleteApp(app);
});

afterEach(async () => {
  await db.recursiveDelete(db.collection('users'));
  await db.recursiveDelete(db.collection('shareLinks'));
});

async function count(ref) {
  return (await ref.get()).size;
}

describe('cleanupDeletedNote', () => {
  it('removes versions, comments, and share links of the deleted note only', async () => {
    const notes = db.collection('users').doc('owner').collection('notes');
    const gone = notes.doc('gone');
    const kept = notes.doc('kept');

    await gone.collection('versions').doc('v1').set({ encryptedContent: 'x' });
    await gone.collection('versions').doc('v2').set({ encryptedContent: 'y' });
    await gone.collection('comments').doc('c1').set({ authorUid: 'collab' });
    await kept.set({ encryptedContent: 'z' });
    await kept.collection('versions').doc('v1').set({ encryptedContent: 'z' });

    await db.doc('shareLinks/t-gone').set({ ownerUid: 'owner', noteId: 'gone', mode: 'open' });
    await db.doc('shareLinks/t-gone/requests/r1').set({ ownerUid: 'owner', status: 'pending' });
    await db.doc('shareLinks/t-kept').set({ ownerUid: 'owner', noteId: 'kept', mode: 'open' });
    await db.doc('shareLinks/t-other').set({ ownerUid: 'someoneElse', noteId: 'gone', mode: 'open' });

    const result = await cleanupDeletedNote(db, 'owner', 'gone');

    assert.strictEqual(result.links, 1);
    assert.strictEqual(await count(gone.collection('versions')), 0);
    assert.strictEqual(await count(gone.collection('comments')), 0);
    assert.strictEqual((await db.doc('shareLinks/t-gone').get()).exists, false);
    assert.strictEqual(await count(db.collection('shareLinks/t-gone/requests')), 0);

    // Unrelated data is untouched.
    assert.strictEqual(await count(kept.collection('versions')), 1);
    assert.strictEqual((await db.doc('shareLinks/t-kept').get()).exists, true);
    assert.strictEqual((await db.doc('shareLinks/t-other').get()).exists, true);
  });

  it('is a no-op when there is nothing left to clean', async () => {
    const result = await cleanupDeletedNote(db, 'owner', 'missing');
    assert.strictEqual(result.links, 0);
  });
});
