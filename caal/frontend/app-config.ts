export interface AppConfig {
  pageTitle: string;
  pageDescription: string;
  companyName: string;

  supportsChatInput: boolean;
  supportsVideoInput: boolean;
  supportsScreenShare: boolean;
  isPreConnectBufferEnabled: boolean;

  logo: string;
  startButtonText: string;
  accent?: string;
  logoDark?: string;
  accentDark?: string;

  // for LiveKit Cloud Sandbox
  sandboxId?: string;
  agentName?: string;
}

export const APP_CONFIG_DEFAULTS: AppConfig = {
  companyName: 'CAAL',
  pageTitle: 'CAAL Voice Assistant',
  pageDescription: 'A local voice assistant with Home Assistant and n8n integrations',

  supportsChatInput: true,
  supportsVideoInput: false,
  supportsScreenShare: false,
  isPreConnectBufferEnabled: true,

  logo: '/cwl-logo-round.png',
  accent: '#45997c',
  logoDark: '/cwl-logo-round.png',
  accentDark: '#45997c',
  startButtonText: 'Talk to CAAL',

  // for LiveKit Cloud Sandbox
  sandboxId: undefined,
  agentName: undefined,
};
