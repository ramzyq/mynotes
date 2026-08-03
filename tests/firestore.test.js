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
    await db.collection('users/user1/notes').doc('note1').set({ title: 'test' });
    await assertSucceeds(db.collection('users/user1/notes').doc('note1').get());
  });

  it('denies user A reading user B note', async () => {
    const dbA = testEnv.authenticatedContext('userA').firestore();
    const dbB = testEnv.authenticatedContext('userB').firestore();
    await dbB.collection('users/userB/notes').doc('secret').set({ title: 'secret' });
    await assertFails(dbA.collection('users/userB/notes').doc('secret').get());
  });

  it('allows collaborator to read shared note', async () => {
    const dbOwner = testEnv.authenticatedContext('owner').firestore();
    const dbCollab = testEnv.authenticatedContext('collab').firestore();
    await dbOwner.collection('users/owner/notes').doc('shared').set({
      title: 'shared',
      collaborators: ['collab'],
    });
    await assertSucceeds(dbCollab.collection('users/owner/notes').doc('shared').get());
  });

  it('denies collaborator from writing to shared note', async () => {
    const dbOwner = testEnv.authenticatedContext('owner').firestore();
    const dbCollab = testEnv.authenticatedContext('collab').firestore();
    await dbOwner.collection('users/owner/notes').doc('shared').set({
      title: 'shared',
      collaborators: ['collab'],
    });
    await assertFails(dbCollab.collection('users/owner/notes').doc('shared').set({ title: 'hacked' }));
  });

  it('allows authenticated user to report a comment', async () => {
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
});
