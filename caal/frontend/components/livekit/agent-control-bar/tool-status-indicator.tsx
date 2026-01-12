'use client';

import * as React from 'react';
import { WrenchIcon } from '@phosphor-icons/react/dist/ssr';
import { Tooltip } from '@/components/ui/tooltip';
import { useToolStatus } from '@/hooks/useToolStatus';
import { cn } from '@/lib/utils';

/**
 * Visual indicator showing whether the last agent response used a tool.
 * - Green wrench + tool name: Tool was called (grounded response)
 * - Red wrench: No tool called (generated from model weights)
 * - Gray wrench: No status yet
 *
 * Click to see tool parameters in a popup.
 */
export function ToolStatusIndicator() {
  const toolStatus = useToolStatus();
  const [popupOpen, setPopupOpen] = React.useState(false);
  const containerRef = React.useRef<HTMLDivElement>(null);

  // Close popup when clicking outside
  React.useEffect(() => {
    if (!popupOpen) return;

    const handleClickOutside = (e: MouseEvent) => {
      if (containerRef.current && !containerRef.current.contains(e.target as Node)) {
        setPopupOpen(false);
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, [popupOpen]);

  // Determine status and styling
  const hasStatus = toolStatus !== null;
  const toolUsed = toolStatus?.toolUsed ?? false;
  const toolNames = toolStatus?.toolNames ?? [];
  const toolParams = toolStatus?.toolParams ?? [];

  // Get display name (last tool used, formatted nicely)
  const displayName =
    toolNames.length > 0 ? toolNames[toolNames.length - 1].replace(/_/g, ' ') : null;

  const handleClick = () => {
    if (hasStatus && toolUsed && toolParams.length > 0) {
      setPopupOpen(!popupOpen);
    }
  };

  // Tooltip content based on status
  const tooltipContent = !hasStatus
    ? 'Tool status'
    : toolUsed
      ? `Tool: ${toolNames.join(', ')}`
      : 'No tool used';

  return (
    <div ref={containerRef} className="relative flex items-center gap-1.5">
      {/* Wrench icon button */}
      <Tooltip content={tooltipContent}>
        <button
          type="button"
          onClick={handleClick}
          className={cn(
            'flex h-10 w-10 items-center justify-center rounded-full',
            'bg-secondary/50 transition-colors duration-200',
            hasStatus && toolUsed && 'cursor-pointer bg-green-500/10 hover:bg-green-500/20',
            !hasStatus && 'cursor-default'
          )}
          aria-label={
            !hasStatus
              ? 'Tool status: waiting for response'
              : toolUsed
                ? `Tool used: ${toolNames.join(', ')}. Click for details.`
                : 'No tool called - response generated from model'
          }
        >
          <WrenchIcon
            weight="bold"
            className={cn(
              'h-5 w-5 transition-colors duration-200',
              'text-muted-foreground/50',
              hasStatus && toolUsed && 'text-green-500'
            )}
          />
        </button>
      </Tooltip>

      {/* Tool name label - only shown when a tool was actually used */}
      {hasStatus && toolUsed && displayName && (
        <span className="max-w-48 truncate text-xs font-medium text-green-500/80">
          {displayName}
        </span>
      )}

      {/* Popup with tool params */}
      {popupOpen && toolParams.length > 0 && (
        <div className="absolute bottom-full left-0 z-50 mb-2">
          <div className="border-border bg-popover max-w-72 min-w-48 rounded-lg border p-3 shadow-lg">
            <div className="text-muted-foreground mb-2 text-xs font-semibold">Tool Parameters</div>
            {toolNames.map((name, i) => (
              <div key={i} className="mb-2 last:mb-0">
                <div className="text-foreground mb-1 text-sm font-medium">{name}</div>
                <pre className="text-muted-foreground bg-muted/50 max-h-32 overflow-x-auto overflow-y-auto rounded p-2 text-xs">
                  {JSON.stringify(toolParams[i] ?? {}, null, 2)}
                </pre>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
