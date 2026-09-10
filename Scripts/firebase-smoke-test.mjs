const projectID = "mamba-snake-4532c";
const apiKey = "AIzaSyCnTHr1xrRjHiYnydqLG6rkme9Wu-Jrvfk";
const bundleID = "com.mamba.snake";
const authBase = "https://identitytoolkit.googleapis.com/v1";
const firestoreBase =
  `https://firestore.googleapis.com/v1/projects/${projectID}/databases/(default)/documents`;

const stringValue = (value) => ({ stringValue: value });
const integerValue = (value) => ({ integerValue: String(value) });
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

let user;
let scoreCreated = false;

try {
  user = await createAnonymousUser();

  await patchDocument(user.idToken, `scores/${user.localId}`, {
    nickname: stringValue("SmokeSolo"),
    nicknameNormalized: stringValue("smokesolo"),
    ownerID: stringValue(user.localId),
    score: integerValue(42),
    level: integerValue(1),
    createdAt: timestampValue(),
    updatedAt: timestampValue(),
  });
  scoreCreated = true;

  const score = await request(`${firestoreBase}/scores/${user.localId}`, {
    headers: authHeaders(user.idToken),
  });
  if (score.fields.score?.integerValue !== "42") {
    throw new Error("Solo score was not persisted.");
  }

  const scores = await request(`${firestoreBase}/scores?pageSize=20`, {
    headers: authHeaders(user.idToken),
  });
  if ((scores.documents?.length ?? 0) < 1) {
    throw new Error("Leaderboard scores are missing.");
  }

  await request(
    `${firestoreBase}/rooms?pageSize=1`,
    { headers: authHeaders(user.idToken) },
    403,
  ).catch(async (error) => {
    // rooms collection may no longer exist in rules; 403 or missing is fine
    if (!error.message.includes("returned 403") && !error.message.includes("returned 404")) {
      // Firestore may return permission-denied as 403 for unmatched paths depending on rules
      // With only /scores match, unmatched paths deny by default → 403
      throw error;
    }
  });

  console.log("FIREBASE_SMOKE_TEST_OK");
  console.log(`SCORE_DOCUMENTS=${scores.documents?.length ?? 0}`);
} finally {
  if (scoreCreated && user?.idToken) {
    await deleteDocument(user.idToken, `scores/${user.localId}`).catch(() => {});
  }
  if (user?.idToken) {
    await deleteAnonymousUser(user.idToken).catch(() => {});
  }
}
