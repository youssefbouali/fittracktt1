import { SecretsManagerClient, GetSecretValueCommand } from '@aws-sdk/client-secrets-manager';
import { CognitoIdentityClient } from '@aws-sdk/client-cognito-identity';
import { fromCognitoIdentityPool } from '@aws-sdk/credential-provider-cognito-identity';
import { awsConfig } from '../config/aws';
import { AuthService } from './authService';

let secretsClient: SecretsManagerClient | null = null;

export const initializeSecrets = (idToken?: string) => {
  if (!awsConfig.identityPoolId) {
    console.error('Identity Pool ID is not configured');
    return;
  }

  if (!idToken) {
    console.error('Cognito idToken is required to initialize SecretsManager for authenticated identity');
    return;
  }

  const credentialProvider = fromCognitoIdentityPool({
    client: new CognitoIdentityClient({ region: awsConfig.region }),
    identityPoolId: awsConfig.identityPoolId,
    logins: {
      [`cognito-idp.${awsConfig.region}.amazonaws.com/${awsConfig.userPoolId}`]: idToken,
    },
  });

  secretsClient = new SecretsManagerClient({
    region: awsConfig.region,
    credentials: credentialProvider,
  });
};

const getSecretsClient = async (): Promise<SecretsManagerClient> => {
  if (!secretsClient) {
    const idToken = await AuthService.getIdToken();
    if (!idToken) {
      throw new Error('NotAuthorizedException: Authenticated Cognito idToken required for SecretsManager');
    }
    initializeSecrets(idToken);
  }
  return secretsClient as SecretsManagerClient;
};

export const SecretsService = {
  async getSecretJson(secretName: string): Promise<any> {
    const client = await getSecretsClient();
    const resp = await client.send(new GetSecretValueCommand({ SecretId: secretName }));
    const str = resp.SecretString || '{}';
    return JSON.parse(str);
  },
};
