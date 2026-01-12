import { NextResponse } from 'next/server';

// Backend webhook server URL (same as wake endpoint)
const WEBHOOK_URL = process.env.WEBHOOK_URL || 'http://agent:8889';

export async function POST() {
  try {
    const res = await fetch(`${WEBHOOK_URL}/reload-tools`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ room_name: 'voice_assistant_room' }),
    });

    if (!res.ok) {
      const text = await res.text();
      console.error('[/api/reload-tools] Backend error:', res.status, text);
      return NextResponse.json({ error: text || 'Backend error' }, { status: res.status });
    }

    const data = await res.json();
    return NextResponse.json(data);
  } catch (error) {
    console.error('[/api/reload-tools] Error:', error);
    return NextResponse.json(
      { error: error instanceof Error ? error.message : 'Unknown error' },
      { status: 500 }
    );
  }
}
