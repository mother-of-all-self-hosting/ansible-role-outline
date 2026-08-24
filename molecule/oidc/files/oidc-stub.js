// SPDX-FileCopyrightText: 2026 Slavi Pantaleev
//
// SPDX-License-Identifier: AGPL-3.0-or-later

// A throwaway OpenID Connect provider for the `oidc` Molecule scenario.
//
// It is deliberately not a real provider: it signs nothing, remembers nothing
// and issues the same opaque access token to anyone who asks with the right
// client credentials. What it does do is refuse to play along unless the
// client ID and client secret it is handed match the ones this scenario
// configured the role with, so that completing a sign-in against it is proof
// that both values travelled intact from the scenario's variables, through
// the `env` file the role templates, through Docker's `--env-file` parsing,
// and into the request Outline makes.
//
// Outline sends those credentials in the token request body rather than as
// HTTP Basic authentication, and this checks them where Outline puts them.
//
// It runs on Outline's own container image, on the container network the role
// creates. Reusing that image keeps the scenario to a single pull: the image
// is already there because the role pulled it, it ships a Node runtime, and
// this file needs nothing beyond the standard library. Running on the role's
// network is not a stylistic choice - Docker 28 and newer stop a container on
// a bridge network from reaching ports published on that bridge's gateway, so
// a listener on the test host would not be reachable from Outline's container.
//
// Configuration arrives through the environment, so that nothing here has to
// be kept in sync with the scenario by hand.

const http = require("http");

const port = Number(process.env.STUB_PORT || 9000);
const expectedClientId = process.env.STUB_CLIENT_ID || "";
const expectedClientSecret = process.env.STUB_CLIENT_SECRET || "";
const accessToken = process.env.STUB_ACCESS_TOKEN || "molecule-access-token";

// `email_verified` is load-bearing rather than decorative. Outline lets the
// very first sign-in create the team without it, but refuses every later one
// against an existing team - so a stub that omitted it would pass on a fresh
// database and fail on a re-run.
const claims = {
  sub: process.env.STUB_SUBJECT || "molecule-oidc-subject",
  preferred_username: process.env.STUB_USERNAME || "moleculeuser",
  email: process.env.STUB_EMAIL || "molecule@example.com",
  email_verified: true,
  name: process.env.STUB_NAME || "Molecule User",
};

const respondJson = (response, statusCode, payload) => {
  const body = JSON.stringify(payload);
  response.writeHead(statusCode, {
    "Content-Type": "application/json",
    "Content-Length": Buffer.byteLength(body),
  });
  response.end(body);
};

const server = http.createServer((request, response) => {
  const path = request.url.split("?")[0];

  let body = "";
  request.on("data", (chunk) => {
    body += chunk;
  });

  request.on("end", () => {
    // Where a browser would be sent to sign in. This scenario never follows
    // the redirect - it is Outline's `Location` that is worth asserting on,
    // not what a stub chooses to answer - but a provider that 404s its own
    // authorization endpoint would be a confusing thing to leave lying about.
    if (path === "/authorize") {
      const parameters = new URLSearchParams(request.url.split("?")[1] || "");
      const redirectUri = parameters.get("redirect_uri");

      if (!redirectUri) {
        respondJson(response, 400, { error: "invalid_request" });
        return;
      }

      const target = new URL(redirectUri);
      target.searchParams.set("code", "molecule-authorization-code");
      if (parameters.get("state")) {
        target.searchParams.set("state", parameters.get("state"));
      }

      response.writeHead(302, { Location: target.toString() });
      response.end();
      return;
    }

    if (path === "/token") {
      const parameters = new URLSearchParams(body);

      if (
        parameters.get("client_id") !== expectedClientId ||
        parameters.get("client_secret") !== expectedClientSecret
      ) {
        console.log(
          "rejecting token request: client_id=" +
            JSON.stringify(parameters.get("client_id")) +
            " client_secret=" +
            JSON.stringify(parameters.get("client_secret"))
        );
        respondJson(response, 401, { error: "invalid_client" });
        return;
      }

      console.log("issuing an access token to " + expectedClientId);
      respondJson(response, 200, {
        access_token: accessToken,
        token_type: "Bearer",
        expires_in: 3600,
      });
      return;
    }

    if (path === "/userinfo") {
      if (request.headers.authorization !== "Bearer " + accessToken) {
        console.log("rejecting userinfo request with an unknown access token");
        respondJson(response, 401, { error: "invalid_token" });
        return;
      }

      console.log("describing " + claims.email);
      respondJson(response, 200, claims);
      return;
    }

    respondJson(response, 404, { error: "not_found" });
  });
});

server.listen(port, "0.0.0.0", () => {
  console.log("The Outline Molecule OIDC stub is listening on " + port);
});
