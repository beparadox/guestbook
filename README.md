# Guestbook

The smallest app that still has every part of a real serverless web app: a React page with a
form, an API, a Lambda function, a database, hosting and a deploy pipeline. It's the "kernel"
that [appbep](https://github.com/beparadox/appbep) and Mathisthenics are built around, small
enough to see the whole thing at once.

Visitors sign the guestbook (name + message) and see the latest entries, newest first.

```
 browser ── https://<id>.cloudfront.net ──▶ CloudFront
                                             ├─ /*       ─▶ S3 bucket   (the React app: frontend/)
                                             └─ /api/*   ─▶ API Gateway ─▶ Lambda ─▶ DynamoDB
                                                                          (backend/)
 shared/  types + validation used by BOTH the React app and the Lambda
 infra/   CDK code that creates everything above in AWS
```

## Layout

| Folder      | What lives here                                           | Runs where                    |
| ----------- | --------------------------------------------------------- | ----------------------------- |
| `shared/`   | The contract: request/response types, `validateEntry()`   | In the browser **and** Lambda |
| `backend/`  | The Lambda: handler (HTTP), service (rules), store (data) | AWS Lambda                    |
| `frontend/` | Vite + React: the form and the list                       | The visitor's browser         |
| `infra/`    | AWS CDK: which resources exist and how they're wired      | Your laptop / CI, at deploy   |
| `docs/`     | [The tutorial](docs/TUTORIAL.md)                          | You                           |

Each folder has a README saying what belongs in it and what doesn't.

## Status

Built step by step from [docs/TUTORIAL.md](docs/TUTORIAL.md). Each milestone ends deployed.

- [ ] 0. Repo and workspace
- [ ] 1. A page on the internet (S3 + CloudFront)
- [ ] 2. The backend says hello (Lambda + API Gateway + `/api/*` route)
- [ ] 3. The contract (`shared/` + validation, POST echoes)
- [ ] 4. The database (DynamoDB: save and list)
- [ ] 5. The real UI (form, list, loading and error states)
- [ ] 6. CI/CD (GitHub Actions + OIDC)
- [ ] 7. Optional: custom domain, moderation, alarms
