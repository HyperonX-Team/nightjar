import { initializeApp } from 'https://www.gstatic.com/firebasejs/10.12.2/firebase-app.js';
import {
  collection,
  connectFirestoreEmulator,
  doc,
  getFirestore,
  onSnapshot,
  orderBy,
  query,
} from 'https://www.gstatic.com/firebasejs/10.12.2/firebase-firestore.js';
import { config } from '/config.js';

const el = {
  title: document.getElementById('status-title'),
  liveBadge: document.getElementById('live-badge'),
  statusLine: document.getElementById('status-line'),
  loader: document.getElementById('loader'),
  main: document.getElementById('main'),
  coordinates: document.getElementById('coordinates'),
  locationAge: document.getElementById('location-age'),
  audioSection: document.getElementById('audio-section'),
  audio: document.getElementById('audio'),
  audioNote: document.getElementById('audio-note'),
  expiry: document.getElementById('expiry'),
  call: document.getElementById('call'),
};

const view = {
  map: null,
  marker: null,
  circle: null,
  trailLine: null,
  trailPoints: [],
  lastFix: null,
  incident: null,
  offline: false,
  sawDocument: false,
};

const STALE_AGE_MS = 2 * 60 * 1000;

function tokenFromPath() {
  const match = window.location.pathname.match(/^\/i\/([A-Za-z0-9_-]{16,64})$/);
  return match ? match[1] : null;
}

function setStatus(title, detail, options = {}) {
  el.title.textContent = title;
  el.liveBadge.hidden = !options.live;
  if (detail) {
    el.statusLine.textContent = detail;
    el.statusLine.hidden = false;
  } else {
    el.statusLine.textContent = '';
    el.statusLine.hidden = true;
  }
}

function showLoading() {
  el.loader.hidden = false;
  el.main.hidden = true;
}

function showExpired() {
  el.loader.hidden = true;
  el.main.hidden = true;
  setStatus('This alert does not exist or has expired', '');
}

function showOffline() {
  el.loader.hidden = true;
  const fix = view.lastFix;
  setStatus(
    'No connection. Retrying.',
    fix ? `Last known location ${relativeAge(fix.at)}` : '',
  );
}

function relativeAge(at) {
  const seconds = Math.max(0, Math.round((Date.now() - at.getTime()) / 1000));
  if (seconds < 5) {
    return 'just now';
  }
  if (seconds < 60) {
    return `${seconds} seconds ago`;
  }
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) {
    return minutes === 1 ? '1 minute ago' : `${minutes} minutes ago`;
  }
  const hours = Math.floor(minutes / 60);
  return hours === 1 ? '1 hour ago' : `${hours} hours ago`;
}

