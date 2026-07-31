const { initializeTestEnvironment } = require('@firebase/rules-unit-testing');
async function main() {
  const env = await initializeTestEnvironment({ 
    projectId: 'test', 
    firestore: { rules: 'rules_version = "2"; service cloud.firestore { match /databases/{database}/documents { match /{document=**} { allow read, write: if true; } } }' } 
  });
  console.log('Has unauthenticatedContext:', typeof env.unauthenticatedContext === 'function');
  console.log('Has authenticatedContext:', typeof env.authenticatedContext === 'function');
  const ctx = env.unauthenticatedContext();
  console.log('Unauthenticated context type:', typeof ctx);
  await env.cleanup();
}
main().catch(e => console.error(e.message));
