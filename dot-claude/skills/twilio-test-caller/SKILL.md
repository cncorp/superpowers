---
name: twilio-test-caller
description: Place test voice calls via Twilio. Use when testing voice features or debugging voice pipeline. Only works if twilio_place_call.py exists in branch.
dependencies:
  - tailscale-manager
allowed-tools:
  - Bash
  - Read
  - Glob
---

# Twilio Test Caller

Place test voice calls to validate voice conversation features end-to-end.

## How It Works (Simple Version)

1. **Script calls Twilio API** → Twilio places call FROM +18643997362 TO +16503977712
2. **Twilio hits webhook** → +16503977712 is configured with webhook URL in Twilio console
3. **Tailscale forwards** → Public HTTPS request → localhost:8084
4. **Docker API receives** → FastAPI processes webhook, returns TwiML with WebSocket URL
5. **Audio streams** → VAD + OpenAI Realtime process speech
6. **You see logs** → `docker logs ct4-api-1` shows "Received Twilio voice webhook call_sid=CA..."

**If you DON'T see logs in step 6 → something in the pipeline is broken.**

**For detailed pipeline flow with all 12 steps, see the `run-voice-e2e` skill which includes a complete diagnostic table.**

## When to Use

- User asks to place/test a call
- Testing voice pipeline (transcription, enrichment, interventions)
- Debugging voice call handling
- Verifying voice webhooks work

## Prerequisites

**⚠️ DEPENDENCY: This skill requires the tailscale-manager skill**

Before placing calls, verify:
1. ✅ `twilio_place_call.py` exists
2. ✅ Docker is running
3. ✅ **Tailscale funnel is active** (managed by tailscale-manager skill)
4. ✅ **Twilio number webhook points to Tailscale URL** (CRITICAL!)
5. ✅ Environment variables set

## Setup Workflow

### 1. Check Script Exists
```bash
find . -maxdepth 4 -name "twilio_place_call.py" -type f 2>/dev/null
```
If not found, this branch doesn't have voice features.

### 2. Verify Docker Running
```bash
docker compose ps  # All services should be "Up"
docker compose up -d  # If any are down
```

### 3. Check Tailscale Funnel

**Use the tailscale-manager skill to verify and manage the funnel:**

```bash
sudo tailscale funnel status
```

Expected output when running:
```
https://wakeup.tail<hash>.ts.net (Funnel on)
|-- / proxy http://127.0.0.1:8082
```

**If funnel is not running, use the tailscale-manager skill workflow:**
1. Check current status: `sudo tailscale funnel status`
2. Stop any existing funnel: `sudo tailscale funnel --https=443 off`
3. Start funnel for your ct project: `sudo tailscale funnel --https=443 8082`
4. Verify it started: `sudo tailscale funnel status`

See `.claude/skills/tailscale-manager/SKILL.md` for full funnel management workflow.

### 4. Verify Twilio Webhook (CRITICAL!)

Check webhook configuration:
```bash
docker compose exec api bash -lc 'set -a && source /app/.env && set +a && python -c "
from twilio.rest import Client
import os
client = Client(os.environ[\"TWILIO_ACCOUNT_SID\"], os.environ[\"TWILIO_AUTH_TOKEN\"])
numbers = client.incoming_phone_numbers.list(phone_number=\"+16503977712\")
for number in numbers:
    print(f\"Voice URL: {number.voice_url}\")"'
```

Expected: `https://YOUR-MACHINE.tailXXXXXX.ts.net/webhook/voice/twilio`

If wrong, update webhook:
```bash
docker compose exec api bash -lc 'set -a && source /app/.env && set +a && python -c "
from twilio.rest import Client
import os
client = Client(os.environ[\"TWILIO_ACCOUNT_SID\"], os.environ[\"TWILIO_AUTH_TOKEN\"])
numbers = client.incoming_phone_numbers.list(phone_number=\"+16503977712\")
for number in numbers:
    number.update(voice_url=\"https://YOUR-MACHINE.tailXXXXXX.ts.net/webhook/voice/twilio\", voice_method=\"POST\")
    print(f\"Updated {number.phone_number}\")"'
```

## Place a Call (It's Simple)

**Basic command - just place the call:**
```bash
cd api && set -a && source .env && set +a && \
PYTHONPATH=src uv run python src/scripts/twilio_place_call.py \
  --to +16503977712 \
  --duration-minutes 1 \
  --audio-url https://github.com/srosro/personal-public/raw/refs/heads/main/lib3_mulaw.wav
```

**That's it. If everything is configured correctly, you'll see logs in `docker logs ct4-api-1`.**

