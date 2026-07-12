const projectID = "mamba-snake-4532c";
const apiKey = "AIzaSyCnTHr1xrRjHiYnydqLG6rkme9Wu-Jrvfk";
const bundleID = "com.mamba.snake";
const authBase = "https://identitytoolkit.googleapis.com/v1";
const firestoreBase =
  `https://firestore.googleapis.com/v1/projects/${projectID}/databases/(default)/documents`;

const stringValue = (value) => ({ stringValue: value });
const integerValue = (value) => ({ integerValue: String(value) });
const doubleValue = (value) => ({ doubleValue: value });
const arrayValue = (values) => ({ arrayValue: { values } });
const timestampValue = () => ({ timestampValue: new Date().toISOString() });

async function request(url, options, expectedStatus = 200) {
  const response = await fetch(url, options);
  if (response.status !== expectedStatus) {
    const body = await response.text();
    throw new Error(`${options.method ?? "GET"} ${url} returned ${response.status}: ${body}`);
  }
  return response.status === 204 ? null : response.json();
}

async function createAnonymousUser() {
  return request(`${authBase}/accounts:signUp?key=${apiKey}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Ios-Bundle-Identifier": bundleID,
    },
    body: JSON.stringify({ returnSecureToken: true }),
  });
}

async function deleteAnonymousUser(idToken) {
  await request(`${authBase}/accounts:delete?key=${apiKey}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Ios-Bundle-Identifier": bundleID,
    },
    body: JSON.stringify({ idToken }),
  });
}

function authHeaders(idToken) {
  return {
    Authorization: `Bearer ${idToken}`,
    "Content-Type": "application/json",
  };
}

async function patchDocument(idToken, path, fields, updateMask = []) {
  const url = new URL(`${firestoreBase}/${path}`);
  for (const field of updateMask) {
    url.searchParams.append("updateMask.fieldPaths", field);
  }

  return request(url, {
    method: "PATCH",
    headers: authHeaders(idToken),
    body: JSON.stringify({ fields }),
  });
}

async function deleteDocument(idToken, path) {
  await request(`${firestoreBase}/${path}`, {
    method: "DELETE",
    headers: authHeaders(idToken),
  });
}

async function runQuery(idToken, structuredQuery) {
  return request(`${firestoreBase}:runQuery`, {
    method: "POST",
    headers: authHeaders(idToken),
    body: JSON.stringify({ structuredQuery }),
  });
}

function makeRoomCode() {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  return Array.from({ length: 6 }, () => alphabet[Math.floor(Math.random() * alphabet.length)]).join("");
}

let host;
let guest;
let roomCode;
let roomCreated = false;
let multiplayerScoreCreated = false;

