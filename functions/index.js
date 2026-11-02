'use strict';

const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { onDocumentDeleted } = require('firebase-functions/v2/firestore');
const logger = require('firebase-functions/logger');
const { cleanupDeletedNote } = require('./cleanup');

initializeApp();

/**
 * Runs for every note deletion, whether it came from the app, from the
 * `selfDestructAt` TTL policy (see firestore.indexes.json), or from the
 * console, and removes the note's versions, comments, and share links.
 *
 * The function only ever sees ciphertext and document ids; it never needs,
 * and never has, access to note contents.
 */
exports.cleanupDeletedNote = onDocumentDeleted(
  { document: 'users/{ownerUid}/notes/{noteId}', retry: true },
  async (event) => {
    const { ownerUid, noteId } = event.params;
    const result = await cleanupDeletedNote(getFirestore(), ownerUid, noteId);
    logger.info('Cleaned up deleted note', { ownerUid, noteId, links: result.links });
  },
);