**Parameters:**
- `--to` - Phone number to call (default: +16503977712 - Jake's test number)
- `--from` - Calling from (default: +18643997362 - Abby's number)
- `--duration-minutes` - How long to keep call active (default: 1 minute)
- `--audio-url` - Test audio to play (MUST be .wav mulaw format for best results)

**Audio URL Requirements:**
- ✅ Use mulaw format: `lib3_mulaw.wav`
- ❌ NOT static format: `lib3_converted.wav` (will sound like static)
- 🔗 Recommended URL: `https://github.com/srosro/personal-public/raw/refs/heads/main/lib3_mulaw.wav`

**Verify Interventions After Call:**
After placing a call, verify that interventions were created by visiting the frontend:
```
http://100.93.144.78:5174/
```

**⚠️ PORT PATTERN:** The frontend port MUST match your directory number:
- ct1 → http://100.93.144.78:5171/
- ct2 → http://100.93.144.78:5172/
- ct3 → http://100.93.144.78:5173/
- ct4 → http://100.93.144.78:5174/ ← YOU ARE HERE

This requires the vite dev server to be running. Start it with:
```bash
cd /home/odio/Hacking/codel/ct4/frontend && npm run dev
```
Vite will automatically use port 5174 (configured in vite.config.ts).

## Monitor Call

**Tail logs immediately:**
```bash
docker compose logs -f api worker
```

**Look for:**
- API receives webhook: `POST /webhook/voice-call`
- Worker processes: `Transcribing audio chunk`
- Enrichment: `voice_message_enricher prompt used`
- Interventions: `Sending intervention to...`

**Check for call activity:**
```bash
docker compose logs --since 5m | grep -iE -B 5 -A 5 "call|voice|twilio"
```

## Troubleshooting - Work Backwards

**Call placed but NO LOGS in docker → Check in this order:**

1. **Is Docker running?**
   ```bash
   docker compose ps
   # All services should show "Up"
   ```
   Fix: `docker compose up -d`

2. **Is Tailscale funnel active?**
   ```bash
   tailscale funnel status
   # Should show: https://wakeup.tail... (Funnel on) |-- / proxy http://127.0.0.1:8084
   ```
   Fix: `tailscale funnel --https=443 8084`

3. **Is webhook configured in Twilio?**
   ```bash
   # Check what webhook URL is set
   set -a && source .env && set +a && python -c "
   from twilio.rest import Client; import os
   client = Client(os.getenv('TWILIO_ACCOUNT_SID'), os.getenv('TWILIO_AUTH_TOKEN'))
   for n in client.incoming_phone_numbers.list(phone_number='+16503977712'):
       print(f'Voice URL: {n.voice_url}')
   "
   ```
   Expected: `https://wakeup.tail3b4b7f.ts.net/webhook/voice/twilio`

**Call logs appear but NO VAD/transcription → Check:**
- Audio URL is accessible: `curl -I <audio-url>` (should return 200 OK)
- Worker is running: `docker compose ps | grep worker`
- OpenAI API key set: `grep OPENAI_API_KEY .env`

## Quick Reference

```bash
# Pre-flight check
find . -maxdepth 4 -name "twilio_place_call.py" -type f 2>/dev/null
docker compose ps
sudo tailscale funnel status  # Use tailscale-manager skill commands

# Verify webhook
docker compose exec api bash -lc 'set -a && source /app/.env && set +a && python -c "from twilio.rest import Client; import os; client = Client(os.environ[\"TWILIO_ACCOUNT_SID\"], os.environ[\"TWILIO_AUTH_TOKEN\"]); [print(f\"Voice URL: {n.voice_url}\") for n in client.incoming_phone_numbers.list(phone_number=\"+16503977712\")]"'

# Place 1-minute call
docker compose exec api bash -lc 'cd /app/src/scripts && set -a && source /app/.env && set +a && uv run python twilio_place_call.py --from +18643997362 --to +16503977712 --duration-minutes 1 --audio-url https://github.com/srosro/sample-audio/raw/refs/heads/main/lib3_mulaw.wav'

# Monitor
docker compose logs -f api worker
docker compose logs --since 5m | grep -iE "call|voice|twilio"
```

## Required Environment Variables

In `api/.env`:
```bash
TWILIO_ACCOUNT_SID=ACxxxxx
TWILIO_AUTH_TOKEN=xxxxx
OPENAI_API_KEY=sk-xxxxx
LANGFUSE_PUBLIC_KEY=pk-xxxxx
LANGFUSE_SECRET_KEY=sk-xxxxx
LANGFUSE_HOST=https://langfuse.prod.cncorp.io
```

**Notes:**
- Keep calls short (1 min) - costs money, uses Twilio slots
- Tailscale funnel must stay running during test
- Phone numbers need country code (+16503977712)
