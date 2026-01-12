'use client';

import * as React from 'react';
import { EarIcon, EarSlashIcon, SpinnerIcon } from '@phosphor-icons/react/dist/ssr';
import { useOptionalWakeWordContext } from '@/components/app/wake-word-provider';
import { Toggle } from '@/components/livekit/toggle';
import { cn } from '@/lib/utils';

export type WakeWordToggleProps = React.ComponentProps<typeof Toggle>;

/**
 * Toggle button for enabling/disabling wake word detection.
 * Shows an ear icon when enabled (listening for "Hey Cal").
 * Returns null if wake word provider is not available.
 */
export function WakeWordToggle({ className, ...props }: WakeWordToggleProps) {
  const wakeWord = useOptionalWakeWordContext();

  // Don't render if wake word is not configured
  if (!wakeWord) {
    return null;
  }

  const { isEnabled, setEnabled, isListening, isReady, error } = wakeWord;

  // Show spinner while initializing
  const isPending = isEnabled && !isReady && !error;

  const IconComponent = isPending ? SpinnerIcon : isEnabled ? EarIcon : EarSlashIcon;

  const title = error
    ? `Wake word error: ${error}`
    : isEnabled
      ? isListening
        ? 'Wake word active - say "Hey Cal"'
        : 'Wake word initializing...'
      : 'Wake word disabled - click to enable';

  // Show error alert on mobile (no tooltip access)
  const handlePress = (pressed: boolean) => {
    if (error && pressed) {
      alert(`Wake word error:\n${error}`);
      return;
    }
    setEnabled(pressed);
  };

  return (
    <Toggle
      pressed={isEnabled}
      onPressedChange={handlePress}
      aria-label="Toggle wake word detection"
      title={title}
      className={cn(
        // Highlight when actively listening
        isListening && 'ring-2 ring-green-500/50',
        // Red ring when there's an error
        error && 'ring-2 ring-red-500/50',
        className
      )}
      {...props}
    >
      <IconComponent
        weight="bold"
        className={cn(
          isPending && 'animate-spin',
          isListening && 'text-green-500',
          error && 'text-red-500'
        )}
      />
    </Toggle>
  );
}
