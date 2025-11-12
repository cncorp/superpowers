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

## Place Call

**Basic command (1 minute call):**
```bash
docker compose exec api bash -lc 'cd /app/src/scripts && \
set -a && source /app/.env && set +a && \
uv run python twilio_place_call.py \
  --from +18643997362 \
  --to +16503977712 \
  --duration-minutes 1 \
  --audio-url https://github.com/srosro/sample-audio/raw/refs/heads/main/lib3_mulaw.wav'
```

**Parameters:**
- `--from` - Twilio number (default: +18643997362)
- `--to` - Recipient number (default: +16503977712)
- `--duration-minutes` - Call length (default: 1, keep short)
- `--audio-url` - Test audio URL

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

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Script not found | Branch doesn't have voice features |
| Docker not running | `docker compose up -d` |
| Funnel not active | Use tailscale-manager skill to start funnel: `sudo tailscale funnel --https=443 8082` |
| Call not received | **Most common!** Verify Twilio webhook points to Tailscale URL (see step 4 above) |
| Call fails immediately | Check audio URL accessible: `curl -I <audio-url>` |
| No transcription | Verify OPENAI_API_KEY in .env; check worker logs for Whisper calls |
| No interventions | Fetch `voice_message_enricher` prompt; check intervention conditions in logs |

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
