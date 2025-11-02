# Firestore

## Rules
The database was configured to have a production security applied. Each write operation to the collections is handled by a signed in Firebase email authenticated account. Read access is open by default.
```
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    function isSignedIn() {
      return request.auth != null;
    }

    // words
    match /words/{docId} {
      allow read, write: if isSignedIn();
    }
    match /words/{docId}/{sub=**} {
      allow read, write: if isSignedIn();
    }

    // attempts
    match /attempts/{docId} {
      allow read, write: if isSignedIn();
    }
    match /attempts/{docId}/{sub=**} {
      allow read, write: if isSignedIn();
    }

    // classes
    match /classes/{docId} {
      allow read, write: if isSignedIn();
    }
    match /classes/{docId}/{sub=**} {
      allow read, write: if isSignedIn();
    }

    // students
    match /students/{docId} {
      allow read, write: if isSignedIn();
    }
    match /students/{docId}/{sub=**} {
      allow read, write: if isSignedIn();
    }

    // users
    match /users/{docId} {
      allow read, write: if isSignedIn();
    }
    match /users/{docId}/{sub=**} {
      allow read, write: if isSignedIn();
    }

    // deny everything else
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```