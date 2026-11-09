# Tutorial: a serverless guestbook, one deployed piece at a time

**You write every file and every test. This guide says what to build, why, where to read
more, and how to know it worked.** Each milestone ends with something new live on the internet,
so you see the architecture appear one layer at a time.

The same pieces are in appbep, so whenever you're stuck there's a working example a folder away.
Pointers like `appbep: infra/lib/site-stack.ts:156` are to `~/dev/appbep`;
`mathx: shared/src/api.ts` is `~/dev/mathisthenics-app`.

**Tools:** Node 22 (`.nvmrc`), npm workspaces, TypeScript everywhere, Vite + React 19, Vitest,
AWS CDK v2, the `appbep` AWS profile (us-east-1).

**Cost:** about nothing. S3, CloudFront, Lambda, API Gateway and DynamoDB on-demand all charge
per use, and a guestbook's traffic is far inside the free tiers. Nothing here runs (or bills)
while idle; that's what "serverless" buys you.

---

## The big picture

```
 browser ─▶ CloudFront ─┬─ /*      ─▶ S3          the built React app (static files)
                        └─ /api/*  ─▶ API Gateway ─▶ Lambda ─▶ DynamoDB
```

Four ideas carry over to every app like this (appbep, Mathisthenics, the NPuzzle leaderboard):

1. **The frontend is just files.** React builds to HTML/JS/CSS; S3 stores them; CloudFront
   serves them over HTTPS from edge locations. No server runs your UI.
2. **The backend is a function, not a server.** API Gateway turns each HTTPS request into one
   Lambda call with an event object; your handler returns a status, headers and body.
3. **One address for both.** CloudFront routes `/api/*` to the API and everything else to S3.
   The browser sees a single origin, so there's no CORS to configure. (appbep does exactly this.)
4. **Infrastructure is code.** CDK (TypeScript) describes the resources; `cdk deploy` turns that
   into a CloudFormation stack and creates, changes or deletes resources to match.

Reading list for the whole project, in this order:

