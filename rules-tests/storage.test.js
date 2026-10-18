import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { getBytes, ref, uploadBytes, deleteObject } from 'firebase/storage';

let testEnv;

const audio = new Uint8Array(1024);

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'quiet-tally-rules',
    storage: {
      rules: readFileSync('../storage.rules', 'utf8'),
      host: '127.0.0.1',
      port: 9299,
    },
  });
});

after(async () => {
  await testEnv.cleanup();
});

describe('audio upload', () => {
  it('accepts an authenticated audio upload', async () => {
    const context = testEnv.authenticatedContext('owner-1');
    const target = ref(context.storage(), 'incidents/token-x/audio.m4a');
    await assertSucceeds(
      uploadBytes(target, audio, { contentType: 'audio/mp4' }),
    );
  });

  it('rejects an unauthenticated upload', async () => {
    const context = testEnv.unauthenticatedContext();
    const target = ref(context.storage(), 'incidents/token-y/audio.m4a');
    await assertFails(
      uploadBytes(target, audio, { contentType: 'audio/mp4' }),
    );
  });

  it('rejects the wrong content type', async () => {
    const context = testEnv.authenticatedContext('owner-1');
    const target = ref(context.storage(), 'incidents/token-z/audio.m4a');
    await assertFails(
      uploadBytes(target, audio, { contentType: 'audio/mpeg' }),
    );
  });

  it('rejects a file over the two megabyte cap', async () => {
    const context = testEnv.authenticatedContext('owner-1');
    const target = ref(context.storage(), 'incidents/token-big/audio.m4a');
    const oversized = new Uint8Array(2 * 1024 * 1024 + 1);
    await assertFails(
      uploadBytes(target, oversized, { contentType: 'audio/mp4' }),
    );
  });

  it('allows a public read of the audio', async () => {
    const owner = testEnv.authenticatedContext('owner-1');
    await assertSucceeds(
      uploadBytes(
        ref(owner.storage(), 'incidents/token-read/audio.m4a'),
        audio,
        { contentType: 'audio/mp4' },
      ),
    );
    const anonymous = testEnv.unauthenticatedContext();
    await assertSucceeds(
      getBytes(ref(anonymous.storage(), 'incidents/token-read/audio.m4a')),
    );
  });

  it('rejects delete', async () => {
    const context = testEnv.authenticatedContext('owner-1');
    const target = ref(context.storage(), 'incidents/token-del/audio.m4a');
    await assertSucceeds(
      uploadBytes(target, audio, { contentType: 'audio/mp4' }),
    );
    await assertFails(deleteObject(target));
  });
});
