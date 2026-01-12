'use client';

import { useCallback, useEffect, useState } from 'react';
import { createPortal } from 'react-dom';
import { GearSix, X } from '@phosphor-icons/react/dist/ssr';
import { Button } from '@/components/livekit/button';

interface Settings {
  agent_name: string;
  tts_voice: string;
  prompt: string;
  wake_greetings: string[];
  temperature: number;
  model: string;
  num_ctx: number;
  max_turns: number;
  tool_cache_size: number;
  wake_word_enabled: boolean;
  wake_word_model: string;
  wake_word_threshold: number;
  wake_word_timeout: number;
  // Turn detection (advanced)
  allow_interruptions: boolean;
  min_endpointing_delay: number;
}

interface SettingsModalProps {
  isOpen: boolean;
  onClose: () => void;
}

const DEFAULT_SETTINGS: Settings = {
  agent_name: 'Cal',
  tts_voice: 'am_puck',
  prompt: 'default',
  wake_greetings: ["Hey, what's up?", "What's up?", 'How can I help?'],
  temperature: 0.7,
  model: 'ministral-3:8b',
  num_ctx: 8192,
  max_turns: 20,
  tool_cache_size: 3,
  wake_word_enabled: false,
  wake_word_model: 'models/hey_cal.onnx',
  wake_word_threshold: 0.5,
  wake_word_timeout: 3.0,
  // Turn detection (advanced)
  allow_interruptions: true,
  min_endpointing_delay: 0.5,
};

const DEFAULT_PROMPT = `# Voice Assistant

You are a helpful, conversational voice assistant.
{{CURRENT_DATE_CONTEXT}}

# Tool Priority

Always prefer using tools to answer questions when possible.
`;

