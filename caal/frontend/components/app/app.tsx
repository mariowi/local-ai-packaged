'use client';

import { useCallback, useEffect, useMemo } from 'react';
import { TokenSource } from 'livekit-client';
import { SessionProvider, StartAudio, useSession } from '@livekit/components-react';
import type { AppConfig } from '@/app-config';
import { AgentAudioRenderer } from '@/components/app/agent-audio-renderer';
import { ViewController } from '@/components/app/view-controller';
import { WakeWordProvider } from '@/components/app/wake-word-provider';
import { Toaster } from '@/components/livekit/toaster';
// import { useAgentErrors } from '@/hooks/useAgentErrors';
import { useDebugMode } from '@/hooks/useDebug';
import { getSandboxTokenSource } from '@/lib/utils';

// Porcupine access key from environment
const PORCUPINE_ACCESS_KEY = process.env.NEXT_PUBLIC_PORCUPINE_ACCESS_KEY ?? '';

const IN_DEVELOPMENT = process.env.NODE_ENV !== 'production';

function AppSetup() {
  useDebugMode({ enabled: IN_DEVELOPMENT });
  // useAgentErrors(); // Disabled for multi-device support - timeout breaks second device

  return null;
}

interface AppProps {
  appConfig: AppConfig;
}

export function App({ appConfig }: AppProps) {
  const tokenSource = useMemo(() => {
    return typeof process.env.NEXT_PUBLIC_CONN_DETAILS_ENDPOINT === 'string'
      ? getSandboxTokenSource(appConfig)
      : TokenSource.endpoint('/api/connection-details');
  }, [appConfig]);

  const session = useSession(
    tokenSource,
    appConfig.agentName ? { agentName: appConfig.agentName } : undefined
  );

  // Clean up session on page unload to prevent orphaned agent jobs
  useEffect(() => {
    const handleUnload = () => {
      session.end();
    };
    window.addEventListener('beforeunload', handleUnload);
    window.addEventListener('pagehide', handleUnload);
    return () => {
      window.removeEventListener('beforeunload', handleUnload);
      window.removeEventListener('pagehide', handleUnload);
    };
  }, [session]);

  // Handle wake word detection - unmute mic and call backend to trigger greeting
  const handleWakeWordDetected = useCallback(async () => {
    console.log('[App] Wake word detected');

    // Unmute microphone
    const micTrack = Array.from(
      session.room?.localParticipant?.audioTrackPublications.values() || []
    ).find((pub) => pub.source === 'microphone')?.track;

    if (micTrack && micTrack.isMuted) {
      console.log('[App] Unmuting microphone');
      await micTrack.unmute();
    }

    // Call backend to trigger greeting
    try {
      const response = await fetch('/api/wake', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ room_name: 'voice_assistant_room' }),
      });
      if (!response.ok) {
        console.error('[App] Wake endpoint failed:', response.status);
      }
    } catch (error) {
      console.error('[App] Wake endpoint error:', error);
    }
  }, [session]);

  return (
    <SessionProvider session={session}>
      <WakeWordProvider
        accessKey={PORCUPINE_ACCESS_KEY}
        keywordPath="/hey_cal.ppn"
        onWakeWordDetected={handleWakeWordDetected}
        defaultEnabled={false}
      >
        <AppSetup />
        <main className="grid h-svh grid-cols-1 place-content-center">
          <ViewController appConfig={appConfig} />
        </main>
        <StartAudio label="Start Audio" />
        <AgentAudioRenderer />
        <Toaster />
      </WakeWordProvider>
    </SessionProvider>
  );
}
