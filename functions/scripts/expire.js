#!/usr/bin/env node
'use strict';

/**
 * Delete self-destructed notes on the free (Spark) plan, where neither TTL
 * policies nor Cloud Functions are available. Run on a schedule by
 * .github/workflows/expire-notes.yml.
 *
 *   node functions/scripts/expire.js [--dry-run] [--project ramzyqnotes]
 *
 * For every note whose `selfDestructAt` has passed, and every note that has
 * been in the trash (`deletedAt`) longer than TRASH_RETENTION_DAYS, removes
 * its versions, comments and share links (via cleanupDeletedNote), then the
 * note itself. The app purges the trash too, but only while it is open, so
 * without this a user who stops opening the app keeps trashed notes forever.
 * Needs Admin SDK credentials (GOOGLE_APPLICATION_CREDENTIALS).
 *
 * Queries each user's notes collection separately: those range filters are
 * served by automatic collection-scope indexes, whereas collection-group
 * queries would need extra indexes. Switch to collection-group queries (and
 * add COLLECTION_GROUP field overrides for both fields) once the user count
 * makes one query per user per run too slow.
 */

const { initializeApp } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const { cleanupDeletedNote } = require('../cleanup');

/** Must match Note.trashRetention in the app. */
const TRASH_RETENTION_DAYS = 30;
const DAY_MS = 24 * 60 * 60 * 1000;

/** @param {import('firebase-admin/firestore').Firestore} db */
async function deleteExpiredNotes(db, { apply = true, now = new Date(), log = console.log } = {}) {
  let deleted = 0;
  let purged = 0;
  let failed = 0;
  const cutoff = Timestamp.fromDate(now);
  const trashCutoff = Timestamp.fromDate(new Date(now.getTime() - TRASH_RETENTION_DAYS * DAY_MS));
  // listDocuments also returns user ids that have notes but no profile doc.
  const users = await db.collection('users').listDocuments();
  for (const user of users) {
    const notes = user.collection('notes');
    const [expired, trashed] = await Promise.all([
      notes.where('selfDestructAt', '<=', cutoff).get(),
      notes.where('deletedAt', '<=', trashCutoff).get(),
    ]);
    // A trashed note can also be expired; delete it once, as expired.
    const expiredIds = new Set(expired.docs.map((doc) => doc.id));
    const targets = [
      ...expired.docs.map((doc) => ({ doc, kind: 'expired' })),
      ...trashed.docs.filter((doc) => !expiredIds.has(doc.id)).map((doc) => ({ doc, kind: 'trash' })),
    ];
    for (const { doc, kind } of targets) {
      const count = () => (kind === 'expired' ? deleted++ : purged++);
      if (!apply) {
        count();
        continue;
      }
      try {
        await cleanupDeletedNote(db, user.id, doc.id);
        await doc.ref.delete();
        count();
      } catch (error) {
        // Keep going; the next scheduled run retries this note. Log no ids or
        // messages: the workflow logs of a public repo are public.
        failed++;
        log(`failed to delete an expired note (${error.code ?? 'unknown error'})`);
      }
    }
  }
  log(`expire: ${deleted} expired and ${purged} old trashed notes ${apply ? 'deleted' : 'found (dry run)'} across ${users.length} users${failed ? `, ${failed} failed` : ''}`);
  return { deleted, purged, failed };
}

async function main() {
  const args = process.argv.slice(2);
  const apply = !args.includes('--dry-run');
  const projectIndex = args.indexOf('--project');
  const projectId = projectIndex >= 0 ? args[projectIndex + 1] : process.env.GCLOUD_PROJECT;
  if (!projectId) throw new Error('Pass --project <id>.');

  initializeApp({ projectId });
  const { failed } = await deleteExpiredNotes(getFirestore(), { apply });
  if (failed) process.exit(1);
}

if (require.main === module) {
  main().catch((error) => {
    console.error(`expire failed: ${error.code ?? error.name}`);
    process.exit(1);
  });
}

module.exports = { deleteExpiredNotes, TRASH_RETENTION_DAYS };
