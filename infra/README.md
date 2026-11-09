# infra/

**AWS CDK: code that describes the AWS resources.** Running `cdk deploy` turns it into a
CloudFormation stack named `Guestbook` in the appbep account (us-east-1).

Planned files (milestones 1, 2, 4 and 6):

```
infra/
├─ package.json
├─ tsconfig.json
├─ cdk.json            tells the CDK CLI how to run bin/guestbook.ts
├─ bin/
│  └─ guestbook.ts     the app: creates one GuestbookStack
├─ lib/
│  └─ guestbook-stack.ts   bucket, CloudFront, Lambda, HTTP API, DynamoDB table, outputs
└─ test/
   └─ guestbook-stack.test.ts   assertions on the generated template
```

**What it creates, by the end:**

| Resource                | Milestone | Why                                                          |
| ----------------------- | --------- | ------------------------------------------------------------ |
| S3 bucket               | 1         | Holds the built React app. Private: only CloudFront reads it |
| CloudFront distribution | 1         | HTTPS, caching, and one address for both page and API        |
| Bucket deployment       | 1         | Uploads `frontend/dist` on every deploy                      |
| Lambda function         | 2         | Runs `backend/src/handler.ts`, bundled by esbuild            |
| HTTP API (API Gateway)  | 2         | Turns HTTPS requests into Lambda calls                       |
| `/api/*` behavior       | 2         | CloudFront sends API paths to the HTTP API, uncached         |
| DynamoDB table          | 4         | Stores the entries                                           |
| GitHub deploy role      | 6         | Lets GitHub Actions deploy without stored keys (OIDC)        |

**Not here:** the code the Lambda runs (that's `backend/`).
