import { useEffect, useRef } from 'react';
import { useAgent, useSessionContext } from '@livekit/components-react';
import { toastAlert } from '@/components/livekit/alert-toast';

export function useAgentErrors() {
  const agent = useAgent();
  const { isConnected, end } = useSessionContext();
  // Track if we've seen the agent in a valid state (for multi-device support)
  const hasSeenValidState = useRef(false);

  // Mark as valid if agent is already in a working state
  useEffect(() => {
    if (agent.state === 'listening' || agent.state === 'thinking' || agent.state === 'speaking') {
      hasSeenValidState.current = true;
    }
  }, [agent.state]);

  useEffect(() => {
    // Only show error if we never saw the agent in a valid state
    // This handles multi-device where joining an existing room with active agent
    // would otherwise timeout waiting for state transitions
    if (isConnected && agent.state === 'failed' && !hasSeenValidState.current) {
      const reasons = agent.failureReasons;

      toastAlert({
        title: 'Session ended',
        description: (
          <>
            {reasons.length > 1 && (
              <ul className="list-inside list-disc">
                {reasons.map((reason) => (
                  <li key={reason}>{reason}</li>
                ))}
              </ul>
            )}
            {reasons.length === 1 && <p className="w-full">{reasons[0]}</p>}
            <p className="w-full">
              <a
                target="_blank"
                rel="noopener noreferrer"
                href="https://docs.livekit.io/agents/start/voice-ai/"
                className="whitespace-nowrap underline"
              >
                See quickstart guide
              </a>
              .
            </p>
          </>
        ),
      });

      end();
    }
  }, [agent, isConnected, end]);
}
