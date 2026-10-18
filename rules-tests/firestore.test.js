import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Timestamp,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  collection,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

let testEnv;

const day = 24 * 60 * 60 * 1000;

function incident(ownerUid, overrides = {}) {
  const now = Date.now();
  return {
    ownerUid,
    schemaVersion: 1,
    status: 'active',
    trigger: 'pin',
    createdAt: Timestamp.fromMillis(now),
    updatedAt: Timestamp.fromMillis(now),
    expiresAt: Timestamp.fromMillis(now + day),
    locationUnavailable: true,
    contactsAlerted: 0,
    delivery: [],
    appVersion: '1.0.0+1',
    ...overrides,
  };
}

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'quiet-tally-rules',
    firestore: {
      rules: readFileSync('../firestore.rules', 'utf8'),
      host: '127.0.0.1',
      port: 8180,
    },
  });
});

after(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

describe('incident create', () => {
  it('rejects an unauthenticated create', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(
      setDoc(doc(db, 'incidents', 'token-a'), incident('nobody')),
    );
  });

  it('accepts an owner create', async () => {
    const db = testEnv.authenticatedContext('owner-1').firestore();
    await assertSucceeds(
      setDoc(doc(db, 'incidents', 'token-b'), incident('owner-1')),
    );
  });

  it('rejects a mismatched ownerUid', async () => {
    const db = testEnv.authenticatedContext('owner-1').firestore();
    await assertFails(
      setDoc(doc(db, 'incidents', 'token-c'), incident('owner-2')),
    );
  });

  it('rejects another schemaVersion', async () => {
    const db = testEnv.authenticatedContext('owner-1').firestore();
    await assertFails(
      setDoc(
        doc(db, 'incidents', 'token-d'),
        incident('owner-1', { schemaVersion: 2 }),
      ),
    );
  });

  it('rejects a status other than active', async () => {
    const db = testEnv.authenticatedContext('owner-1').firestore();
    await assertFails(
      setDoc(
        doc(db, 'incidents', 'token-e'),
        incident('owner-1', { status: 'ended' }),
      ),
    );
  });

  it('rejects a missing expiresAt', async () => {
    const db = testEnv.authenticatedContext('owner-1').firestore();
    const payload = incident('owner-1');
    delete payload.expiresAt;
    await assertFails(setDoc(doc(db, 'incidents', 'token-f'), payload));
  });

  it('rejects an expiresAt in the past', async () => {
    const db = testEnv.authenticatedContext('owner-1').firestore();
    await assertFails(
      setDoc(
        doc(db, 'incidents', 'token-g'),
        incident('owner-1', {
          expiresAt: Timestamp.fromMillis(Date.now() - day),
        }),
      ),
    );
  });
});

describe('incident read', () => {
  it('allows a public get by token', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), 'incidents', 'token-h'),
        incident('owner-1'),
      );
    });
    const db = testEnv.unauthenticatedContext().firestore();
    await assertSucceeds(getDoc(doc(db, 'incidents', 'token-h')));
  });

  it('denies listing the collection', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDocs(collection(db, 'incidents')));
  });
});

describe('incident update', () => {
  it('allows the owner to publish a fix', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), 'incidents', 'token-i'),
        incident('owner-1'),
      );
    });
    const db = testEnv.authenticatedContext('owner-1').firestore();
    await assertSucceeds(
      updateDoc(doc(db, 'incidents', 'token-i'), {
        locationUnavailable: false,
        accuracyMeters: 12,
      }),
    );
  });

  it('rejects an update from another account', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), 'incidents', 'token-j'),
        incident('owner-1'),
      );
    });
    const db = testEnv.authenticatedContext('owner-2').firestore();
    await assertFails(
      updateDoc(doc(db, 'incidents', 'token-j'), { status: 'ended' }),
    );
  });

  it('rejects changing ownerUid', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), 'incidents', 'token-k'),
        incident('owner-1'),
      );
    });
    const db = testEnv.authenticatedContext('owner-1').firestore();
    await assertFails(
      updateDoc(doc(db, 'incidents', 'token-k'), { ownerUid: 'owner-2' }),
    );
  });

  it('rejects changing schemaVersion', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), 'incidents', 'token-l'),
        incident('owner-1'),
      );
    });
    const db = testEnv.authenticatedContext('owner-1').firestore();
    await assertFails(
      updateDoc(doc(db, 'incidents', 'token-l'), { schemaVersion: 2 }),
    );
  });

  it('rejects an update after expiry', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), 'incidents', 'token-m'),
        incident('owner-1', {
          expiresAt: Timestamp.fromMillis(Date.now() - 1000),
        }),
      );
    });
    const db = testEnv.authenticatedContext('owner-1').firestore();
    await assertFails(
      updateDoc(doc(db, 'incidents', 'token-m'), { status: 'ended' }),
    );
  });
});

