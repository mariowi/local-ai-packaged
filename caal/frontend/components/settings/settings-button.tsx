'use client';

import { useState } from 'react';
import { GearSix } from '@phosphor-icons/react/dist/ssr';
import { Toggle } from '@/components/livekit/toggle';
import { Tooltip } from '@/components/ui/tooltip';
import { SettingsModal } from './settings-modal';

interface SettingsButtonProps {
  size?: 'default' | 'sm' | 'lg' | 'icon';
  variant?: 'default' | 'secondary' | 'outline' | 'primary';
}

export function SettingsButton({ size = 'icon', variant = 'secondary' }: SettingsButtonProps) {
  const [isOpen, setIsOpen] = useState(false);

  return (
    <>
      <Tooltip content="Settings">
        <Toggle
          size={size}
          variant={variant}
          aria-label="Open settings"
          pressed={isOpen}
          onPressedChange={setIsOpen}
        >
          <GearSix weight="bold" />
        </Toggle>
      </Tooltip>
      <SettingsModal isOpen={isOpen} onClose={() => setIsOpen(false)} />
    </>
  );
}
