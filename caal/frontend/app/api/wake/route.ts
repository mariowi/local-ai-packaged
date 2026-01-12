import { NextResponse } from 'next/server';

// Backend webhook server URL
const WEBHOOK_URL = process.env.WEBHOOK_URL || 'http://agent:8889';

export const revalidate = 0;

export async function POST(req: Request) {
  try {
    const body = await req.json();
    const roomName = body?.room_name || 'voice_assistant_room';

    // Proxy request to backend webhook server
    const response = await fetch(`${WEBHOOK_URL}/wake`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ room_name: roomName }),
    });

    if (!response.ok) {
      const text = await response.text();
      console.error('[/api/wake] Backend error:', response.status, text);
      return NextResponse.json({ error: text || 'Backend error' }, { status: response.status });
    }

    const data = await response.json();
    return NextResponse.json(data);
  } catch (error) {
    console.error('[/api/wake] Error:', error);
    return NextResponse.json(
      { error: error instanceof Error ? error.message : 'Unknown error' },
      { status: 500 }
    );
  }
}