function formatDateTime(date) {
  return date.toLocaleString(undefined, {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

function toDate(value) {
  if (!value) {
    return null;
  }
  if (typeof value.toDate === 'function') {
    return value.toDate();
  }
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function audioUrl(path) {
  return (
    `https://firebasestorage.googleapis.com/v0/b/${config.storageBucket}` +
    `/o/${encodeURIComponent(path)}?alt=media`
  );
}

function ensureMap() {
  if (view.map || typeof window.L === 'undefined') {
    return;
  }
  view.map = window.L.map('map', {
    attributionControl: true,
    zoomControl: true,
  }).setView([0, 0], 2);
  window.L
    .tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19,
      attribution:
        '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
    })
    .addTo(view.map);
}

function renderMap(fix, accuracyMeters) {
  if (!fix) {
    return;
  }
  ensureMap();
  if (!view.map) {
    return;
  }
  const point = [fix.latitude, fix.longitude];
  if (!view.marker) {
    view.marker = window.L
      .circleMarker(point, {
        radius: 7,
        color: '#9c3d2e',
        weight: 2,
        fillColor: '#9c3d2e',
        fillOpacity: 1,
      })
      .addTo(view.map);
  } else {
    view.marker.setLatLng(point);
  }
  if (Number.isFinite(accuracyMeters)) {
    if (!view.circle) {
      view.circle = window.L
        .circle(point, {
          radius: accuracyMeters,
          color: '#1c1b18',
          weight: 1,
          fillOpacity: 0.05,
        })
        .addTo(view.map);
    } else {
      view.circle.setLatLng(point);
      view.circle.setRadius(accuracyMeters);
    }
  }
  const zoom = view.map.getZoom();
  view.map.setView(point, zoom > 15 ? zoom : 16);
}

function renderTrail() {
  if (!view.map || view.trailPoints.length < 2) {
    return;
  }
  const points = view.trailPoints.map((fix) => [
    fix.latitude,
    fix.longitude,
  ]);
  if (!view.trailLine) {
    view.trailLine = window.L
      .polyline(points, { color: '#1c1b18', weight: 2, opacity: 0.7 })
      .addTo(view.map);
  } else {
    view.trailLine.setLatLngs(points);
  }
}

function renderLocation(data) {
  const point = data.location;
  const hasFix = point && typeof point.latitude === 'number';
  if (!hasFix) {
    el.coordinates.hidden = true;
    view.lastFix = null;
    el.locationAge.textContent = 'Location unavailable';
    el.locationAge.hidden = false;
    return;
  }
  const fix = { latitude: point.latitude, longitude: point.longitude };
  const updatedAt = toDate(data.locationUpdatedAt) || new Date();
  view.lastFix = { ...fix, at: updatedAt };
  el.coordinates.textContent =
    `${fix.latitude.toFixed(6)}, ${fix.longitude.toFixed(6)}`;
  el.coordinates.hidden = false;
  const accuracy = Number.isFinite(data.accuracyMeters)
    ? `Accuracy ${Math.round(data.accuracyMeters)} m. `
    : '';
  const stale = Date.now() - updatedAt.getTime() > STALE_AGE_MS;
  el.locationAge.textContent = stale
    ? `Location is not updating. Last update ${relativeAge(updatedAt)}`
    : `${accuracy}Updated ${relativeAge(updatedAt)}`;
  el.locationAge.hidden = false;
  renderMap(fix, data.accuracyMeters);
  renderTrail();
}

function renderAudio(data) {
  const audio = data.audio || {};
  const path = audio.path;
  const usable =
    path && (audio.status === 'ready' || audio.status === 'partial');
  if (!usable) {
    el.audioSection.hidden = false;
    el.audio.hidden = true;
    el.audioNote.textContent = 'Audio unavailable';
    el.audioNote.hidden = false;
    return;
  }
  const url = audioUrl(path);
  if (el.audio.dataset.src !== url) {
    el.audio.dataset.src = url;
    el.audio.src = url;
  }
  const recordedAt = toDate(audio.uploadedAt) || toDate(data.updatedAt);
  const duration = Number.isFinite(audio.durationSec)
    ? `${audio.durationSec} seconds`
    : '';
  el.audioSection.hidden = false;
  el.audio.hidden = false;
  el.audioNote.textContent = [
    duration,
    recordedAt ? `Recorded ${relativeAge(recordedAt)}` : '',
  ]
    .filter(Boolean)
    .join('. ');
  el.audioNote.hidden = el.audioNote.textContent === '';
}

function renderExpiry(data) {
  const expiresAt = toDate(data.expiresAt);
  if (!expiresAt) {
    el.expiry.hidden = true;
    return;
  }
  el.expiry.textContent = `This page stops working at ${formatDateTime(expiresAt)}`;
  el.expiry.hidden = false;
}

function renderIncident(data) {
  view.incident = data;
  const expiresAt = toDate(data.expiresAt);
  const expired = expiresAt !== null && expiresAt.getTime() <= Date.now();
  const ended = data.status === 'ended' || expired;
  el.loader.hidden = true;
  el.main.hidden = false;
  el.call.href = `tel:${config.emergencyNumber}`;

  if (ended) {
    const endTime =
      toDate(data.updatedAt) || toDate(data.createdAt) || new Date();
    setStatus('This alert ended', formatDateTime(endTime));
  } else {
    const name = typeof data.name === 'string' && data.name ? data.name : '';
    setStatus(
      data.trigger === 'test' ? 'Test alert' : `Alert from ${name}`,
      '',
      { live: true },
    );
  }

  renderLocation(data);
  renderAudio(data);
  renderExpiry(data);
}

function renderPings(snapshot) {
  view.trailPoints = snapshot.docs
    .map((entry) => {
      const value = entry.data();
      const point = value.location;
      if (!point || typeof point.latitude !== 'number') {
        return null;
      }
      return {
        latitude: point.latitude,
        longitude: point.longitude,
        accuracyMeters: value.accuracyMeters,
        at: toDate(value.at) || new Date(),
      };
    })
    .filter(Boolean);
  renderTrail();
}

function start(token) {
  const app = initializeApp(config);
  const db = getFirestore(app);
  if (config.useEmulator) {
    // Port matches the emulators block in firebase.json.
    connectFirestoreEmulator(db, config.emulatorHost, 8180);
  }

  // If no snapshot arrives at all, say so instead of sitting on the loading
  // state: the subscription keeps retrying in the background.
  window.setTimeout(() => {
    if (!view.incident && !view.offline) {
      view.offline = true;
      showOffline();
    }
  }, 12000);

  onSnapshot(
    doc(db, 'incidents', token),
    (snapshot) => {
      if (!snapshot.exists()) {
        // No document in the cache means no connection, not a missing alert.
        if (snapshot.metadata.fromCache) {
          showOffline();
        } else {
          showExpired();
        }
        return;
      }
      view.sawDocument = true;
      if (!snapshot.metadata.fromCache) {
        view.offline = false;
      }
      renderIncident(snapshot.data());
    },
    () => {
      view.offline = true;
      showOffline();
    },
  );

  onSnapshot(
    query(
      collection(db, 'incidents', token, 'pings'),
      orderBy('at', 'asc'),
    ),
    (snapshot) => {
      renderPings(snapshot);
    },
    () => {
      // The trail is optional: the parent document still carries the last fix.
    },
  );

  window.setInterval(() => {
    if (view.offline) {
      showOffline();
      return;
    }
    if (view.incident) {
      renderIncident(view.incident);
    }
  }, 10000);

  window.addEventListener('offline', () => {
    view.offline = true;
    showOffline();
  });
  window.addEventListener('online', () => {
    view.offline = false;
    if (view.incident) {
      renderIncident(view.incident);
    }
  });
}

const token = tokenFromPath();
if (token) {
  showLoading();
  start(token);
} else {
  showExpired();
}
