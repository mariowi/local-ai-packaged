import { NextResponse } from 'next/server';
import { AccessToken, type AccessTokenOptions, type VideoGrant } from 'livekit-server-sdk';
import { RoomConfiguration } from '@livekit/protocol';

type ConnectionDetails = {
  serverUrl: string;
  roomName: string;
  participantName: string;
  participantToken: string;
};

// NOTE: you are expected to define the following environment variables in `.env.local`:
const API_KEY = process.env.LIVEKIT_API_KEY;
const API_SECRET = process.env.LIVEKIT_API_SECRET;
// Internal URL for token generation (Docker network or localhost)
const LIVEKIT_URL = process.env.LIVEKIT_URL;
// External URL for browser connection (set to 'auto' for dynamic detection)
const LIVEKIT_PUBLIC_URL = process.env.NEXT_PUBLIC_LIVEKIT_URL;

// don't cache the results
export const revalidate = 0;

export async function POST(req: Request) {
  try {
    if (LIVEKIT_URL === undefined) {
      throw new Error('LIVEKIT_URL is not defined');
    }
    if (API_KEY === undefined) {
      throw new Error('LIVEKIT_API_KEY is not defined');
    }
    if (API_SECRET === undefined) {
      throw new Error('LIVEKIT_API_SECRET is not defined');
    }

    // Parse agent configuration from request body
    const body = await req.json();
    const agentName: string = body?.room_config?.agents?.[0]?.agent_name;

    // Generate participant token
    // Fixed room name - all devices share the same room/agent session
    // This prevents orphaned agent jobs from accumulating on reconnect
    const participantName = 'user';
    const participantIdentity = `voice_assistant_user_${Math.floor(Math.random() * 10_000)}`;
    const roomName = 'voice_assistant_room';

    const participantToken = await createParticipantToken(
      { identity: participantIdentity, name: participantName },
      roomName,
      agentName
    );

    // Determine the WebSocket URL for the browser
    // Priority:
    // 1. If NEXT_PUBLIC_LIVEKIT_URL is an explicit wss:// URL, use it directly
    // 2. If HTTPS request and NEXT_PUBLIC_LIVEKIT_URL is set, use it
    // 3. Otherwise, derive ws:// from request hostname
    let serverUrl: string;
    const forwardedProto = req.headers.get('x-forwarded-proto');
    const isHttps = forwardedProto === 'https' || req.url.startsWith('https://');

    if (isHttps && LIVEKIT_PUBLIC_URL) {
      // HTTPS request - use configured secure URL (Tailscale/distributed mode)
      serverUrl = LIVEKIT_PUBLIC_URL;
    } else {
      // HTTP request - derive ws:// from request host for LAN access
      const host = req.headers.get('host') || 'localhost';
      const hostname = host.split(':')[0]; // Remove port if present
      serverUrl = `ws://${hostname}:7880`;
    }

    // Return connection details
    const data: ConnectionDetails = {
      serverUrl,
      roomName,
      participantToken: participantToken,
      participantName,
    };
    const headers = new Headers({
      'Cache-Control': 'no-store',
    });
    return NextResponse.json(data, { headers });
  } catch (error) {
    if (error instanceof Error) {
      console.error(error);
      return new NextResponse(error.message, { status: 500 });
    }
  }
}

function createParticipantToken(
  userInfo: AccessTokenOptions,
  roomName: string,
  agentName?: string
): Promise<string> {
  const at = new AccessToken(API_KEY, API_SECRET, {
    ...userInfo,
    ttl: '15m',
  });
  const grant: VideoGrant = {
    room: roomName,
    roomJoin: true,
    canPublish: true,
    canPublishData: true,
    canSubscribe: true,
  };
  at.addGrant(grant);

  // Always set room config with fast departure timeout for quick reconnect
  // departureTimeout: seconds to keep room open after last participant leaves (default 20s)
  at.roomConfig = new RoomConfiguration({
    departureTimeout: 1, // Close room 1 second after disconnect for fast reconnect
    ...(agentName && { agents: [{ agentName }] }),
  });

  return at.toJwt();
}
