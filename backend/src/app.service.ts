import { Injectable } from '@nestjs/common';
import * as AWS from 'aws-sdk';

@Injectable()
export class AppService {
  getHealth() {
    return { status: 'ok', message: 'FitTrack backend is running' };
  }

  async getFrontendConfig() {
    const region = process.env.AWS_REGION || 'us-east-1';
    AWS.config.update({ region });
    const name = process.env.FRONTEND_CONFIG_SECRET_NAME || '';
    let data: any = null;
    if (name) {
      const sm = new AWS.SecretsManager({ region });
      try {
        const res = await sm.getSecretValue({ SecretId: name }).promise();
        if (res.SecretString) {
          data = JSON.parse(res.SecretString);
        }
      } catch {}
    }
    return {
      region: data?.region || region,
      userPoolId: data?.userPoolId || process.env.COGNITO_USER_POOL_ID || '',
      clientId: data?.clientId || process.env.COGNITO_CLIENT_ID || '',
      identityPoolId: data?.identityPoolId || process.env.COGNITO_IDENTITY_POOL_ID || '',
      s3Bucket: data?.s3Bucket || process.env.S3_BUCKET || '',
      cloudFrontDomain: data?.cloudFrontDomain || process.env.CLOUDFRONT_DOMAIN || '',
      apiEndpoint: data?.apiEndpoint || process.env.API_ENDPOINT || '',
    };
  }
}