export function SettingsModal({ isOpen, onClose }: SettingsModalProps) {
  const [settings, setSettings] = useState<Settings>(DEFAULT_SETTINGS);
  const [promptContent, setPromptContent] = useState('');
  const [, setCustomPromptExists] = useState(false);
  const [voices, setVoices] = useState<string[]>([]);
  const [models, setModels] = useState<string[]>([]);
  const [wakeWordModels, setWakeWordModels] = useState<string[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Load settings on mount
  const loadSettings = useCallback(async () => {
    setLoading(true);
    setError(null);

    try {
      const [settingsRes, voicesRes, modelsRes, wakeWordModelsRes] = await Promise.all([
        fetch('/api/settings'),
        fetch('/api/voices'),
        fetch('/api/models'),
        fetch('/api/wake-word/models'),
      ]);

      if (settingsRes.ok) {
        const data = await settingsRes.json();
        setSettings(data.settings || DEFAULT_SETTINGS);
        setPromptContent(data.prompt_content || DEFAULT_PROMPT);
        setCustomPromptExists(data.custom_prompt_exists || false);
      } else {
        console.warn('Failed to load settings, using defaults');
        setSettings(DEFAULT_SETTINGS);
        setPromptContent(DEFAULT_PROMPT);
      }

      if (voicesRes.ok) {
        const data = await voicesRes.json();
        setVoices(data.voices || []);
      }

      if (modelsRes.ok) {
        const data = await modelsRes.json();
        setModels(data.models || []);
      }

      if (wakeWordModelsRes.ok) {
        const data = await wakeWordModelsRes.json();
        setWakeWordModels(data.models || []);
      }
    } catch (err) {
      console.error('Error loading settings:', err);
      setError('Failed to load settings from server');
      // Still show defaults even when API fails
      setSettings(DEFAULT_SETTINGS);
      setPromptContent(DEFAULT_PROMPT);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    if (isOpen) {
      loadSettings();
    }
  }, [isOpen, loadSettings]);

  const handleSave = async () => {
    setSaving(true);
    setError(null);

    try {
      // Save settings
      const settingsRes = await fetch('/api/settings', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ settings }),
      });

      if (!settingsRes.ok) {
        throw new Error('Failed to save settings');
      }

      // Save prompt if it was edited and prompt is set to custom
      if (settings.prompt === 'custom') {
        const promptRes = await fetch('/api/prompt', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ content: promptContent }),
        });

        if (!promptRes.ok) {
          throw new Error('Failed to save prompt');
        }
      }

      onClose();
    } catch (err) {
      console.error('Error saving settings:', err);
      setError(err instanceof Error ? err.message : 'Failed to save');
    } finally {
      setSaving(false);
    }
  };

  const handlePromptChange = (value: string) => {
    setSettings({ ...settings, prompt: value });
    // If switching to custom and custom doesn't exist, keep current content
  };

  const handleWakeGreetingsChange = (value: string) => {
    const greetings = value.split('\n').filter((g) => g.trim());
    setSettings({ ...settings, wake_greetings: greetings });
  };

  if (!isOpen) return null;

  const isPromptReadOnly = settings.prompt === 'default';

  // Use portal to render modal at document body level (avoids CSS filter stacking context issues)
  return createPortal(
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
      <div className="bg-background border-input dark:border-muted flex max-h-[85vh] w-full max-w-lg flex-col rounded-lg border shadow-xl">
        {/* Header - fixed */}
        <div className="border-input dark:border-muted flex shrink-0 items-center justify-between border-b p-4">
          <div className="flex items-center gap-2">
            <GearSix weight="bold" className="h-5 w-5" />
            <h2 className="text-lg font-semibold">Settings</h2>
          </div>
          <button
            onClick={onClose}
            className="text-muted-foreground hover:text-foreground rounded p-1"
          >
            <X weight="bold" className="h-5 w-5" />
          </button>
        </div>

        {/* Content - scrollable */}
        <div className="flex-1 space-y-4 overflow-y-auto p-4">
          {loading ? (
            <div className="text-muted-foreground py-8 text-center">Loading settings...</div>
          ) : (
            <>
              {error && <div className="rounded-md bg-red-500/10 p-3 text-red-500">{error}</div>}

              {/* Agent Name */}
              <div className="space-y-1">
                <label className="text-sm font-medium">Agent Name</label>
                <input
                  type="text"
                  value={settings.agent_name}
                  onChange={(e) => setSettings({ ...settings, agent_name: e.target.value })}
                  className="border-input bg-background w-full rounded-md border px-3 py-2"
                />
              </div>

              {/* Voice */}
              <div className="space-y-1">
                <label className="text-sm font-medium">Voice</label>
                <select
                  value={settings.tts_voice}
                  onChange={(e) => setSettings({ ...settings, tts_voice: e.target.value })}
                  className="border-input bg-background w-full rounded-md border px-3 py-2"
                >
                  {voices.length > 0 ? (
                    voices.map((voice) => (
                      <option key={voice} value={voice}>
                        {voice}
                      </option>
                    ))
                  ) : (
                    <option value={settings.tts_voice}>{settings.tts_voice}</option>
                  )}
                </select>
              </div>

              {/* Prompt Selection */}
              <div className="space-y-1">
                <label className="text-sm font-medium">Prompt</label>
                <div className="flex gap-2">
                  <button
                    onClick={() => handlePromptChange('default')}
                    className={`rounded-md px-3 py-1.5 text-sm ${
                      settings.prompt === 'default'
                        ? 'bg-primary text-primary-foreground'
                        : 'bg-muted hover:bg-muted/80'
                    }`}
                  >
                    Default
                  </button>
                  <button
                    onClick={() => handlePromptChange('custom')}
                    className={`rounded-md px-3 py-1.5 text-sm ${
                      settings.prompt === 'custom'
                        ? 'bg-primary text-primary-foreground'
                        : 'bg-muted hover:bg-muted/80'
                    }`}
                  >
                    Custom
                  </button>
                </div>
              </div>

              {/* Prompt Content */}
              <div className="space-y-1">
                <label className="text-muted-foreground text-sm">
                  {isPromptReadOnly ? 'Default prompt (read-only)' : 'Custom prompt'}
                </label>
                <textarea
                  value={promptContent}
                  onChange={(e) => setPromptContent(e.target.value)}
                  readOnly={isPromptReadOnly}
                  rows={6}
                  className={`border-input bg-background w-full rounded-md border px-3 py-2 font-mono text-sm ${
                    isPromptReadOnly ? 'cursor-not-allowed opacity-60' : ''
                  }`}
                />
              </div>

              {/* Model */}
              <div className="space-y-1">
                <label className="text-sm font-medium">Model</label>
                <select
                  value={settings.model}
                  onChange={(e) => setSettings({ ...settings, model: e.target.value })}
                  className="border-input bg-background w-full rounded-md border px-3 py-2"
                >
                  {models.length > 0 ? (
                    models.map((model) => (
                      <option key={model} value={model}>
                        {model}
                      </option>
                    ))
                  ) : (
                    <option value={settings.model}>{settings.model}</option>
                  )}
                </select>
              </div>

              {/* Numeric Settings Row */}
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1">
                  <label className="text-sm font-medium">Temperature</label>
                  <input
                    type="number"
                    min="0"
                    max="2"
                    step="0.1"
                    value={settings.temperature}
                    onChange={(e) =>
                      setSettings({ ...settings, temperature: parseFloat(e.target.value) || 0.7 })
                    }
                    className="border-input bg-background w-full rounded-md border px-3 py-2"
                  />
                </div>
                <div className="space-y-1">
                  <label className="text-sm font-medium">Context Size</label>
                  <input
                    type="number"
                    min="1024"
                    max="131072"
                    step="1024"
                    value={settings.num_ctx}
                    onChange={(e) =>
                      setSettings({ ...settings, num_ctx: parseInt(e.target.value) || 8192 })
                    }
                    className="border-input bg-background w-full rounded-md border px-3 py-2"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1">
                  <label className="text-sm font-medium">Max Turns</label>
                  <input
                    type="number"
                    min="1"
                    max="100"
                    value={settings.max_turns}
                    onChange={(e) =>
                      setSettings({ ...settings, max_turns: parseInt(e.target.value) || 20 })
                    }
                    className="border-input bg-background w-full rounded-md border px-3 py-2"
                  />
                </div>
                <div className="space-y-1">
                  <label className="text-sm font-medium">Tool Cache</label>
                  <input
                    type="number"
                    min="0"
                    max="10"
                    value={settings.tool_cache_size}
                    onChange={(e) =>
                      setSettings({ ...settings, tool_cache_size: parseInt(e.target.value) || 3 })
                    }
                    className="border-input bg-background w-full rounded-md border px-3 py-2"
                  />
                </div>
              </div>

              {/* Wake Word Section */}
              <div className="border-input dark:border-muted space-y-3 rounded-md border p-3">
                <div className="flex items-center justify-between">
                  <div>
                    <label className="text-sm font-medium">Server-Side Wake Word</label>
                    <p className="text-muted-foreground text-xs">
                      Activate with wake phrase (requires restart)
                    </p>
                  </div>
                  <button
                    type="button"
                    role="switch"
                    aria-checked={settings.wake_word_enabled}
                    onClick={() =>
                      setSettings({ ...settings, wake_word_enabled: !settings.wake_word_enabled })
                    }
                    className={`relative inline-flex h-6 w-11 shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:ring-2 focus:ring-offset-2 focus:outline-none ${
                      settings.wake_word_enabled ? 'bg-primary' : 'bg-muted'
                    }`}
                  >
                    <span
                      className={`pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out ${
                        settings.wake_word_enabled ? 'translate-x-5' : 'translate-x-0'
                      }`}
                    />
                  </button>
                </div>

                {settings.wake_word_enabled && (
                  <>
                    {/* Wake Word Model Selector */}
                    <div className="space-y-1 pt-2">
                      <label className="text-muted-foreground text-xs">Wake Word Model</label>
                      <select
                        value={settings.wake_word_model}
                        onChange={(e) =>
                          setSettings({ ...settings, wake_word_model: e.target.value })
                        }
                        className="border-input bg-background w-full rounded-md border px-2 py-1 text-sm"
                      >
                        {wakeWordModels.length > 0 ? (
                          wakeWordModels.map((model) => (
                            <option key={model} value={model}>
                              {model
                                .replace('models/', '')
                                .replace('.onnx', '')
                                .replace(/_/g, ' ')
                                .replace(/\b\w/g, (c) => c.toUpperCase())}
                            </option>
                          ))
                        ) : (
                          <option value={settings.wake_word_model}>
                            {settings.wake_word_model
                              .replace('models/', '')
                              .replace('.onnx', '')
                              .replace(/_/g, ' ')
                              .replace(/\b\w/g, (c) => c.toUpperCase())}
                          </option>
                        )}
                      </select>
                    </div>

                    <div className="grid grid-cols-2 gap-3">
                      <div className="space-y-1">
                        <label className="text-muted-foreground text-xs">Detection Threshold</label>
                        <input
                          type="number"
                          min="0.1"
                          max="1.0"
                          step="0.1"
                          value={settings.wake_word_threshold}
                          onChange={(e) =>
                            setSettings({
                              ...settings,
                              wake_word_threshold: parseFloat(e.target.value) || 0.5,
                            })
                          }
                          className="border-input bg-background w-full rounded-md border px-2 py-1 text-sm"
                        />
                      </div>
                      <div className="space-y-1">
                        <label className="text-muted-foreground text-xs">Silence Timeout (s)</label>
                        <input
                          type="number"
                          min="1"
                          max="30"
                          step="0.5"
                          value={settings.wake_word_timeout}
                          onChange={(e) =>
                            setSettings({
                              ...settings,
                              wake_word_timeout: parseFloat(e.target.value) || 3.0,
                            })
                          }
                          className="border-input bg-background w-full rounded-md border px-2 py-1 text-sm"
                        />
                      </div>
                    </div>

                    {/* Wake Greetings */}
                    <div className="space-y-1">
                      <label className="text-muted-foreground text-xs">
                        Wake Greetings (one per line)
                      </label>
                      <textarea
                        value={settings.wake_greetings.join('\n')}
                        onChange={(e) => handleWakeGreetingsChange(e.target.value)}
                        rows={3}
                        className="border-input bg-background w-full rounded-md border px-2 py-1 text-sm"
                      />
                    </div>
                  </>
                )}
              </div>

              {/* Advanced: Turn Detection */}
              <div className="border-input dark:border-muted space-y-3 rounded-md border p-3">
                <div className="flex items-center justify-between">
                  <div>
                    <label className="text-sm font-medium">Advanced: Turn Detection</label>
                    <p className="text-muted-foreground text-xs">
                      Control how the agent detects when you&apos;re done speaking
                    </p>
                  </div>
                </div>

                {/* Allow Interruptions Toggle */}
                <div className="flex items-center justify-between pt-2">
                  <div>
                    <label className="text-muted-foreground text-xs">Allow Interruptions</label>
                    <p className="text-muted-foreground text-xs">
                      Interrupt the agent while speaking
                    </p>
                  </div>
                  <button
                    type="button"
                    role="switch"
                    aria-checked={settings.allow_interruptions}
                    onClick={() =>
                      setSettings({
                        ...settings,
                        allow_interruptions: !settings.allow_interruptions,
                      })
                    }
                    className={`relative inline-flex h-6 w-11 shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:ring-2 focus:ring-offset-2 focus:outline-none ${
                      settings.allow_interruptions ? 'bg-primary' : 'bg-muted'
                    }`}
                  >
                    <span
                      className={`pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out ${
                        settings.allow_interruptions ? 'translate-x-5' : 'translate-x-0'
                      }`}
                    />
                  </button>
                </div>

                {/* Endpointing Delay */}
                <div className="space-y-1">
                  <label className="text-muted-foreground text-xs">
                    Endpointing Delay ({settings.min_endpointing_delay}s)
                  </label>
                  <p className="text-muted-foreground text-xs">
                    Seconds to wait before considering your turn complete
                  </p>
                  <input
                    type="range"
                    min="0.1"
                    max="2.0"
                    step="0.1"
                    value={settings.min_endpointing_delay}
                    onChange={(e) =>
                      setSettings({
                        ...settings,
                        min_endpointing_delay: parseFloat(e.target.value) || 0.5,
                      })
                    }
                    className="w-full accent-[#45997c]"
                  />
                  <div className="text-muted-foreground flex justify-between text-xs">
                    <span>Fast (0.1s)</span>
                    <span>Slow (2.0s)</span>
                  </div>
                </div>
              </div>

              {/* Note about session restart */}
              <p className="text-muted-foreground text-xs">
                Note: Model, context size, prompt, wake word, and turn detection changes take effect
                on next session.
              </p>
            </>
          )}
        </div>

        {/* Footer - fixed */}
        <div className="border-input dark:border-muted flex shrink-0 justify-end gap-2 border-t p-4">
          <Button variant="secondary" onClick={onClose} disabled={saving}>
            Cancel
          </Button>
          <Button variant="primary" onClick={handleSave} disabled={loading || saving}>
            {saving ? 'Saving...' : 'Save'}
          </Button>
        </div>
      </div>
    </div>,
    document.body
  );
}