- [What is the AWS CDK?](https://docs.aws.amazon.com/cdk/v2/guide/home.html) and
  [CDK concepts: apps, stacks, constructs](https://docs.aws.amazon.com/cdk/v2/guide/core-concepts.html)
- [npm workspaces](https://docs.npmjs.com/cli/v10/using-npm/workspaces)
- [Vite: getting started](https://vite.dev/guide/) and [Vitest: getting started](https://vitest.dev/guide/)

---

## How to work through it

- One milestone = one branch = one PR (from milestone 0 on, once the repo exists).
- **Tests first** where there's logic: write the test, watch it fail, make it pass.
- Before each commit: `npm run check` (you build that script in milestone 0) must pass.
- Each milestone ends with **Deploy** and **Check** sections. Until milestone 6, you deploy from
  your laptop; after it, merging deploys.
- Tick the milestone off in the README's Status list.

---

## Milestone 0: repo and workspace

**Goal:** the root of the monorepo: the files that sit **above** the four folders and tie them
together. No app code yet.

You create three files at the repo root, by hand or with a command:

```
guestbook/
├─ package.json        ← you write it (or `npm init -y`, then edit)
├─ package-lock.json   ← npm creates it; never edit it, always commit it
├─ tsconfig.base.json  ← you write it
├─ .prettierrc.json    ← you write it
├─ node_modules/       ← npm creates it (ignored by git)
└─ shared/ backend/ frontend/ infra/   (only READMEs for now)
```

1. **The repo** (done: beparadox/guestbook, public). From here on: a branch and a PR per
   milestone. This one can be `git switch -c workspace`.
2. **Root `package.json`.** It isn't an app; it's the manager of the four apps. It needs:
   - `"name": "guestbook"`, `"private": true` (never publish it to npm), `"type": "module"`,
     `"engines": { "node": ">=22" }`
   - `"workspaces": []` for now. **Add each folder to this list in the milestone where you
     give it its own `package.json`** (`frontend` and `infra` in 1, `backend` in 2, `shared`
     in 3). A workspace is a folder with a `package.json`; listing one that doesn't have one yet
     makes `npm run … --workspaces` fail with "No workspaces found".
   - Scripts. For now just `format` (`prettier --write .`), `format:check`
     (`prettier --check .`) and `check` (`npm run format:check`). Each later milestone adds to
     `check`: `typecheck`, `test`, `build` (each one `npm run <x> --workspaces --if-present`)
     and `synth` (`npm run synth -w infra`).

   `appbep: package.json` shows where this ends up.
3. **Prettier as a root dev dependency:** `npm install --save-dev prettier`. That one command
   adds `"devDependencies": { "prettier": "^3…" }` to your `package.json`, creates
   `node_modules/` and `package-lock.json`. "Root" means you run it in the repo root, not inside
   a folder: tools used across the whole repo (Prettier, later gitleaks) live at the root; tools
   one app needs (Vite, CDK, the AWS SDK) go in that app's own `package.json`.
4. **`.prettierrc.json`**: your formatting choices, e.g.
   `{ "singleQuote": true, "printWidth": 100 }` (appbep's: `appbep: .prettierrc.json`). Add a
   `.prettierignore` with `package-lock.json`, `dist`, `cdk.out` if Prettier complains about
   them.
5. **`tsconfig.base.json`**: the TypeScript settings every folder shares, so they're written once:
   `"strict": true`, `"target": "ES2022"`, `"module": "ESNext"`, `"moduleResolution": "Bundler"`,
   `"skipLibCheck": true`, all inside `"compilerOptions"`. Nothing uses it yet; each folder's
   `tsconfig.json` will start with `"extends": "../tsconfig.base.json"`. (TypeScript itself gets
   installed per folder later.)
6. Optional: a secret scan with [gitleaks](https://github.com/gitleaks/gitleaks), like
   `appbep: scripts/scan-secrets.sh`, added to `check`. Worth it in a public repo.

**Check:** `npm run check` passes, and `git status` shows `package.json`, `package-lock.json`,
`tsconfig.base.json` and `.prettierrc.json`, but not `node_modules/`.

**Commit:** "Set up the workspace", push the branch, open a PR, merge.

---

## Milestone 1: a page on the internet

**Goal:** a "Guestbook coming soon" React page at `https://<something>.cloudfront.net`.

### 1a. The React app (`frontend/`)

`npm create vite@latest frontend -- --template react-ts` from the repo root, then delete what
you don't need (the counter, the logos). Make the `name` in `frontend/package.json`
`@guestbook/frontend`, and add `"typecheck": "tsc -b --noEmit"` if the template didn't.
`npm run build -w frontend` must produce `frontend/dist/`. Add `"frontend"` to the root
`workspaces` list, and `typecheck` + `build` to the root `check` script.

### 1b. The CDK app (`infra/`)

Create `infra/package.json` (`"name": "@guestbook/infra"`, scripts `typecheck`, `test`
(`vitest run`), `synth` (`cdk synth --quiet`)), add `"infra"` to the root `workspaces`, and
install from the root with `-w infra`, e.g. `npm install aws-cdk-lib constructs -w infra`.
Dependencies: `aws-cdk-lib`, `constructs`; dev: `aws-cdk`, `tsx`, `typescript`, `vitest`,
`@types/node`. Add `test` and `synth` to the root `check`. Then:

- **`cdk.json`**: `{ "app": "npx tsx bin/guestbook.ts" }`
- **`bin/guestbook.ts`**: `new App()`, then `new GuestbookStack(app, 'Guestbook', { env: { region: 'us-east-1' } })`
- **`lib/guestbook-stack.ts`**: a `Stack` subclass with three constructs:

| Construct | Settings that matter | Read |
| --- | --- | --- |
| `s3.Bucket` | `blockPublicAccess: BLOCK_ALL`, `enforceSSL: true`; for a learning app, `removalPolicy: DESTROY` + `autoDeleteObjects: true` so `cdk destroy` cleans up fully | [S3 module](https://docs.aws.amazon.com/cdk/api/v2/docs/aws-cdk-lib.aws_s3-readme.html) |
| `cloudfront.Distribution` | `defaultRootObject: 'index.html'`; default behavior origin `origins.S3BucketOrigin.withOriginAccessControl(bucket)`, `viewerProtocolPolicy: REDIRECT_TO_HTTPS` | [CloudFront module](https://docs.aws.amazon.com/cdk/api/v2/docs/aws-cdk-lib.aws_cloudfront-readme.html), [Origin Access Control](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-s3.html) |
| `s3deploy.BucketDeployment` | `sources: [Source.asset('../frontend/dist')]`, `destinationBucket`, `distribution` + `distributionPaths: ['/*']` so each deploy clears the CloudFront cache | [S3 deployment module](https://docs.aws.amazon.com/cdk/api/v2/docs/aws-cdk-lib.aws_s3_deployment-readme.html) |

Plus a `CfnOutput` with `https://${distribution.distributionDomainName}`.

Working example: `appbep: infra/lib/site-stack.ts:126` (bucket), `:156` (distribution),
`:206` (deployment), `:243` (outputs). appbep keeps its bucket on `RETAIN` because it's real;
think about why the guestbook can use `DESTROY` and appbep shouldn't.

**Removal policies, the one-paragraph version:** CloudFormation deletes a resource when it
leaves your code (or on `cdk destroy`). For a bucket or table that means the data goes too.
`RETAIN` tells it to leave the resource behind instead. Learn-and-throw-away apps: `DESTROY`.
Anything with data you care about: `RETAIN`.

### 1c. Your first infra test (`infra/test/guestbook-stack.test.ts`)

CDK can render the stack to its CloudFormation template in a test, with no AWS involved.
[`Template.fromStack`](https://docs.aws.amazon.com/cdk/api/v2/docs/aws-cdk-lib.assertions-readme.html)
then lets you assert on it. Write tests that:

- [ ] the bucket blocks all public access
- [ ] there's exactly one CloudFront distribution and it redirects HTTP to HTTPS

`appbep: infra/test/site-stack.test.ts` shows the style. Note: the stack reads
`frontend/dist`, so build the frontend before running infra tests (your `check` order does).

### Deploy

```bash
aws sso login --profile appbep        # if it's expired
npm run build -w frontend
cd infra && npx cdk diff --profile appbep     # read it: what will be created?
npx cdk deploy --profile appbep
```

The appbep account is already bootstrapped for CDK in us-east-1, so no `cdk bootstrap` needed.
The first deploy takes ~5 minutes (CloudFront is slow to create).

**Check:** open the `SiteUrl` output. Then try the bucket directly
(`https://<bucket>.s3.amazonaws.com/index.html`): **Access Denied** is the right answer. Only
CloudFront can read it.

---

## Milestone 2: the backend says hello

**Goal:** `GET /api/health` → `{"ok":true}`, and the page shows "API: ok".

### 2a. The handler (`backend/`)

Create `backend/package.json` (`@guestbook/backend`, scripts `typecheck` and `test`) and add
`"backend"` to the root `workspaces`. Dependencies: dev `@types/aws-lambda`, `typescript`,
`vitest`, `@types/node`.

`backend/src/handler.ts` exports `handler(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2>`.
For now: `GET /api/health` → 200 `{ ok: true }`, anything else → 404 `{ error: 'not_found' }`.
Write a small `json(status, body)` helper that sets `content-type: application/json` and
`JSON.stringify`s the body (`appbep: api/src/handler.ts` has one).

The method and path are in `event.requestContext.http.method` and `event.rawPath`.
Read: [Lambda handlers in TypeScript](https://docs.aws.amazon.com/lambda/latest/dg/typescript-handler.html),
[HTTP API Lambda integration, payload format 2.0](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-develop-integrations-lambda.html).

**Tests first (`handler.test.ts`):** build a fake event object (only the fields you read; cast it)
and assert:

- [ ] `GET /api/health` → 200, body `{"ok":true}`, JSON content type
- [ ] `GET /api/nope` → 404
- [ ] `POST /api/health` → 404 (or 405, your choice; test whichever you pick)

### 2b. Infra

| Construct | Settings that matter | Read |
| --- | --- | --- |
| `lambdaNodejs.NodejsFunction` | `entry: '../backend/src/handler.ts'`, `runtime: NODEJS_22_X`, `bundling: { format: ESM, minify: true, sourceMap: true }`; a `logs.LogGroup` with a retention period (e.g. 2 weeks) passed as `logGroup` (`appbep: infra/lib/site-stack.ts:80`) | [Lambda Node.js module](https://docs.aws.amazon.com/cdk/api/v2/docs/aws-cdk-lib.aws_lambda_nodejs-readme.html) |
| `apigwv2.HttpApi` | `defaultIntegration: new HttpLambdaIntegration('Api', fn)` sends every route to the one Lambda | [API Gateway v2 module](https://docs.aws.amazon.com/cdk/api/v2/docs/aws-cdk-lib.aws_apigatewayv2-readme.html) |
| Distribution `additionalBehaviors['api/*']` | origin `new origins.HttpOrigin(\`${api.apiId}.execute-api.${this.region}.${this.urlSuffix}\`)`, `allowedMethods: ALLOW_ALL`, `cachePolicy: CACHING_DISABLED`, `originRequestPolicy: ALL_VIEWER_EXCEPT_HOST_HEADER` | same CloudFront module |

`NodejsFunction` runs esbuild on your handler: it follows the imports (including, later,
`@guestbook/shared`) and bundles them into one file. That's why `shared/` never needs its own
build step. Working example: `appbep: infra/lib/site-stack.ts:62` (function), `:118` (API),
`:169` (the `api/*` behavior).

**Why `CACHING_DISABLED` and `ALL_VIEWER_EXCEPT_HOST_HEADER`?** An API response must not be
cached and shared between visitors, and the API needs the query string and body passed
through; but API Gateway rejects a `Host` header that names your CloudFront domain.

**Infra tests:**

- [ ] there's a Lambda function on `nodejs22.x`
- [ ] the distribution has a behavior for `api/*` with caching disabled

### 2c. Frontend

In `App.tsx`, `fetch('/api/health')` in a `useEffect` and show "API: ok" or "API: down".
For local dev, add a [Vite proxy](https://vite.dev/config/server-options.html#server-proxy) in
`vite.config.ts` so `/api` goes to your deployed CloudFront URL; then `npm run dev -w frontend`
talks to the real API.

### Deploy and check

`npm run check`, then `cdk deploy`. Open the site: "API: ok". Then
`curl -s https://<your-site>/api/health`. Then find your Lambda's log group in CloudWatch
and see the request you just made (the console's "Live Tail" is fun here).

---

## Milestone 3: the contract

**Goal:** `POST /api/entries` validates its input and echoes a would-be entry. No database yet.

### 3a. `shared/`

Add `"shared"` to the root `workspaces`. `package.json`: `"name": "@guestbook/shared"`, `"type": "module"`,
`"exports": { ".": "./src/index.ts" }`. Pointing `exports` at TypeScript source works because
everything that imports it (Vite, esbuild, Vitest, `tsc` with `moduleResolution: Bundler`)
understands TypeScript. Mathisthenics does the same with `"main"` and `"types"`
(`mathx: shared/package.json`). The alternative, compiling `shared` to `dist/` first, is what a
package published to npm needs, but inside one repo it's just one more build step to forget.

**`entry.ts`**:

```ts
export interface NewEntry { name: string; message: string }          // what the form sends
export interface Entry extends NewEntry { id: string; createdAt: string } // what the API returns
export const LIMITS = { name: 40, message: 500 } as const;
```

**`validate.ts`**: `validateEntry(input: unknown)` returns either
`{ ok: true, value: NewEntry }` (trimmed) or `{ ok: false, errors: { name?: string; message?: string } }`.
Rules: an object; `name` and `message` are strings; after trimming, non-empty and within
`LIMITS`. Unknown extra fields are dropped from `value`, never passed through.

That return type is a **discriminated union**: checking `result.ok` tells TypeScript which
shape you have. Read: [TypeScript narrowing](https://www.typescriptlang.org/docs/handbook/2/narrowing.html).
Compare `mathx: shared/src/api.ts` for a larger contract.

**Tests first (`validate.test.ts`).** A table of cases suits this well
([`it.each`](https://vitest.dev/api/#test-each)):

- [ ] a valid entry comes back trimmed
- [ ] empty / whitespace-only name or message → that field's error
- [ ] exactly the limit passes; one over fails
- [ ] `null`, a string, an array, numbers instead of strings → errors, never a throw
- [ ] extra fields (`{ name, message, admin: true }`) aren't in `value`

### 3b. `backend/` uses it

Add `"@guestbook/shared": "*"` to `backend/package.json` dependencies and `npm install`.
`POST /api/entries`:

1. Read the body. If `event.isBase64Encoded`, decode it first (`appbep: api/src/handler.ts`
   has `bodyText()`).
2. `JSON.parse` inside `try`; failure → 400 `{ error: 'invalid_json' }`.
3. `validateEntry`; failure → 400 `{ error: 'invalid_entry', fields: errors }`.
4. Success → 201 with an `Entry`: `id` from `crypto.randomUUID()`, `createdAt` from
   `new Date().toISOString()`.

**Tests:**

- [ ] valid body → 201, and the response has an `id` and `createdAt`
- [ ] base64-encoded valid body → 201
- [ ] `not json` → 400 `invalid_json`
- [ ] `{}` → 400 `invalid_entry` with both field errors

You'll notice step 4 is hard to test exactly (random id, real clock). Milestone 4 fixes that.

### Deploy and check

```bash
curl -s -X POST https://<site>/api/entries -H 'content-type: application/json' \
  -d '{"name":"bam","message":"first!"}'
curl -s -X POST https://<site>/api/entries -d '{"name":""}'
```

---

## Milestone 4: the database

**Goal:** entries are saved, and `GET /api/entries` returns the latest 20, newest first.

### 4a. Split handler / service / store

Move the logic out of the handler:

- **`store.ts`**: `interface EntryStore { put(entry: Entry): Promise<void>; latest(limit: number): Promise<Entry[]> }`
  and `class MemoryStore implements EntryStore` (an array, sorted on read).
- **`service.ts`**: `signGuestbook(input: unknown, deps)` and `listEntries(deps)`, where
  `deps = { store: EntryStore; now: () => number; newId: () => string }`. They return
  `{ status, body }`; the handler only turns that into an HTTP response.

This is **dependency injection**: the service never reaches for `Date.now()` or DynamoDB
itself, it's handed them, so a test can hand it a fake clock and a `MemoryStore`.
`appbep: api/src/npuzzle/store.ts` and `service.ts` are the same pattern (that's the NPuzzle
work you'll do next, so this is a rehearsal).

**Tests (`service.test.ts`, with `MemoryStore` and a fixed clock):**

- [ ] signing returns 201 with exactly the id and time the fakes produced
- [ ] an invalid entry → 400 and **nothing** is stored
- [ ] listing returns newest first
- [ ] listing returns at most 20, even with 25 stored
- [ ] an empty guestbook → 200 with `[]`

### 4b. DynamoDB

**Key design.** DynamoDB only sorts *within* a partition, by the sort key. To list "newest
first" with one query, put every entry in the same partition and make the sort key sortable
by time:

| Attribute | Value | Why |
| --- | --- | --- |
| `pk` | `"ENTRY"` | one partition holds all entries |
| `sk` | `` `${createdAt}#${id}` `` | ISO-8601 timestamps sort correctly as text; the id breaks ties |
| `name`, `message`, `id`, `createdAt` | the entry | |

`latest(limit)` is one `QueryCommand`: `KeyConditionExpression: 'pk = :pk'`,
`ScanIndexForward: false` (descending), `Limit: limit`. **Not** a `Scan`: a scan reads the
whole table and returns it unordered.

(One partition for everything is fine at guestbook scale; a single partition handles
thousands of writes a second. At real scale you'd shard it, e.g. one partition per month.)

Read: [DynamoDB core components](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/HowItWorks.CoreComponents.html),
[Querying](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Query.html),
[the document client](https://docs.aws.amazon.com/AWSJavaScriptSDK/v3/latest/Package/-aws-sdk-lib-dynamodb/)
(`@aws-sdk/lib-dynamodb`: plain JS objects in and out). A working `UpdateCommand`:
`appbep: api/src/contact/aws.ts`.

**`dynamo-store.ts`**: `class DynamoStore implements EntryStore`, table name from the
constructor. Dependencies: `@aws-sdk/client-dynamodb`, `@aws-sdk/lib-dynamodb`. The Lambda
runtime already includes the SDK; esbuild leaves it out of the bundle.

**Handler wiring:** build the real deps **once, outside** the handler function
(`new DynamoStore(process.env.TABLE_NAME!)`, `Date.now`, `crypto.randomUUID`). Warm Lambda
invocations reuse them, which is faster.

**Infra:**

- `dynamodb.TableV2` with `partitionKey: { name: 'pk', type: STRING }`,
  `sortKey: { name: 'sk', type: STRING }`, on-demand billing (the default), and a removal policy
  you've thought about ([DynamoDB module](https://docs.aws.amazon.com/cdk/api/v2/docs/aws-cdk-lib.aws_dynamodb-readme.html)).
  `appbep: infra/lib/site-stack.ts:53`.
- `environment: { TABLE_NAME: table.tableName }` on the function, and
  `table.grantReadWriteData(fn)`. That one line writes the IAM policy letting this function, and
  only this function, use this table. Look at the generated policy in `cdk diff`: it's the
  least-privilege idea in practice.

**Infra tests:**

- [ ] the table's key schema is `pk` (HASH) + `sk` (RANGE)
- [ ] the function has a `TABLE_NAME` environment variable

**Optional test (`dynamo-store.test.ts`):** the
[`aws-sdk-client-mock`](https://github.com/m-radzikowski/aws-sdk-client-mock) package fakes the
client. Assert that `latest` sends a Query with `ScanIndexForward: false` and the right `Limit`,
and that `put` builds `sk` as `createdAt#id`.

### Deploy and check

Sign it twice with `curl`, then `curl -s https://<site>/api/entries`. Open the table in the
DynamoDB console (**Explore items**) and look at your keys.

---

## Milestone 5: the real UI

**Goal:** a visitor can sign the guestbook and see their entry appear.

- **`api.ts`**: `listEntries(): Promise<Entry[]>` and
  `signGuestbook(entry: NewEntry): Promise<{ ok: true; entry: Entry } | { ok: false; errors }>`.
  Types from `@guestbook/shared` (add it to `frontend/package.json` dependencies).
- **`EntryList.tsx`**: four states, all visible on purpose: loading, error ("couldn't load
  the guestbook"), empty ("be the first to sign!"), loaded. Show the date with
  `toLocaleDateString()`.
- **`SignForm.tsx`**: controlled inputs ([React: reacting to input](https://react.dev/learn/reacting-to-input-with-state)),
  a character counter from `LIMITS`, `validateEntry` before sending (show field errors under
  the inputs), the button disabled while sending, and the server's field errors shown the same
  way. On success: clear the form and put the new entry at the top of the list.
- **Accessibility:** real `<label>`s, errors tied to inputs with `aria-describedby`, the list
  in an element with `aria-live="polite"` so screen readers hear new entries.
- **Security, for free:** render names and messages as `{entry.message}`, never with
  `dangerouslySetInnerHTML`. React escapes text, so `<script>` in a message shows up as text.
  Try it once deployed.

**Tests (`api.test.ts`):** replace `fetch` with `vi.fn()` (or `vi.stubGlobal('fetch', ...)`):

- [ ] `listEntries` calls `GET /api/entries` and returns the array
- [ ] `signGuestbook` sends `POST` with a JSON body and content type
- [ ] a 400 `invalid_entry` comes back as `{ ok: false, errors }`, not a throw
- [ ] a 500 or a network failure throws (so the UI shows its error state)

**Optional component tests:** `@testing-library/react` + `jsdom` + `@testing-library/user-event`:
type into the form, submit, and see the entry in the list. (appbep issue #20 is the same setup.)

### Deploy and check

Sign it from your phone. Try an empty name, a 501-character message and `<b>hi</b>`.

---

## Milestone 6: CI/CD

**Goal:** PRs run `npm run check`; merging to `main` deploys. No AWS keys stored anywhere.

### 6a. The deploy role (you, console, **appbep** account)

GitHub Actions logs in to AWS with **OIDC**: GitHub signs a short-lived token saying "this is
a workflow from repo X on branch Y", and AWS trades it for temporary credentials of one role,
which trusts only that repo and branch.

The appbep account already has the GitHub identity provider (appbep's runbook, step A6). You
only need a **new role**, `guestbook-github-deploy`:

- **Trust policy**: copy `appbep-github-deploy`'s (IAM → Roles → Trust relationships) and
  change the `sub` condition to this repo. appbep's `sub` uses GitHub's immutable-ID format
  (`repo:beparadox@<owner id>/appbep@<repo id>:ref:refs/heads/main`); the guestbook's repo id
  comes from `gh api repos/beparadox/guestbook --jq .id`.
- **Permissions**: the same inline policy as appbep's, allowing `sts:AssumeRole` on the three
  `cdk-hnb659fds-*` roles. CDK's bootstrap roles do the actual deploying; your role only
  needs permission to become them.

Read: [GitHub: configuring OpenID Connect in AWS](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services),
[aws-actions/configure-aws-credentials](https://github.com/aws-actions/configure-aws-credentials).

Then in the repo: **Settings → Secrets and variables → Actions → Variables**: add
`AWS_DEPLOY_ROLE_ARN` (a variable, not a secret; the ARN isn't sensitive, but keep the account
id out of committed files anyway).

### 6b. Workflows (`.github/workflows/`)

- **`ci.yml`**: on `pull_request` and `push` to `main`: checkout, `setup-node` with
  `node-version-file: .nvmrc` and `cache: npm`, `npm ci`, `npm run check`.
- **`deploy.yml`**: on `push` to `main` (or, like appbep, on `workflow_run` after CI succeeds),
  with `permissions: id-token: write, contents: read`, a `concurrency` group so two deploys
  never overlap, then `configure-aws-credentials` with `role-to-assume: ${{ vars.AWS_DEPLOY_ROLE_ARN }}`,
  `npm ci`, build, and `npx cdk deploy --require-approval never`.

Working examples: `appbep: .github/workflows/ci.yml` and `deploy.yml`.

**Check:** open a PR that changes the page's heading. CI runs on the PR; merge it; watch the
Deploy run; reload the site.

---

## Milestone 7 (optional): grown-up extras

Each is a separate small PR:

- **Custom domain** `guestbook.appbep.com`: an ACM certificate in us-east-1 validated by DNS,
  `domainNames` + `certificate` on the distribution, and an alias `ARecord` in the appbep.com
  hosted zone. `appbep: infra/lib/site-stack.ts` (the `props.domain` parts) does all three.
  Pass the zone id as CDK context, never commit it (`appbep: infra/bin/appbep.ts`).
- **Moderation**: entries are saved with `status: 'pending'` and only `approved` ones are
  listed; you approve from a laptop script (like NPuzzle's admin script). Needed before you
  link to the guestbook from anywhere public, because spam bots will find it.
- **Abuse limits**: API Gateway [throttling](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-throttling.html)
  on the stage (e.g. 5 requests/second), and a honeypot field in the form.
- **An alarm**: a CloudWatch alarm on the Lambda's `Errors` metric that emails you.
- **The funhouse**: once it's moderated, a guestbook room in appbep's funhouse that links
  here.

---

## Tearing it down

`cd infra && npx cdk destroy --profile appbep` deletes everything (that's why the bucket and
table use `DESTROY` here). A good last exercise once you're done, followed by a redeploy from
scratch: if `cdk deploy` rebuilds the whole thing from an empty account, your infrastructure
really is code.
