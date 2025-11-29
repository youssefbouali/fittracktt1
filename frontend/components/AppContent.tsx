import { useEffect, useState } from 'react';
import { awsConfig, validateAwsConfig } from '../config/aws';
import { AuthService, initializeCognito } from '../services/authService';
import { api } from '../lib/api';
import { SecretsService, initializeSecrets } from '../services/secretsService';

export default function AppContent({ Component, pageProps }: any) {
  const [ready, setReady] = useState(false);

  useEffect(() => {
    if (typeof window === 'undefined') return;

    (async () => {
      if (!validateAwsConfig()) {
        console.error('AWS config is incomplete. Services not initialized.');
        return;
      }

      initializeCognito();

      // Optionally load extra config from Secrets Manager after sign-in
      const secretName = (process as any).env?.NEXT_PUBLIC_FRONTEND_CONFIG_SECRET_NAME || '';
      try {
        const idToken = await AuthService.getIdToken();
        if (idToken && secretName) {
          initializeSecrets(idToken);
          const remote = await SecretsService.getSecretJson(secretName);
          Object.assign(awsConfig, remote || {});
        }
      } catch {}

      setReady(true);

      AuthService.getCurrentUser()
        .then(user => user && console.log('User logged in:', user))
        .catch(console.error);
    })();
  }, []);

  if (!ready) return null;
  return <Component {...pageProps} />;
}
