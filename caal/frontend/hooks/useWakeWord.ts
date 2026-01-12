'use client';

import { useEffect, useRef, useState, useCallback } from 'react';
import { PorcupineWorker } from '@picovoice/porcupine-web';
import { WebVoiceProcessor } from '@picovoice/web-voice-processor';

interface UseWakeWordOptions {
  accessKey: string;
  keywordPath: string; // URL to .ppn model file in public/
  modelPath?: string; // URL to .pv model file in public/ (optional, uses default)
  sensitivity?: number;
  onWakeWord: () => void;
  enabled?: boolean;
}

interface UseWakeWordReturn {
  isListening: boolean;
  isReady: boolean;
  error: string | null;
  startListening: () => Promise<void>;
  stopListening: () => Promise<void>;
}

export function useWakeWord({
  accessKey,
  keywordPath,
  modelPath = '/porcupine_params.pv', // Default Porcupine model
  sensitivity = 0.5,
  onWakeWord,
  enabled = true,
}: UseWakeWordOptions): UseWakeWordReturn {
  const [isListening, setIsListening] = useState(false);
  const [isReady, setIsReady] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const porcupineRef = useRef<PorcupineWorker | null>(null);
  const onWakeWordRef = useRef(onWakeWord);

  // Keep callback ref updated
  useEffect(() => {
    onWakeWordRef.current = onWakeWord;
  }, [onWakeWord]);

  // Initialize Porcupine
  useEffect(() => {
    if (!enabled || !accessKey) {
      return;
    }

    let mounted = true;

    async function init() {
      try {
        setError(null);

        // Porcupine v4 API:
        // create(accessKey, keywords, callback, model, options?)
        const porcupine = await PorcupineWorker.create(
          accessKey,
          {
            publicPath: keywordPath,
            label: 'hey_cal',
            sensitivity,
          },
          (detection) => {
            if (detection.index >= 0 && mounted) {
              console.log('[WakeWord] Detected:', detection.label);
              onWakeWordRef.current();
            }
          },
          { publicPath: modelPath }
        );

        if (mounted) {
          porcupineRef.current = porcupine;
          setIsReady(true);
          console.log('[WakeWord] Porcupine initialized');
        } else {
          // Cleanup if unmounted during init
          await porcupine.release();
        }
      } catch (err) {
        console.error('[WakeWord] Init error:', err);
        if (mounted) {
          setError(err instanceof Error ? err.message : 'Failed to initialize wake word');
        }
      }
    }

    init();

    return () => {
      mounted = false;
      if (porcupineRef.current) {
        // Unsubscribe from WebVoiceProcessor before releasing
        WebVoiceProcessor.unsubscribe(porcupineRef.current).catch(() => {});
        porcupineRef.current.release();
        porcupineRef.current = null;
      }
      setIsReady(false);
      setIsListening(false);
    };
  }, [accessKey, keywordPath, modelPath, sensitivity, enabled]);

  const startListening = useCallback(async () => {
    if (!porcupineRef.current || !isReady) {
      console.warn('[WakeWord] Cannot start - not ready');
      return;
    }

    try {
      // Subscribe Porcupine to WebVoiceProcessor to start receiving audio
      await WebVoiceProcessor.subscribe(porcupineRef.current);
      setIsListening(true);
      console.log('[WakeWord] Started listening');
    } catch (err) {
      console.error('[WakeWord] Start error:', err);
      setError(err instanceof Error ? err.message : 'Failed to start listening');
    }
  }, [isReady]);

  const stopListening = useCallback(async () => {
    if (!porcupineRef.current) {
      return;
    }

    try {
      // Unsubscribe from WebVoiceProcessor to stop receiving audio
      await WebVoiceProcessor.unsubscribe(porcupineRef.current);
      setIsListening(false);
      console.log('[WakeWord] Stopped listening');
    } catch (err) {
      console.error('[WakeWord] Stop error:', err);
    }
  }, []);

  return { isListening, isReady, error, startListening, stopListening };
}
