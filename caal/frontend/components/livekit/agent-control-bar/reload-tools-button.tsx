'use client';

import * as React from 'react';
import { ArrowsClockwiseIcon } from '@phosphor-icons/react/dist/ssr';
import { Toggle } from '@/components/livekit/toggle';
import { Tooltip } from '@/components/ui/tooltip';
import { cn } from '@/lib/utils';

/**
 * Button to reload n8n workflow tools without restarting the agent.
 * Posts to /reload-tools webhook.
 */
export function ReloadToolsButton() {
  const [loading, setLoading] = React.useState(false);
  const [success, setSuccess] = React.useState(false);

  const handleReload = async () => {
    if (loading) return;
    setLoading(true);
    setSuccess(false);

    try {
      const res = await fetch('/api/reload-tools', { method: 'POST' });
      if (res.ok) {
        setSuccess(true);
        setTimeout(() => setSuccess(false), 2000);
      }
    } catch (e) {
      console.error('Failed to reload tools:', e);
    } finally {
      setLoading(false);
    }
  };

  return (
    <Tooltip content="Reload tools">
      <Toggle
        size="icon"
        variant="secondary"
        aria-label="Reload tools"
        pressed={false}
        onPressedChange={handleReload}
        disabled={loading}
        className={cn(success && 'text-green-500')}
      >
        <ArrowsClockwiseIcon weight="bold" className={cn(loading && 'animate-spin')} />
      </Toggle>
    </Tooltip>
  );
}