try {
  host = await createAnonymousUser();
  guest = await createAnonymousUser();
  roomCode = makeRoomCode();

  await patchDocument(host.idToken, `rooms/${roomCode}`, {
    hostID: stringValue(host.localId),
    hostNickname: stringValue("SmokeHost"),
    hostDirection: stringValue("none"),
    guestDirection: stringValue("none"),
    status: stringValue("waiting"),
    createdAt: timestampValue(),
    updatedAt: timestampValue(),
  });
  roomCreated = true;

  await request(`${firestoreBase}/rooms/${roomCode}`, {
    headers: authHeaders(guest.idToken),
  });

  await patchDocument(
    guest.idToken,
    `rooms/${roomCode}`,
    {
      guestID: stringValue(guest.localId),
      guestNickname: stringValue("SmokeGuest"),
      guestDirection: stringValue("none"),
      status: stringValue("playing"),
      updatedAt: timestampValue(),
    },
    ["guestID", "guestNickname", "guestDirection", "status", "updatedAt"],
  );

  await patchDocument(
    guest.idToken,
    `rooms/${roomCode}`,
    {
      guestDirection: stringValue("right"),
      guestUpdatedAt: timestampValue(),
    },
    ["guestDirection", "guestUpdatedAt"],
  );

  await patchDocument(
    host.idToken,
    `rooms/${roomCode}`,
    {
      sequence: integerValue(1),
      gridRevision: integerValue(1),
      hostX: doubleValue(10.5),
      hostY: doubleValue(0.5),
      guestX: doubleValue(20.5),
      guestY: doubleValue(0.5),
      snakeX: doubleValue(8.5),
      snakeY: doubleValue(30.5),
      score: integerValue(100),
      lives: integerValue(3),
      level: integerValue(1),
      percentCovered: doubleValue(2.5),
      gameState: stringValue("playing"),
      updatedAt: timestampValue(),
    },
    [
      "sequence", "gridRevision", "hostX", "hostY", "guestX", "guestY",
      "snakeX", "snakeY", "score", "lives", "level", "percentCovered",
      "gameState", "updatedAt",
    ],
  );

  const room = await request(`${firestoreBase}/rooms/${roomCode}`, {
    headers: authHeaders(guest.idToken),
  });
  if (room.fields.score?.integerValue !== "100") {
    throw new Error("Guest did not receive the host snapshot.");
  }

  await patchDocument(host.idToken, `multiplayerScores/${roomCode}`, {
    ownerID: stringValue(host.localId),
    hostID: stringValue(host.localId),
    guestID: stringValue(guest.localId),
    playerIDs: arrayValue([stringValue(host.localId), stringValue(guest.localId)]),
    hostNickname: stringValue("SmokeHost"),
    guestNickname: stringValue("SmokeGuest"),
    score: integerValue(100),
    level: integerValue(1),
    createdAt: timestampValue(),
    updatedAt: timestampValue(),
  });
  multiplayerScoreCreated = true;

  await patchDocument(
    guest.idToken,
    `multiplayerScores/${roomCode}`,
    {
      score: integerValue(9999),
      updatedAt: timestampValue(),
    },
    ["score", "updatedAt"],
  ).then(
    () => { throw new Error("Guest was allowed to overwrite the team score."); },
    (error) => {
      if (!error.message.includes("returned 403")) throw error;
    },
  );

  const multiplayerScore = await request(`${firestoreBase}/multiplayerScores/${roomCode}`, {
    headers: authHeaders(guest.idToken),
  });
  if (multiplayerScore.fields.score?.integerValue !== "100") {
    throw new Error("Co-op leaderboard score was not persisted.");
  }

  const userBestTeam = await runQuery(host.idToken, {
    from: [{ collectionId: "multiplayerScores" }],
    where: {
      fieldFilter: {
        field: { fieldPath: "playerIDs" },
        op: "ARRAY_CONTAINS",
        value: stringValue(host.localId),
      },
    },
    orderBy: [{ field: { fieldPath: "score" }, direction: "DESCENDING" }],
    limit: 1,
  });
  if (!userBestTeam.some((result) => result.document?.name.endsWith(`/${roomCode}`))) {
    throw new Error("Co-op user best query did not return the team score.");
  }

  const scores = await request(`${firestoreBase}/scores?pageSize=20`, {
    headers: authHeaders(host.idToken),
  });
  if ((scores.documents?.length ?? 0) < 5) {
    throw new Error("Migrated leaderboard scores are missing.");
  }

  await request(
    `${firestoreBase}/rooms?pageSize=1`,
    { headers: authHeaders(guest.idToken) },
    403,
  );

  console.log("FIREBASE_SMOKE_TEST_OK");
  console.log(`MIGRATED_SCORE_DOCUMENTS=${scores.documents.length}`);
  console.log("MULTIPLAYER_SCORE_RULES_OK");
  console.log("MULTIPLAYER_SCORE_INDEX_OK");
} finally {
  if (multiplayerScoreCreated && host?.idToken && roomCode) {
    await deleteDocument(host.idToken, `multiplayerScores/${roomCode}`).catch(() => {});
  }
  if (roomCreated && host?.idToken && roomCode) {
    await deleteDocument(host.idToken, `rooms/${roomCode}`).catch(() => {});
  }
  if (guest?.idToken) {
    await deleteAnonymousUser(guest.idToken).catch(() => {});
  }
  if (host?.idToken) {
    await deleteAnonymousUser(host.idToken).catch(() => {});
  }
}