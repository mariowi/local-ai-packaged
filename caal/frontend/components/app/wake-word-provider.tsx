'use client';

import { type ReactNode, createContext, useCallback, useContext, useEffect, useState } from 'react';
import { useWakeWord } from '@/hooks/useWakeWord';

interface WakeWordContextValue {
  /** Whether wake word mode is enabled */
  isEnabled: boolean;
  /** Toggle wake word mode on/off */
  setEnabled: (enabled: boolean) => void;
  /** Whether currently listening for wake word */
  isListening: boolean;
  /** Whether Porcupine is ready */
  isReady: boolean;
  /** Error message if initialization failed */
  error: string | null;
  /** Manually start listening */
  startListening: () => Promise<void>;
  /** Manually stop listening */
  stopListening: () => Promise<void>;
}

const WakeWordContext = createContext<WakeWordContextValue | null>(null);

interface WakeWordProviderProps {
  children: ReactNode;
  /** Picovoice access key */
  accessKey: string;
  /** Path to .ppn model file in public/ */
  keywordPath: string;
  /** Detection sensitivity (0.0 - 1.0) */
  sensitivity?: number;
  /** Callback when wake word is detected */
  onWakeWordDetected: () => void;
  /** Initial enabled state */
  defaultEnabled?: boolean;
}

export function WakeWordProvider({
  children,
  accessKey,
  keywordPath,
  sensitivity = 0.5,
  onWakeWordDetected,
  defaultEnabled = false, // Default to off - user enables via toggle
}: WakeWordProviderProps) {
  const [isEnabled, setEnabled] = useState(defaultEnabled);

  const handleWakeWord = useCallback(() => {
    if (isEnabled) {
      console.log('[WakeWordProvider] Wake word detected, triggering callback');
      onWakeWordDetected();
    }
  }, [isEnabled, onWakeWordDetected]);

  const { isListening, isReady, error, startListening, stopListening } = useWakeWord({
    accessKey,
    keywordPath,
    sensitivity,
    onWakeWord: handleWakeWord,
    enabled: isEnabled,
  });

  // Auto-start listening when enabled and ready
  useEffect(() => {
    if (isEnabled && isReady && !isListening) {
      startListening();
    }
  }, [isEnabled, isReady, isListening, startListening]);

  // Stop listening when disabled
  useEffect(() => {
    if (!isEnabled && isListening) {
      stopListening();
    }
  }, [isEnabled, isListening, stopListening]);

  const contextValue: WakeWordContextValue = {
    isEnabled,
    setEnabled,
    isListening,
    isReady,
    error,
    startListening,
    stopListening,
  };

  return <WakeWordContext.Provider value={contextValue}>{children}</WakeWordContext.Provider>;
}

export function useWakeWordContext(): WakeWordContextValue {
  const context = useContext(WakeWordContext);
  if (!context) {
    throw new Error('useWakeWordContext must be used within WakeWordProvider');
  }
  return context;
}

/**
 * Safe version that returns null if not within provider.
 * Useful for components that may or may not have wake word enabled.
 */
export function useOptionalWakeWordContext(): WakeWordContextValue | null {
  return useContext(WakeWordContext);
}
