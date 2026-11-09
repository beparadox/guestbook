# shared/

**The contract between the browser and the server.** Code here runs in both places, so it
must not use anything browser-only (`window`, `document`) or server-only (`fs`, the AWS SDK).

Planned files (you create them in milestone 3):

```
shared/
├─ package.json        name "@guestbook/shared"; points "exports" at src/index.ts
├─ tsconfig.json
└─ src/
   ├─ index.ts         re-exports everything below
   ├─ entry.ts         types: NewEntry (what the form sends), Entry (what the API returns)
   ├─ validate.ts      validateEntry(input: unknown) → { ok: true, value } | { ok: false, errors }
   └─ validate.test.ts
```

**Why it exists:** the form and the Lambda check input with the _same_ function, so they can
never disagree about what a valid entry is. The browser check is for the visitor's convenience;
the Lambda check is the one that counts, because anyone can call the API without the form.

**Not here:** HTTP handling, React components, database code.
