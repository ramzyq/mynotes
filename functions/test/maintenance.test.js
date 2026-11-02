'use strict';

// Runs against the Firestore and Auth emulators:
//   firebase emulators:exec --only firestore,auth "npm --prefix functions test"
const assert = require('assert');
const { initializeApp, deleteApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore } = require('firebase-admin/firestore');
const { purgePlaintext, backfillEmailIndex } = require('../scripts/maintenance');

const quiet = () => {};
let app;
let db;
let auth;

describe('maintenance', function () {
  before(function () {
    if (!process.env.FIREBASE_AUTH_EMULATOR_HOST) this.skip();
    app = initializeApp({ projectId: 'mynotes-test' }, 'maintenance-test');
    db = getFirestore(app);
    auth = getAuth(app);
  });

  after(async () => {
    if (app) await deleteApp(app);
  });

  afterEach(async () => {
    if (!db) return;
    await db.recursiveDelete(db.collection('users'));
    await db.recursiveDelete(db.collection('emailIndex'));
    const { users } = await auth.listUsers();
    await auth.deleteUsers(users.map((u) => u.uid));
  });

  it('purges plaintext only from encrypted notes, and only with --apply', async () => {
    const notes = db.collection('users').doc('u1').collection('notes');
    await notes.doc('leaky').set({ encryptionVersion: 1, title: 'Secret', content: 'Body', encryptedTitle: 'x', tags: ['t'] });
    await notes.doc('v2').set({ encryptionVersion: 2, title: '', encryptedTitle: 'y' });
    await notes.doc('plain').set({ encryptionVersion: 0, title: 'Not encrypted' });

    const dry = await purgePlaintext(db, { apply: false, log: quiet });
    assert.deepStrictEqual(dry, { scanned: 2, leaked: 1 });
    assert.strictEqual((await notes.doc('leaky').get()).data().title, 'Secret');

    await purgePlaintext(db, { apply: true, log: quiet });
    const leaky = (await notes.doc('leaky').get()).data();
    assert.strictEqual('title' in leaky, false);
    assert.strictEqual('content' in leaky, false);
    assert.strictEqual(leaky.encryptedTitle, 'x');
    assert.deepStrictEqual(leaky.tags, ['t'], 'v1 metadata is kept for the app to migrate');
    assert.strictEqual('title' in (await notes.doc('v2').get()).data(), false);
    assert.strictEqual((await notes.doc('plain').get()).data().title, 'Not encrypted');
  });

  it('backfills emailIndex for verified emails without overwriting', async () => {
    await auth.createUser({ uid: 'a', email: 'Alice@Example.com', emailVerified: true });
    await auth.createUser({ uid: 'b', email: 'bob@example.com', emailVerified: false });
    await auth.createUser({ uid: 'c', email: 'carol@example.com', emailVerified: true });
    await db.doc('emailIndex/carol@example.com').set({ uid: 'someone-else' });

    const dry = await backfillEmailIndex(auth, db, { apply: false, log: quiet });
    assert.deepStrictEqual(dry, { created: 1, skipped: 2 });
    assert.strictEqual((await db.doc('emailIndex/alice@example.com').get()).exists, false);

    await backfillEmailIndex(auth, db, { apply: true, log: quiet });
    assert.deepStrictEqual((await db.doc('emailIndex/alice@example.com').get()).data(), { uid: 'a' });
    assert.strictEqual((await db.doc('emailIndex/bob@example.com').get()).exists, false);
    assert.deepStrictEqual((await db.doc('emailIndex/carol@example.com').get()).data(), { uid: 'someone-else' });
  });
});
