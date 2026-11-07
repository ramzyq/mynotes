const { assertFails, assertSucceeds, initializeTestEnvironment } = require('@firebase/rules-unit-testing');
const path = require('path');

const rulesPath = path.resolve(__dirname, '..', 'firestore.rules');
let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'mynotes-test',
    firestore: { rules: require('fs').readFileSync(rulesPath, 'utf8') },
  });
});

async function seed(path, data) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(path).set(data);
  });
}

const as = (uid, verified = true) => testEnv.authenticatedContext(uid, { email: `${uid}@example.com`, email_verified: verified }).firestore();

/** A note shared with `reporter`, with a comment by `author`, to report. */
async function seedReportable() {
  await seed('users/owner/notes/note1', { collaborators: ['reporter', 'author'] });
  await seed('users/owner/notes/note1/comments/comment1', { authorUid: 'author', encryptedContent: 'ct' });
}

afterEach(async () => {
  await testEnv.clearFirestore();
});

after(async () => {
  await testEnv.cleanup();
});

describe('Firestore rules', () => {
  it('denies unauthenticated read', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(db.collection('users/user1/notes').get());
  });

  it('allows authenticated user to read own note', async () => {
    const db = testEnv.authenticatedContext('user1').firestore();
    await db.collection('users/user1/notes').doc('note1').set({ encryptedTitle: 'x', encryptionVersion: 2 });
    await assertSucceeds(db.collection('users/user1/notes').doc('note1').get());
  });

  it('denies user A reading user B note', async () => {
    const dbA = testEnv.authenticatedContext('userA').firestore();
    const dbB = testEnv.authenticatedContext('userB').firestore();
    await dbB.collection('users/userB/notes').doc('secret').set({ encryptedTitle: 'x', encryptionVersion: 2 });
    await assertFails(dbA.collection('users/userB/notes').doc('secret').get());
  });

  it('allows collaborator to read shared note', async () => {
    const dbOwner = testEnv.authenticatedContext('owner').firestore();
    const dbCollab = testEnv.authenticatedContext('collab').firestore();
    await dbOwner.collection('users/owner/notes').doc('shared').set({
      encryptedTitle: 'x',
      collaborators: ['collab'],
    });
    await assertSucceeds(dbCollab.collection('users/owner/notes').doc('shared').get());
  });

  // ---------- note validation ----------

  const validNote = () => ({
    colorIndex: 0, isPinned: false, isArchived: false, isStudyMaterial: false,
    selfDestructAt: null, selfDestructOnRead: false,
    createdAt: new Date(), updatedAt: new Date(),
    encryptedTitle: 'ct', encryptedContent: 'ct', encryptedMeta: 'ct', encryptionVersion: 2,
    wrappedKey: 'wk', keyGen: 1, versionCounter: 0,
  });

  it('accepts the note shape the app writes', async () => {
    await assertSucceeds(as('owner').doc('users/owner/notes/n1').set(validNote()));
    await assertSucceeds(as('owner').doc('users/owner/notes/n1').update({
      isPinned: true, collaborators: ['c1'], 'encryptedKeys.c1': 'wk2', sharedBy: 'owner', sharedAt: new Date(),
    }));
  });

  it('lets the owner move a note to the trash and back', async () => {
    const db = as('owner');
    await assertSucceeds(db.doc('users/owner/notes/t1').set(validNote()));
    await assertSucceeds(db.doc('users/owner/notes/t1').update({ deletedAt: new Date() }));
    await assertSucceeds(db.doc('users/owner/notes/t1').update({ deletedAt: null }));
    await assertFails(db.doc('users/owner/notes/t1').update({ deletedAt: 'yesterday' }));
    await assertFails(as('collab').doc('users/owner/notes/t1').update({ deletedAt: new Date() }));
  });

  it('refuses plaintext, unknown fields and wrong types on notes', async () => {
    const db = as('owner');
    await assertFails(db.doc('users/owner/notes/a').set({ ...validNote(), title: 'Plaintext!' }));
    await assertFails(db.doc('users/owner/notes/b').set({ ...validNote(), content: 'Plaintext!' }));
    await assertFails(db.doc('users/owner/notes/c').set({ ...validNote(), pinHash: 'h' }));
    await assertFails(db.doc('users/owner/notes/d').set({ ...validNote(), isAdmin: true }));
    await assertFails(db.doc('users/owner/notes/e').set({ ...validNote(), isPinned: 'yes' }));
    await assertFails(db.doc('users/owner/notes/f').set({ ...validNote(), sharedBy: 'someone-else' }));
    await assertFails(db.doc('users/owner/notes/g').set({
      ...validNote(), collaborators: Array.from({ length: 51 }, (_, i) => `u${i}`),
    }));
  });

  it('validates profile, comment and report shapes', async () => {
    await assertSucceeds(as('u1').doc('users/u1').set({ email: 'u1@example.com', displayName: 'U', publicKey: 'pk' }));
    await assertFails(as('u1').doc('users/u1').set({ email: 'u1@example.com', isAdmin: true }));

    await seed('users/owner/notes/n1', { collaborators: ['collab'] });
    const comment = { authorUid: 'collab', authorName: 'C', encryptedContent: 'ct', keyGen: 1, createdAt: new Date() };
    await assertSucceeds(as('collab').doc('users/owner/notes/n1/comments/c1').set(comment));
    await assertFails(as('collab').doc('users/owner/notes/n1/comments/c2').set({ ...comment, content: 'plain' }));

    const report = { reporterUid: 'collab', targetOwnerUid: 'owner', noteId: 'n1', commentId: 'c1',
      commentAuthorUid: 'collab', reason: 'spam', status: 'open', createdAt: new Date() };
    await assertSucceeds(as('collab').collection('reports').add(report));
    await assertFails(as('collab').collection('reports').add({ ...report, extra: 1 }));
  });

  it('cuts collaborators off from an expired note but not its owner', async () => {
    const past = new Date(Date.now() - 60_000);
    const future = new Date(Date.now() + 3_600_000);
    await seed('users/owner/notes/expired', { collaborators: ['collab'], selfDestructAt: past });
    await seed('users/owner/notes/later', { collaborators: ['collab'], selfDestructAt: future });
    await seed('users/owner/notes/never', { collaborators: ['collab'], selfDestructAt: null });
    await assertFails(as('collab').doc('users/owner/notes/expired').get());
    await assertSucceeds(as('collab').doc('users/owner/notes/later').get());
    await assertSucceeds(as('collab').doc('users/owner/notes/never').get());
    await assertSucceeds(as('owner').doc('users/owner/notes/expired').get());
    // Comments on an expired note are closed to collaborators too.
    await assertFails(as('collab').doc('users/owner/notes/expired/comments/c1').set({ authorUid: 'collab', encryptedContent: 'x' }));
    await assertSucceeds(as('collab').doc('users/owner/notes/later/comments/c1').set({ authorUid: 'collab', encryptedContent: 'x' }));
  });

  it('still serves the shared-notes feed query', async () => {
    await seed('users/owner/notes/n1', { collaborators: ['collab'], updatedAt: new Date() });
    const snap = await assertSucceeds(as('collab').collectionGroup('notes')
      .where('collaborators', 'array-contains', 'collab').get());
    if (snap.size !== 1) throw new Error(`expected 1 shared note, got ${snap.size}`);
    await assertFails(as('stranger').collectionGroup('notes').get());
  });

  it('only accepts reports about a real comment the reporter can see', async () => {
    await seedReportable();
    const report = { reporterUid: 'reporter', targetOwnerUid: 'owner', noteId: 'note1', commentId: 'comment1',
      commentAuthorUid: 'author', reason: 'spam', status: 'open', createdAt: new Date() };
    await assertSucceeds(as('reporter').collection('reports').add(report));

    // Someone with no access to the note can't target its owner.
    await assertFails(as('stranger').collection('reports').add({ ...report, reporterUid: 'stranger' }));
    // The named author must be the comment's real author.
    await assertFails(as('reporter').collection('reports').add({ ...report, commentAuthorUid: 'owner' }));
    // The comment must exist.
    await assertFails(as('reporter').collection('reports').add({ ...report, commentId: 'nope' }));
    // A made-up owner/note pair is refused.
    await assertFails(as('reporter').collection('reports').add({ ...report, targetOwnerUid: 'victim' }));
  });

  it('lets a user delete their own profile, and only theirs', async () => {
    await seed('users/u1', { displayName: 'U', publicKey: 'pk' });
    await assertFails(as('u2').doc('users/u1').delete());
    await assertSucceeds(as('u1').doc('users/u1').delete());
  });

  it('lets authors find their comments, and recipients their join requests, for account deletion', async () => {
    await seed('users/owner/notes/n1', { collaborators: ['me', 'other'] });
    await seed('users/owner/notes/n1/comments/mine', { authorUid: 'me', encryptedContent: 'x' });
    await seed('users/owner/notes/n1/comments/theirs', { authorUid: 'other', encryptedContent: 'x' });
    await seed('shareLinks/tok/requests/me', { ownerUid: 'owner', recipientUid: 'me', noteId: 'n1', status: 'pending' });
    await seed('shareLinks/tok/requests/other', { ownerUid: 'owner', recipientUid: 'other', noteId: 'n1', status: 'pending' });

    const comments = await assertSucceeds(as('me').collectionGroup('comments').where('authorUid', '==', 'me').get());
    if (comments.size !== 1) throw new Error(`expected 1 comment, got ${comments.size}`);
    await assertFails(as('me').collectionGroup('comments').get());
    await assertFails(as('me').collectionGroup('comments').where('authorUid', '==', 'other').get());
    await assertSucceeds(as('me').doc('users/owner/notes/n1/comments/mine').delete());

    const requests = await assertSucceeds(as('me').collectionGroup('requests').where('recipientUid', '==', 'me').get());
    if (requests.size !== 1) throw new Error(`expected 1 request, got ${requests.size}`);
    await assertFails(as('me').collectionGroup('requests').where('recipientUid', '==', 'other').get());
    await assertSucceeds(as('me').doc('shareLinks/tok/requests/me').delete());
  });

  it('denies collaborator from writing to shared note', async () => {
    const dbOwner = testEnv.authenticatedContext('owner').firestore();
    const dbCollab = testEnv.authenticatedContext('collab').firestore();
    await dbOwner.collection('users/owner/notes').doc('shared').set({
      encryptedTitle: 'x',
      collaborators: ['collab'],
    });
    await assertFails(dbCollab.collection('users/owner/notes').doc('shared').set({ encryptedTitle: 'hacked' }));
  });

  it('allows authenticated user to report a comment', async () => {
    await seedReportable();
    const db = testEnv.authenticatedContext('reporter').firestore();
    await db.collection('reports').doc('report1').set({
      targetOwnerUid: 'owner',
      noteId: 'note1',
      commentId: 'comment1',
      commentAuthorUid: 'author',
      reporterUid: 'reporter',
      reason: 'Harassment',
      status: 'open',
      createdAt: new Date(),
    });
    await assertSucceeds(db.collection('reports').doc('report1').get());
  });

  it('denies creating a report on behalf of another user', async () => {
    await seedReportable();
    const db = testEnv.authenticatedContext('reporter').firestore();
    await assertFails(db.collection('reports').doc('report1').set({
      targetOwnerUid: 'owner',
      noteId: 'note1',
      commentId: 'comment1',
      commentAuthorUid: 'author',
      reporterUid: 'someoneElse',
      reason: 'Spam',
      status: 'open',
      createdAt: new Date(),
    }));
  });

  it('allows note owner to read reports on their notes', async () => {
    await seedReportable();
    const dbReporter = testEnv.authenticatedContext('reporter').firestore();
    await dbReporter.collection('reports').doc('report1').set({
      targetOwnerUid: 'owner',
      noteId: 'note1',
      commentId: 'comment1',
      commentAuthorUid: 'author',
      reporterUid: 'reporter',
      reason: 'Spam',
      status: 'open',
      createdAt: new Date(),
    });
    const dbOwner = testEnv.authenticatedContext('owner').firestore();
    await assertSucceeds(dbOwner.collection('reports').doc('report1').get());
  });

  it('denies unrelated user from reading a report', async () => {
    await seedReportable();
    const dbReporter = testEnv.authenticatedContext('reporter').firestore();
    await dbReporter.collection('reports').doc('report1').set({
      targetOwnerUid: 'owner',
      noteId: 'note1',
      commentId: 'comment1',
      commentAuthorUid: 'author',
      reporterUid: 'reporter',
      reason: 'Spam',
      status: 'open',
      createdAt: new Date(),
    });
    const dbStranger = testEnv.authenticatedContext('stranger').firestore();
    await assertFails(dbStranger.collection('reports').doc('report1').get());
  });

  it('denies anyone from updating or deleting a report', async () => {
    await seedReportable();
    const dbReporter = testEnv.authenticatedContext('reporter').firestore();
    await dbReporter.collection('reports').doc('report1').set({
      targetOwnerUid: 'owner',
      noteId: 'note1',
      commentId: 'comment1',
      commentAuthorUid: 'author',
      reporterUid: 'reporter',
      reason: 'Spam',
      status: 'open',
      createdAt: new Date(),
    });
    await assertFails(dbReporter.collection('reports').doc('report1').update({ status: 'resolved' }));
    await assertFails(dbReporter.collection('reports').doc('report1').delete());
  });

  it('allows any authenticated user to read another user publicKey', async () => {
    const dbA = testEnv.authenticatedContext('userA').firestore();
    const dbB = testEnv.authenticatedContext('userB').firestore();
    await dbB.collection('users').doc('userB').set({ email: 'b@x.com', publicKey: 'abc' });
    await assertSucceeds(dbA.collection('users').doc('userB').get());
  });

  // ---------- users / emailIndex ----------

  it('denies listing all user profiles', async () => {
    await seed('users/userB', { email: 'b@x.com', publicKey: 'abc' });
    await assertFails(as('userA').collection('users').get());
  });

  it('allows claiming own email index entry only', async () => {
    await assertSucceeds(as('alice').doc('emailIndex/alice@example.com').set({ uid: 'alice' }));
    await assertFails(as('alice').doc('emailIndex/bob@example.com').set({ uid: 'alice' }));
    await assertFails(as('alice').doc('emailIndex/alice@example.com').set({ uid: 'bob' }));
  });

  it('denies claiming an email index entry with an unverified email', async () => {
    await assertFails(as('alice', false).doc('emailIndex/alice@example.com').set({ uid: 'alice' }));
  });

  it('allows exact email lookup but not listing', async () => {
    await seed('emailIndex/bob@example.com', { uid: 'bob' });
    await assertSucceeds(as('alice').doc('emailIndex/bob@example.com').get());
    await assertFails(as('alice').collection('emailIndex').get());
  });

  it('keeps private key backup owner-only', async () => {
    await seed('users/alice/private/keyBackup', { slots: {} });
    await assertSucceeds(as('alice').doc('users/alice/private/keyBackup').get());
    await assertFails(as('bob').doc('users/alice/private/keyBackup').get());
  });

  // ---------- comments ----------

  it('allows collaborator to comment as themselves only', async () => {
    await seed('users/owner/notes/n1', { collaborators: ['collab'] });
    const db = as('collab');
    await assertSucceeds(db.doc('users/owner/notes/n1/comments/c1').set({ authorUid: 'collab', encryptedContent: 'x' }));
    await assertFails(db.doc('users/owner/notes/n1/comments/c2').set({ authorUid: 'owner', encryptedContent: 'x' }));
  });

  it('denies owner posting a comment as someone else', async () => {
    await seed('users/owner/notes/n1', { collaborators: ['collab'] });
    await assertFails(as('owner').doc('users/owner/notes/n1/comments/c1').set({ authorUid: 'collab', encryptedContent: 'x' }));
  });

  it('denies strangers reading comments', async () => {
    await seed('users/owner/notes/n1', { collaborators: ['collab'] });
    await seed('users/owner/notes/n1/comments/c1', { authorUid: 'collab' });
    await assertFails(as('stranger').doc('users/owner/notes/n1/comments/c1').get());
  });

  it('denies editing comments; allows author or owner to delete', async () => {
    await seed('users/owner/notes/n1', { collaborators: ['collab'] });
    await seed('users/owner/notes/n1/comments/c1', { authorUid: 'collab' });
    await seed('users/owner/notes/n1/comments/c2', { authorUid: 'collab' });
    await assertFails(as('collab').doc('users/owner/notes/n1/comments/c1').update({ encryptedContent: 'y' }));
    await assertSucceeds(as('collab').doc('users/owner/notes/n1/comments/c1').delete());
    await assertSucceeds(as('owner').doc('users/owner/notes/n1/comments/c2').delete());
  });

  it('denies collaborators reading version history', async () => {
    await seed('users/owner/notes/n1', { collaborators: ['collab'] });
    await seed('users/owner/notes/n1/versions/v1', { encryptedContent: 'x' });
    await assertFails(as('collab').doc('users/owner/notes/n1/versions/v1').get());
  });

  // ---------- share links ----------

  it('allows owner to create a share link for their own note', async () => {
    await seed('users/owner/notes/note1', { title: '' });
    await assertSucceeds(as('owner').doc('shareLinks/token1').set({
      ownerUid: 'owner', noteId: 'note1', mode: 'approval', createdAt: new Date(),
    }));
  });

  it('denies share links that carry a plaintext title', async () => {
    await seed('users/owner/notes/note1', { title: '' });
    await assertFails(as('owner').doc('shareLinks/token1').set({
      ownerUid: 'owner', noteId: 'note1', mode: 'approval',
      noteTitlePlain: 'My note', createdAt: new Date(),
    }));
  });

  it('denies creating a share link as another user or for a missing note', async () => {
    await seed('users/someoneElse/notes/note1', { title: '' });
    await assertFails(as('owner').doc('shareLinks/token1').set({
      ownerUid: 'someoneElse', noteId: 'note1', mode: 'approval', createdAt: new Date(),
    }));
    await assertFails(as('owner').doc('shareLinks/token2').set({
      ownerUid: 'owner', noteId: 'missing', mode: 'approval', createdAt: new Date(),
    }));
  });

  it('allows fetching a link by token but not listing links', async () => {
    await seed('shareLinks/token1', { ownerUid: 'owner', noteId: 'note1', mode: 'open' });
    await assertSucceeds(as('stranger').doc('shareLinks/token1').get());
    await assertFails(as('stranger').collection('shareLinks').get());
  });

  it('allows owners to list only their own links', async () => {
    await seed('shareLinks/token1', { ownerUid: 'owner', noteId: 'note1', mode: 'open' });
    await seed('shareLinks/token2', { ownerUid: 'other', noteId: 'note2', mode: 'open' });
    await assertSucceeds(as('owner').collection('shareLinks').where('ownerUid', '==', 'owner').get());
    await assertFails(as('owner').collection('shareLinks').where('ownerUid', '==', 'other').get());
  });

  // ---------- join requests ----------

  const request = (uid, status) => ({
    ownerUid: 'owner', noteId: 'note1', recipientUid: uid,
    recipientPublicKey: 'abc', status, createdAt: new Date(),
  });

  it('allows recipient to create a pending request', async () => {
    await seed('shareLinks/token1', { ownerUid: 'owner', noteId: 'note1', mode: 'approval' });
    await assertSucceeds(as('recipient').doc('shareLinks/token1/requests/recipient').set(request('recipient', 'pending')));
  });

  it('allows recipient to auto-approve on an open-mode link', async () => {
    await seed('shareLinks/token1', { ownerUid: 'owner', noteId: 'note1', mode: 'open' });
    await assertSucceeds(as('recipient').doc('shareLinks/token1/requests/recipient').set(request('recipient', 'approved')));
  });

  it('denies recipient self-approving on an approval-mode link', async () => {
    await seed('shareLinks/token1', { ownerUid: 'owner', noteId: 'note1', mode: 'approval' });
    await assertFails(as('recipient').doc('shareLinks/token1/requests/recipient').set(request('recipient', 'approved')));
  });

  it('denies recipient escalating their own request status', async () => {
    await seed('shareLinks/token1', { ownerUid: 'owner', noteId: 'note1', mode: 'approval' });
    await seed('shareLinks/token1/requests/recipient', request('recipient', 'pending'));
    const ref = as('recipient').doc('shareLinks/token1/requests/recipient');
    await assertFails(ref.update({ status: 'approved' }));
    await assertFails(ref.update({ approvedBy: 'owner' }));
    await assertSucceeds(ref.update({ recipientName: 'New name' }));
  });

  it('denies a request pointing at a different note than the link', async () => {
    await seed('shareLinks/token1', { ownerUid: 'owner', noteId: 'note1', mode: 'open' });
    await assertFails(as('recipient').doc('shareLinks/token1/requests/recipient').set({
      ...request('recipient', 'pending'), noteId: 'otherNote',
    }));
  });

  it('denies recipient creating a request for another user', async () => {
    await seed('shareLinks/token1', { ownerUid: 'owner', noteId: 'note1', mode: 'approval' });
    await assertFails(as('recipient').doc('shareLinks/token1/requests/someoneElse').set(request('someoneElse', 'pending')));
  });

  it('allows owner to approve with their own uid only', async () => {
    await seed('shareLinks/token1', { ownerUid: 'owner', noteId: 'note1', mode: 'approval' });
    await seed('shareLinks/token1/requests/r1', request('r1', 'pending'));
    const ref = as('owner').doc('shareLinks/token1/requests/r1');
    await assertFails(ref.update({ status: 'approved', approvedBy: 'r1' }));
    await assertSucceeds(ref.update({ status: 'approved', approvedBy: 'owner' }));
  });

  it('allows owner to read own requests via collectionGroup', async () => {
    await seed('shareLinks/token1', { ownerUid: 'owner', noteId: 'note1', mode: 'approval' });
    await seed('shareLinks/token1/requests/r1', request('r1', 'pending'));
    await assertSucceeds(as('owner').collectionGroup('requests').where('ownerUid', '==', 'owner').get());
  });

  it('denies non-owner from updating a request status', async () => {
    await seed('shareLinks/token1', { ownerUid: 'owner', noteId: 'note1', mode: 'approval' });
    await seed('shareLinks/token1/requests/r1', request('r1', 'pending'));
    await assertFails(as('intruder').doc('shareLinks/token1/requests/r1').update({ status: 'shared' }));
  });
});
