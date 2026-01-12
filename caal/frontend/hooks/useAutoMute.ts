'use client';

import { useEffect, useRef } from 'react';
import type { AgentState } from '@livekit/components-react';

interface MicToggle {
  toggle: (enabled?: boolean, ...args: any[]) => Promise<any>;
  enabled: boolean;
}

interface UseAutoMuteOptions {
  agentState: AgentState;
  micToggle: MicToggle;
  enabled: boolean;
  skip?: boolean; // Skip the next auto-mute (e.g., after wake word greeting)
  delay?: number; // Delay in milliseconds before auto-muting (default: 0)
  onMuted?: () => void;
}

/**
 * Auto-mutes the microphone after the agent finishes speaking.
 * Used with wake word mode to return to listening state after each interaction.
 */
export function useAutoMute({
  agentState,
  micToggle,
  enabled,
  skip = false,
  delay = 0,
  onMuted,
}: UseAutoMuteOptions) {
  const wasActiveRef = useRef(false);
  const onMutedRef = useRef(onMuted);
  const muteTimerRef = useRef<NodeJS.Timeout | null>(null);

  // Keep callback ref updated
  useEffect(() => {
    onMutedRef.current = onMuted;
  }, [onMuted]);

  useEffect(() => {
    if (!enabled) {
      wasActiveRef.current = false;
      // Clear any pending mute timer
      if (muteTimerRef.current) {
        clearTimeout(muteTimerRef.current);
        muteTimerRef.current = null;
      }
      return;
    }

    // Track when agent becomes active (speaking or thinking)
    if (agentState === 'speaking' || agentState === 'thinking') {
      wasActiveRef.current = true;
      // Cancel pending mute if user starts speaking during delay
      if (muteTimerRef.current && agentState === 'thinking') {
        console.log('[AutoMute] User spoke during delay, canceling auto-mute');
        clearTimeout(muteTimerRef.current);
        muteTimerRef.current = null;
      }
    }

    // When agent returns to listening after being active, mute mic (with optional delay)
    // Skip if the skip flag is set (e.g., after wake word greeting)
    if (agentState === 'listening' && wasActiveRef.current && micToggle.enabled && !skip) {
      wasActiveRef.current = false;

      // Clear any existing timer
      if (muteTimerRef.current) {
        clearTimeout(muteTimerRef.current);
      }

      if (delay > 0) {
        console.log(`[AutoMute] Agent finished, will mute mic in ${delay}ms`);
        muteTimerRef.current = setTimeout(() => {
          // Timer completed - user didn't speak during delay, so mute
          // (If user spoke, timer would have been canceled in the thinking state handler)
          console.log('[AutoMute] Delay elapsed, muting mic');
          micToggle.toggle(false).then(() => {
            onMutedRef.current?.();
          });
          muteTimerRef.current = null;
        }, delay);
      } else {
        console.log('[AutoMute] Agent finished, muting mic');
        micToggle.toggle(false).then(() => {
          onMutedRef.current?.();
        });
      }
    } else if (skip && agentState === 'listening' && wasActiveRef.current) {
      // Skip this auto-mute but reset the wasActive flag
      console.log('[AutoMute] Skipping auto-mute (wake word greeting)');
      wasActiveRef.current = false;
    }
  }, [agentState, enabled, micToggle, skip, delay]);

  // Cleanup timer only on unmount
  useEffect(() => {
    return () => {
      if (muteTimerRef.current) {
        clearTimeout(muteTimerRef.current);
        muteTimerRef.current = null;
      }
    };
  }, []);
}
