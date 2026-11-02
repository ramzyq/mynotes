#!/usr/bin/env node
'use strict';

/**
 * One-off admin maintenance for the migration in PR #34.
 *
 *   node functions/scripts/maintenance.js [--apply] [--project ramzyqnotes]
 *
 * Dry run by default: prints what it would change. Pass --apply to write.
 * Needs Admin SDK credentials, e.g. GOOGLE_APPLICATION_CREDENTIALS pointing
 * at a service-account key for the project.
 *
 * 1. Purge leaked plaintext. Older app versions wrote each encrypted note's
 *    plaintext `title` and `content` next to the ciphertext. Those two fields
 *    are deleted from every note with encryptionVersion >= 1. (Other v1
 *    plaintext metadata such as tags is left alone: v1 notes still read it,
 *    and the app moves it into the encrypted blob on next open.)
 * 2. Backfill emailIndex for every account with a verified email, so people
 *    who haven't opened the new app yet can still be found by "share by
 *    email". Existing entries are never overwritten.
 */

const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

const BATCH = 400;

/** @param {import('firebase-admin/firestore').Firestore} db */
async function purgePlaintext(db, { apply, log = console.log }) {
  let scanned = 0;
  let leaked = 0;
  let batch = db.batch();
  let pending = 0;

  // Unfiltered scan: a filtered collection-group query would need an extra
  // index. Only notes under users/{uid}/notes are considered.
  const snapshot = await db.collectionGroup('notes').get();
  for (const doc of snapshot.docs) {
    const data = doc.data();
    if (doc.ref.parent.parent?.parent.id !== 'users') continue;
    if (!(Number(data.encryptionVersion) >= 1)) continue;
    scanned++;
    const hasTitle = typeof data.title === 'string' && data.title.length > 0;
    const hasContent = typeof data.content === 'string' && data.content.length > 0;
    if (!hasTitle && !hasContent && !('title' in data) && !('content' in data)) continue;
    if (hasTitle || hasContent) leaked++;
    if (!apply) continue;
    batch.update(doc.ref, { title: FieldValue.delete(), content: FieldValue.delete() });
    if (++pending >= BATCH) {
      await batch.commit();
      batch = db.batch();
      pending = 0;
    }
  }
  if (apply && pending > 0) await batch.commit();
  log(`purge: scanned ${scanned} encrypted notes, ${leaked} had plaintext${apply ? ' (deleted)' : ' (dry run)'}`);
  return { scanned, leaked };
}

/**
 * @param {import('firebase-admin/auth').Auth} auth
 * @param {import('firebase-admin/firestore').Firestore} db
 */
async function backfillEmailIndex(auth, db, { apply, log = console.log }) {
  let created = 0;
  let skipped = 0;
  let pageToken;
  do {
    const page = await auth.listUsers(1000, pageToken);
    for (const user of page.users) {
      if (!user.email || !user.emailVerified) {
        skipped++;
        continue;
      }
      const ref = db.collection('emailIndex').doc(user.email.toLowerCase());
      const existing = await ref.get();
      if (existing.exists) {
        skipped++;
        continue;
      }
      created++;
      if (apply) await ref.create({ uid: user.uid });
    }
    pageToken = page.pageToken;
  } while (pageToken);
  log(`emailIndex: ${created} entries ${apply ? 'created' : 'to create (dry run)'}, ${skipped} skipped`);
  return { created, skipped };
}

async function main() {
  const args = process.argv.slice(2);
  const apply = args.includes('--apply');
  const projectIndex = args.indexOf('--project');
  const projectId = projectIndex >= 0 ? args[projectIndex + 1] : process.env.GCLOUD_PROJECT;
  if (!projectId) throw new Error('Pass --project <id>.');

  initializeApp({ projectId });
  const db = getFirestore();
  console.log(`${apply ? 'APPLYING' : 'DRY RUN'} on project ${projectId}`);
  await purgePlaintext(db, { apply });
  await backfillEmailIndex(getAuth(), db, { apply });
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error);
    process.exit(1);
  });
}

module.exports = { purgePlaintext, backfillEmailIndex };
