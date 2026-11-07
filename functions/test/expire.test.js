'use strict';

// Runs against the Firestore emulator:
//   firebase emulators:exec --only firestore "npm --prefix functions test"
const assert = require('assert');
const { initializeApp, deleteApp } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const { deleteExpiredNotes, TRASH_RETENTION_DAYS } = require('../scripts/expire');

const quiet = () => {};
let app;
let db;

describe('deleteExpiredNotes', function () {
  before(function () {
    if (!process.env.FIRESTORE_EMULATOR_HOST) this.skip();
    app = initializeApp({ projectId: 'mynotes-test' }, 'expire-test');
    db = getFirestore(app);
  });

  after(async () => {
    if (app) await deleteApp(app);
  });

  afterEach(async () => {
    if (!db) return;
    await db.recursiveDelete(db.collection('users'));
    await db.recursiveDelete(db.collection('shareLinks'));
  });

  const now = new Date('2026-11-03T12:00:00Z');
  const at = (offsetMs) => Timestamp.fromDate(new Date(now.getTime() + offsetMs));

  it('deletes only expired notes, with their subcollections and share links', async () => {
    // No profile doc for u1: its notes must still be found.
    const notes = db.collection('users').doc('u1').collection('notes');
    await notes.doc('expired').set({ selfDestructAt: at(-1000) });
    await notes.doc('expired').collection('versions').doc('v').set({ x: 1 });
    await notes.doc('expired').collection('comments').doc('c').set({ x: 1 });
    await db.doc('shareLinks/tok').set({ ownerUid: 'u1', noteId: 'expired', mode: 'open' });
    await db.doc('shareLinks/tok/requests/r').set({ status: 'pending' });
    await notes.doc('future').set({ selfDestructAt: at(60_000) });
    await notes.doc('never').set({ selfDestructAt: null });
    await notes.doc('legacy').set({ title: '' });
    await db.doc('users/u2').set({ displayName: 'B' });
    await db.doc('users/u2/notes/gone').set({ selfDestructAt: at(-5) });

    const dry = await deleteExpiredNotes(db, { apply: false, now, log: quiet });
    assert.deepStrictEqual(dry, { deleted: 2, purged: 0, failed: 0 });
    assert.ok((await notes.doc('expired').get()).exists, 'dry run deletes nothing');

    const result = await deleteExpiredNotes(db, { now, log: quiet });
    assert.deepStrictEqual(result, { deleted: 2, purged: 0, failed: 0 });
    assert.strictEqual((await notes.doc('expired').get()).exists, false);
    assert.strictEqual((await notes.doc('expired').collection('versions').get()).size, 0);
    assert.strictEqual((await notes.doc('expired').collection('comments').get()).size, 0);
    assert.strictEqual((await db.doc('shareLinks/tok').get()).exists, false);
    assert.strictEqual((await db.collection('shareLinks/tok/requests').get()).size, 0);
    assert.strictEqual((await db.doc('users/u2/notes/gone').get()).exists, false);
    for (const id of ['future', 'never', 'legacy']) {
      assert.ok((await notes.doc(id).get()).exists, `${id} is kept`);
    }
  });

  it('purges notes trashed longer than the retention period', async () => {
    const day = 24 * 60 * 60 * 1000;
    const notes = db.collection('users').doc('u1').collection('notes');
    await notes.doc('old').set({ deletedAt: at(-(TRASH_RETENTION_DAYS + 1) * day) });
    await notes.doc('old').collection('versions').doc('v').set({ x: 1 });
    await notes.doc('recent').set({ deletedAt: at(-1 * day) });
    await notes.doc('live').set({ deletedAt: null });
    // Both expired and long trashed: deleted once, counted as expired.
    await notes.doc('both').set({ deletedAt: at(-40 * day), selfDestructAt: at(-1000) });

    const dry = await deleteExpiredNotes(db, { apply: false, now, log: quiet });
    assert.deepStrictEqual(dry, { deleted: 1, purged: 1, failed: 0 });

    const result = await deleteExpiredNotes(db, { now, log: quiet });
    assert.deepStrictEqual(result, { deleted: 1, purged: 1, failed: 0 });
    for (const id of ['old', 'both']) {
      assert.strictEqual((await notes.doc(id).get()).exists, false, `${id} is deleted`);
    }
    assert.strictEqual((await notes.doc('old').collection('versions').get()).size, 0);
    for (const id of ['recent', 'live']) {
      assert.ok((await notes.doc(id).get()).exists, `${id} is kept`);
    }
  });
});
