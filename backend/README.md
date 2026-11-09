# backend/

**The code that runs inside AWS Lambda.** No CDK here: this folder never describes AWS
resources, it only runs on them.

Planned files (milestones 2-4):

```
backend/
├─ package.json            name "@guestbook/backend"; depends on @guestbook/shared
├─ tsconfig.json
└─ src/
   ├─ handler.ts           HTTP in, HTTP out: route the request, parse the body, call the
   │                       service, turn its result into a response. The only file that knows
   │                       about API Gateway events.
   ├─ handler.test.ts
   ├─ service.ts           The rules: validate, stamp id + time, save, list. Takes its
   │                       dependencies (store, clock, id maker) as an argument, so tests can
   │                       pass fakes.
   ├─ service.test.ts
   ├─ store.ts             The EntryStore interface + MemoryStore (for tests)
   ├─ dynamo-store.ts      DynamoStore: the real EntryStore, using DynamoDB
   └─ dynamo-store.test.ts (optional, with a mocked AWS client)
```

**The three layers** (handler → service → store) are the same split appbep uses for the
NPuzzle leaderboard. Each one can be tested without the one below it being real.

**Not here:** CDK code (that's `infra/`), validation rules (those are in `shared/`).
