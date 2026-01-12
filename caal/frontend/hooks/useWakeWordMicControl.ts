'use client';

import { useEffect, useRef } from 'react';
import { useVoiceAssistant } from '@livekit/components-react';
import { useOptionalWakeWordContext } from '@/components/app/wake-word-provider';
import { useAutoMute } from './useAutoMute';

interface MicToggle {
  toggle: (enabled?: boolean, ...args: any[]) => Promise<any>;
  enabled: boolean;
}

interface UseWakeWordMicControlOptions {
  micToggle: MicToggle;
}

/**
 * Integrates wake word detection with microphone control.
 *
 * Flow:
 * 1. Wake word mode enabled → mute mic (listen for "Hey Cal")
 * 2. "Hey Cal" detected → app.tsx unmutes mic directly
 * 3. User speaks → agent responds
 * 4. Agent finishes responding → auto-mute mic (back to wake word listening)
 */
export function useWakeWordMicControl({ micToggle }: UseWakeWordMicControlOptions) {
  const wakeWord = useOptionalWakeWordContext();
  const { state: agentState } = useVoiceAssistant();
  const hasUserSpokenRef = useRef(false);

  // Mute mic when wake word mode is first enabled (but not when unmuting during conversation)
  useEffect(() => {
    if (!wakeWord) return;

    // Only mute when wake word mode becomes enabled AND ready
    // Don't re-mute every time mic state changes (that would fight the unmute)
    if (wakeWord.isEnabled && wakeWord.isReady && micToggle.enabled) {
      console.log('[WakeWordMicControl] Wake word enabled, muting mic');
      micToggle.toggle(false);
    }
  }, [wakeWord?.isEnabled, wakeWord?.isReady]); // Don't watch micToggle to avoid re-muting after unmute

  // Track when user speaks (agent enters thinking state)
  useEffect(() => {
    // When mic is unmuted and agent starts thinking, user has spoken
    if (micToggle.enabled && agentState === 'thinking') {
      console.log('[WakeWordMicControl] User spoke');
      hasUserSpokenRef.current = true;
    }

    // Reset flag when mic is muted (new wake word cycle)
    if (!micToggle.enabled) {
      hasUserSpokenRef.current = false;
    }
  }, [agentState, micToggle.enabled]);

  // Auto-mute after agent finishes speaking - but only if user has spoken
  // Add 4 second delay to allow follow-up questions without re-triggering wake word
  useAutoMute({
    agentState,
    micToggle,
    enabled: wakeWord?.isEnabled ?? false,
    skip: !hasUserSpokenRef.current, // Skip if user hasn't spoken yet
    delay: 4000, // 4 second delay before auto-mute
    onMuted: () => {
      console.log('[WakeWordMicControl] Agent finished, resuming wake word listening');
      hasUserSpokenRef.current = false; // Reset for next cycle
    },
  });
}
