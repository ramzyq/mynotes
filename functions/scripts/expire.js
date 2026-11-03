#!/usr/bin/env node
'use strict';

/**
 * Delete self-destructed notes on the free (Spark) plan, where neither TTL
 * policies nor Cloud Functions are available. Run on a schedule by
 * .github/workflows/expire-notes.yml.
 *
 *   node functions/scripts/expire.js [--dry-run] [--project ramzyqnotes]
 *
 * For every note whose `selfDestructAt` has passed, removes its versions,
 * comments and share links (via cleanupDeletedNote), then the note itself.
 * Needs Admin SDK credentials (GOOGLE_APPLICATION_CREDENTIALS).
 *
 * Queries each user's notes collection separately: that range filter is
 * served by the existing collection-scope selfDestructAt index, whereas a
 * collection-group query would need an extra index.
 */

const { initializeApp } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const { cleanupDeletedNote } = require('../cleanup');

/** @param {import('firebase-admin/firestore').Firestore} db */
async function deleteExpiredNotes(db, { apply = true, now = new Date(), log = console.log } = {}) {
  let deleted = 0;
  let failed = 0;
  const cutoff = Timestamp.fromDate(now);
  // listDocuments also returns user ids that have notes but no profile doc.
  const users = await db.collection('users').listDocuments();
  for (const user of users) {
    const expired = await user.collection('notes').where('selfDestructAt', '<=', cutoff).get();
    for (const doc of expired.docs) {
      if (!apply) {
        deleted++;
        continue;
      }
      try {
        await cleanupDeletedNote(db, user.id, doc.id);
        await doc.ref.delete();
        deleted++;
      } catch (error) {
        // Keep going; the next scheduled run retries this note. Log no ids or
        // messages: the workflow logs of a public repo are public.
        failed++;
        log(`failed to delete an expired note (${error.code ?? 'unknown error'})`);
      }
    }
  }
  log(`expire: ${deleted} expired notes ${apply ? 'deleted' : 'found (dry run)'} across ${users.length} users${failed ? `, ${failed} failed` : ''}`);
  return { deleted, failed };
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

module.exports = { deleteExpiredNotes };
