# frontend/

**The React app**, built by Vite into static files (`dist/`) that S3 serves and CloudFront
delivers. Nothing here runs on a server.

Planned files (milestones 1, 2 and 5):

```
frontend/
├─ package.json        created by `npm create vite@latest` (React + TypeScript template)
├─ index.html
├─ vite.config.ts      includes a dev proxy: /api → the deployed API, so `npm run dev` works
└─ src/
   ├─ main.tsx         mounts <App />
   ├─ App.tsx          the page: <SignForm /> and <EntryList />
   ├─ api.ts           listEntries() and signGuestbook(): the only file that calls fetch()
   ├─ api.test.ts
   ├─ SignForm.tsx     the form: controlled inputs, validateEntry() from shared, submit state
   └─ EntryList.tsx    the list: loading, empty, error and loaded states
```

**One rule worth keeping:** components never call `fetch` directly; they call `api.ts`. Then
there's exactly one place that knows the URLs and the response shapes, and it's easy to test.

**Not here:** validation rules (import them from `@guestbook/shared`), anything secret (every
byte here is public once deployed).
