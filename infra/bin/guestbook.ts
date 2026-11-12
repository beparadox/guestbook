import { App } from 'aws-cdk-lib';
import { GuestbookStack } from '../lib/guestbook-stack';

const app = new App();

new GuestbookStack(app, 'Guestbook', {
  env: {
    region: 'us-east-1',
  },
});