describe('incident delete', () => {
  it('allows the owner to delete', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), 'incidents', 'token-n'),
        incident('owner-1'),
      );
    });
    const db = testEnv.authenticatedContext('owner-1').firestore();
    await assertSucceeds(deleteDoc(doc(db, 'incidents', 'token-n')));
  });

  it('rejects a delete from another account', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), 'incidents', 'token-o'),
        incident('owner-1'),
      );
    });
    const db = testEnv.authenticatedContext('owner-2').firestore();
    await assertFails(deleteDoc(doc(db, 'incidents', 'token-o')));
  });
});

describe('pings', () => {
  async function seedParent() {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), 'incidents', 'token-p'),
        incident('owner-1'),
      );
    });
  }

  function ping(overrides = {}) {
    const now = Date.now();
    return {
      location: { latitude: 1.3521, longitude: 103.8198 },
      accuracyMeters: 12,
      at: Timestamp.fromMillis(now),
      atClient: Timestamp.fromMillis(now),
      expiresAt: Timestamp.fromMillis(now + day),
      ...overrides,
    };
  }

  it('allows the owner to add a ping', async () => {
    await seedParent();
    const db = testEnv.authenticatedContext('owner-1').firestore();
    await assertSucceeds(
      setDoc(doc(db, 'incidents', 'token-p', 'pings', 'ping-1'), ping()),
    );
  });

  it('rejects a ping from an unrelated account', async () => {
    await seedParent();
    const db = testEnv.authenticatedContext('owner-2').firestore();
    await assertFails(
      setDoc(doc(db, 'incidents', 'token-p', 'pings', 'ping-2'), ping()),
    );
  });

  it('rejects a ping that is already expired', async () => {
    await seedParent();
    const db = testEnv.authenticatedContext('owner-1').firestore();
    await assertFails(
      setDoc(
        doc(db, 'incidents', 'token-p', 'pings', 'ping-3'),
        ping({ expiresAt: Timestamp.fromMillis(Date.now() - 1000) }),
      ),
    );
  });

  it('rejects updating a ping', async () => {
    await seedParent();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), 'incidents', 'token-p', 'pings', 'ping-4'),
        ping(),
      );
    });
    const db = testEnv.authenticatedContext('owner-1').firestore();
    await assertFails(
      updateDoc(doc(db, 'incidents', 'token-p', 'pings', 'ping-4'), {
        accuracyMeters: 5,
      }),
    );
  });

  it('rejects deleting a ping', async () => {
    await seedParent();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), 'incidents', 'token-p', 'pings', 'ping-5'),
        ping(),
      );
    });
    const db = testEnv.authenticatedContext('owner-1').firestore();
    await assertFails(
      deleteDoc(doc(db, 'incidents', 'token-p', 'pings', 'ping-5')),
    );
  });

  it('allows the public to read pings by token path', async () => {
    await seedParent();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), 'incidents', 'token-p', 'pings', 'ping-6'),
        ping(),
      );
    });
    const db = testEnv.unauthenticatedContext().firestore();
    const snapshot = await assertSucceeds(
      getDocs(collection(db, 'incidents', 'token-p', 'pings')),
    );
    assert.equal(snapshot.size, 1);
  });
});
