'use strict';

/**
 * Delete everything that hangs off a note once the note document is gone:
 * its version history, its comments, and any share links (with their join
 * requests) that point at it.
 *
 * Firestore never deletes subcollections when a parent document is deleted,
 * and TTL deletion removes only the expired document itself, so without this
 * the encrypted history and comments of a "self-destructed" note would stay
 * in the database indefinitely.
 *
 * Safe to run more than once: deleting what is already gone is a no-op. The
 * app also deletes these itself, so this is usually a no-op for app deletes
 * and does the real work for TTL deletes and interrupted client deletes.
 *
 * @param {import('firebase-admin/firestore').Firestore} db
 * @param {string} ownerUid
 * @param {string} noteId
 * @returns {Promise<{links: number}>}
 */
async function cleanupDeletedNote(db, ownerUid, noteId) {
  const noteRef = db.collection('users').doc(ownerUid).collection('notes').doc(noteId);

  await Promise.all([
    db.recursiveDelete(noteRef.collection('versions')),
    db.recursiveDelete(noteRef.collection('comments')),
  ]);

  const links = await db
    .collection('shareLinks')
    .where('ownerUid', '==', ownerUid)
    .where('noteId', '==', noteId)
    .get();
  // recursiveDelete on a document also removes its `requests` subcollection.
  await Promise.all(links.docs.map((doc) => db.recursiveDelete(doc.ref)));

  return { links: links.size };
}

module.exports = { cleanupDeletedNote };
