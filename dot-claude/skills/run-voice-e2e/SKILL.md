---
name: run-voice-e2e
description: Complete E2E workflow for voice calls - database setup, user creation, infrastructure verification, and call testing. Use when setting up voice testing from scratch or debugging voice pipeline issues.
dependencies:
  - tailscale-manager
  - twilio-test-caller
allowed-tools:
  - Bash
  - Read
  - Glob
  - Skill
---

# Voice E2E Testing Workflow

**Simple rule: Place a call, check if logs appear. If no logs → something's broken.**

## When to Use

- Setting up voice testing for the first time
- Debugging voice call failures
- Running voice baseline metrics collection
- Verifying complete voice pipeline works E2E

## Critical Architecture Requirement

**⚠️ EVERY voice user MUST have THREE conversation types:**

1. **GROUP** conversation - Contains 2 MEMBERS (the couple) + 1 THERAPIST (the AI coach)
2. **ONE_ON_ONE** conversation - Contains 1 MEMBER + 1 THERAPIST
3. **VOICE** conversation - Created automatically during calls

**Why all three are required:**
- The voice webhook looks up the caller's GROUP conversation to find their partner
- But VOICE uses a different therapist Person than text messaging
- The ONE_ON_ONE bridges this: `VOICE → ONE_ON_ONE → GROUP`
- Without ONE_ON_ONE, the lookup fails with: `ValueError: No ONE_ON_ONE conversation found for VOICE conversation`

See `api/src/data/models/conversation.py:220-236` for the implementation.

## Prerequisites

1. ✅ Docker running (`docker compose ps`)
2. ✅ Tailscale funnel active (use `tailscale-manager` skill)
3. ✅ Environment variables configured (`.env` file)
4. ✅ Database running and accessible

## Complete Pipeline Flow

**Understand the flow from script → logs to debug issues:**

**⚠️ PORT PATTERN - CRITICAL**: We use parallel dev environments (ct1, ct2, ct3, ct4). **ALL PORTS MUST END WITH THE SAME DIGIT AS THE DIRECTORY NUMBER**:

| Directory | API Port | Postgres Port | Redis Port | Vite Port |
|-----------|----------|---------------|------------|-----------|
| ct1       | 8081     | 5431          | 6371       | 5171      |
| ct2       | 8082     | 5432          | 6372       | 5172      |
| ct3       | 8083     | 5433          | 6373       | 5173      |
| **ct4**   | **8084** | **5434**      | **6374**   | **5174**  |

**YOU ARE IN ct4 → ALL PORTS END IN 4**

This pattern applies to:
- Tailscale funnel: `tailscale funnel --https=443 808X` where X = directory number
- API health check: `http://localhost:808X/health`
- Frontend URL: `http://100.93.144.78:517X/`
- Database connection: `localhost:543X`
- Redis connection: `localhost:637X`

| Step | Component | What Happens | Required Configuration | Expected Feedback/Logs | How to Verify |
|------|-----------|--------------|----------------------|----------------------|---------------|
| 1 | **Script Execution** | `twilio_place_call.py` sends API request to Twilio | `.env` has TWILIO_ACCOUNT_SID + TWILIO_AUTH_TOKEN | Terminal: `Started call CA... from +18643997362 to +16503977712` | Script runs without error |
| 2 | **Twilio Places Call** | Twilio initiates outbound call FROM +18643997362 TO +16503977712 | Phone number +16503977712 exists in Twilio account | Terminal: `status: in-progress` | Call connects (not busy/failed) |
| 3 | **Twilio Checks Webhook** | +16503977712 has webhook configured, Twilio POSTs to that URL | Twilio console: Voice URL = `https://wakeup.tail3b4b7f.ts.net/webhook/voice/twilio` | Twilio makes HTTP POST request | Check Twilio debugger console |
| 4 | **Tailscale Receives Request** | Public HTTPS request hits Tailscale funnel | `tailscale funnel status` shows `https://wakeup.tail3b4b7f.ts.net` → `http://127.0.0.1:808X` **(X = ct directory number, e.g. 8084 for ct4)** | Funnel proxies request to localhost | `tailscale funnel status` |
| 5 | **Docker API Receives** | FastAPI container receives POST on port 808X | `docker compose ps` shows ct4-api-1 running, listening on **port 8084** (ct4) | **API LOG**: `Received Twilio voice webhook call_sid=CA...` | `docker logs ct4-api-1 \| grep "Received Twilio"` |
| 6 | **Webhook Processes** | API looks up conversation, returns TwiML | Database has registered voice users with GROUP+ONE_ON_ONE+VOICE convos | **API LOG**: `Resolved existing voice caller`, `Using caller's voice contact` | `docker logs ct4-api-1 \| grep "voice caller"` |
| 7 | **TwiML Response** | FastAPI returns XML: `<Response><Say>...</Say><Connect><Stream url="wss://..."/></Connect></Response>` | TwiML includes WebSocket URL: `wss://wakeup.tail3b4b7f.ts.net/webhook/voice/twilio/stream` | Twilio receives 200 OK with TwiML body | API logs show HTTP 200 response |
| 8 | **Twilio → WebSocket** | Twilio opens WebSocket connection to stream endpoint, starts streaming audio | WebSocket endpoint `/webhook/voice/twilio/stream` implemented, Tailscale funnel supports WebSocket upgrade | **API LOG**: `connection open`, `Twilio media stream started` | `docker logs ct4-api-1 \| grep "media stream started"` |
| 9 | **Stream Processing** | StreamingTranscriptProcessor + RealtimeProcessor initialized, VAD starts | Silero VAD model cached, OpenAI API key configured, Langfuse configured | **API LOG**: `VAD model loaded`, `OpenAI Realtime WebSocket connected`, `Langfuse configuration loaded` | VAD and Realtime processor logs appear |
| 10 | **Audio Processing** | Twilio streams mulaw audio → decoded → VAD segments → queued for transcription | Worker container running, Redis available | **API LOG**: `Running VAD over audio chunk`, `Queueing streaming segment`, `Enqueued streaming segment` | Audio segments detected and queued |
| 11 | **Worker/Transcription** | RQ worker picks up transcription job, calls OpenAI Whisper API | ct4-worker-1 running, OPENAI_API_KEY valid | **WORKER LOG**: transcription results | `docker logs ct4-worker-1` shows job processing |
| 12 | **End Call** | Call duration expires or hangup, WebSocket closes, cleanup | - | **API LOG**: `Persisted Twilio media stream to WAV`, `Finalizing Realtime processor`, `OpenAI WebSocket closed` | Cleanup logs, WAV file saved to `/app/tmp/twilio_streams/` |

**Use this table to diagnose issues: If you don't see logs at step N, check the configuration for step N.**

## Step 1: Verify Infrastructure

### Check Docker Services
```bash
cd /home/odio/Hacking/codel/ct4
docker compose ps
```

All services should show "Up". If not:
```bash
docker compose up -d
```

### Check Tailscale Funnel
Use the `tailscale-manager` skill to verify:
```bash
sudo tailscale funnel status
```

Expected output:
```
https://wakeup.tail3b4b7f.ts.net (Funnel on)
|-- / proxy http://127.0.0.1:8084
```

If funnel is not running, start it:
```bash
sudo tailscale funnel --https=443 8084
```

### Verify API Health
```bash
curl https://wakeup.tail3b4b7f.ts.net/health
```

Expected: `{"status":"healthy"}`

## Step 2: Set Up Test Users

**CRITICAL:** Each voice user needs all three conversation types (GROUP, ONE_ON_ONE, VOICE).

### Check Existing Users
```bash
cd /home/odio/Hacking/codel/ct4/api
set -a && source .env && set +a && PYTHONPATH=src uv run python -c "
from config.database import get_session
from data.helpers.models import PersonContacts

with get_session() as session:
    # Check if users exist
    jake = session.query(PersonContacts).filter_by(
        handle='+16504850071',
        provider='twilio_voice'
    ).first()

    mary = session.query(PersonContacts).filter_by(
        handle='+13607896822',
        provider='twilio_voice'
    ).first()

    if jake:
        print(f'✅ Jake exists: Person {jake.person_id}')
    else:
        print('❌ Jake does not exist')

    if mary:
        print(f'✅ Mary exists: Person {mary.person_id}')
    else:
        print('❌ Mary does not exist')
"
```

### Create Users If Needed

Create a setup script:

```bash
cd /home/odio/Hacking/codel/ct4/api
cat > setup_voice_e2e_users.py << 'EOF'
#!/usr/bin/env python3
"""Setup complete voice E2E testing users with all required conversations."""

import sys
from pathlib import Path

SRC_PATH = Path(__file__).resolve().parent / "src"
sys.path.insert(0, str(SRC_PATH))

from config.database import get_session
from data.helpers.models import PersonContacts, Persons
from data.helpers.user_management import create_person_with_contact
from data.models.conversation import Conversation, ConversationParticipant
from data.models.enums import ConversationType, ConversationState, ParticipantRole
from logger import get_logger

logger = get_logger()

def setup_voice_e2e_users():
    """Create Jake and Mary with all required conversation types."""

    with get_session() as session:
        # Get or create Jake
        jake_contact = session.query(PersonContacts).filter_by(
            handle="+16504850071",
            provider="twilio_voice"
        ).first()

        if not jake_contact:
            logger.info("Creating Jake...")
            jake_result = create_person_with_contact(
                session=session,
                name="Jake",
                provider="twilio_voice",
                provider_key="+16504850071",
                is_primary=True
            )
            session.commit()
            jake_contact = session.query(PersonContacts).filter_by(
                handle="+16504850071",
                provider="twilio_voice"
            ).first()
            logger.info(f"Created Jake: UUID {jake_result['person_global_uuid']}")
        else:
            logger.info(f"Jake exists: Person {jake_contact.person_id}")

        # Get or create Mary
        mary_contact = session.query(PersonContacts).filter_by(
            handle="+13607896822",
            provider="twilio_voice"
        ).first()

        if not mary_contact:
            logger.info("Creating Mary...")
            mary_result = create_person_with_contact(
                session=session,
                name="Mary",
                provider="twilio_voice",
                provider_key="+13607896822",
                is_primary=True
            )
            session.commit()
            mary_contact = session.query(PersonContacts).filter_by(
                handle="+13607896822",
                provider="twilio_voice"
            ).first()
            logger.info(f"Created Mary: UUID {mary_result['person_global_uuid']}")
        else:
            logger.info(f"Mary exists: Person {mary_contact.person_id}")

        # Get the Coach contact
        coach_contact = session.query(PersonContacts).filter_by(
            handle="+16503999736",
            provider="twilio_voice"
        ).first()

        if not coach_contact:
            logger.error("Coach contact not found! Need to create coach first.")
            return

        jake_person = session.get(Persons, jake_contact.person_id)
        mary_person = session.get(Persons, mary_contact.person_id)

        # Check if GROUP conversation exists
        group_conv = None
        for cp in jake_person.conversation_participants:
            if cp.conversation.type == ConversationType.GROUP and cp.conversation.state == ConversationState.ACTIVE:
                group_conv = cp.conversation
                break

        if not group_conv:
            logger.info("Creating GROUP conversation...")
            group_conv = Conversation(
                provider='system',
                provider_key=f'group_jake_mary_e2e',
                type=ConversationType.GROUP,
                state=ConversationState.ACTIVE
            )
            session.add(group_conv)
            session.flush()

            # Add participants
            for person, contact in [(jake_person, jake_contact), (mary_person, mary_contact)]:
                session.add(ConversationParticipant(
                    conversation_id=group_conv.id,
                    person_id=person.id,
                    person_contact_id=contact.id,
                    role=ParticipantRole.MEMBER
                ))

            # Add coach as THERAPIST
            session.add(ConversationParticipant(
                conversation_id=group_conv.id,
                person_id=coach_contact.person_id,
                person_contact_id=coach_contact.id,
                role=ParticipantRole.THERAPIST
            ))

            session.commit()
            logger.info(f"Created GROUP conversation {group_conv.id}")
        else:
            logger.info(f"GROUP conversation exists: {group_conv.id}")

        # Check if Jake has ONE_ON_ONE
        one_on_one_conv = None
        for cp in jake_person.conversation_participants:
            if cp.conversation.type == ConversationType.ONE_ON_ONE and cp.conversation.state == ConversationState.ACTIVE:
                one_on_one_conv = cp.conversation
                break

        if not one_on_one_conv:
            logger.info("Creating ONE_ON_ONE conversation for Jake...")
            one_on_one_conv = Conversation(
                provider='sendblue',
                provider_key=f'jake_coach_121_e2e',
                type=ConversationType.ONE_ON_ONE,
                state=ConversationState.ACTIVE
            )
            session.add(one_on_one_conv)
            session.flush()

            # Add Jake as MEMBER
            session.add(ConversationParticipant(
                conversation_id=one_on_one_conv.id,
                person_id=jake_person.id,
                person_contact_id=jake_contact.id,
                role=ParticipantRole.MEMBER
            ))

            # Add Coach as THERAPIST
            session.add(ConversationParticipant(
                conversation_id=one_on_one_conv.id,
                person_id=coach_contact.person_id,
                person_contact_id=coach_contact.id,
                role=ParticipantRole.THERAPIST
            ))

            session.commit()
            logger.info(f"Created ONE_ON_ONE conversation {one_on_one_conv.id}")
        else:
            logger.info(f"ONE_ON_ONE conversation exists: {one_on_one_conv.id}")

        print("\n✅ Voice E2E users ready:")
        print(f"  Jake: +16504850071 (Person {jake_person.id})")
        print(f"  Mary: +13607896822 (Person {mary_person.id})")
        print(f"  GROUP conversation: {group_conv.id}")
        print(f"  ONE_ON_ONE conversation: {one_on_one_conv.id}")
        print("\nJake can now call +16503977712 for E2E testing.")

if __name__ == "__main__":
    setup_voice_e2e_users()
EOF

chmod +x setup_voice_e2e_users.py
```

Run the setup:
```bash
cd /home/odio/Hacking/codel/ct4/api
set -a && source .env && set +a && uv run python setup_voice_e2e_users.py
```

### Verify User Setup

Check that all conversations exist:

```bash
cd /home/odio/Hacking/codel/ct4/api
set -a && source .env && set +a && PYTHONPATH=src uv run python -c "
from config.database import get_session
from data.models.conversation import Conversation, ConversationParticipant
from data.models.enums import ConversationType

with get_session() as session:
    # Get Jake's conversations
    jake_participants = session.query(ConversationParticipant).filter(
        ConversationParticipant.person_id == 12  # Jake's person_id - ADJUST AS NEEDED
    ).all()

    print('Jake conversations:')
    for cp in jake_participants:
        conv = session.query(Conversation).filter(Conversation.id == cp.conversation_id).first()
        participant_count = session.query(ConversationParticipant).filter(
            ConversationParticipant.conversation_id == conv.id
        ).count()
        print(f'  ✅ {conv.type.name}: ID {conv.id}, {participant_count} participants')
"
```

Expected output:
```
Jake conversations:
  ✅ GROUP: ID 16, 3 participants
  ✅ ONE_ON_ONE: ID 18, 2 participants
  ✅ VOICE: ID 17, 3 participants (if call already made)
```

## Step 3: Place Test Calls

**⚠️ DEPENDENCY: Use the `twilio-test-caller` skill to place calls**

You have two options for making test calls:

### Option A: Manual Call (Real Phone)
Call +16503977712 from Jake's phone (+16504850071). This tests real audio input.

### Option B: Programmatic Call (Automated)
Use the `twilio-test-caller` skill to place automated calls with test audio.

**The call tests the complete flow:**
1. Twilio receives inbound call
2. Twilio webhook calls your API via Tailscale funnel
3. API finds Jake's GROUP conversation (via ONE_ON_ONE lookup)
4. API creates VOICE conversation
5. WebSocket streams audio
6. VAD detects speech segments
7. Transcription happens
8. Messages saved to database

**To place a programmatic call, invoke the `twilio-test-caller` skill.**

## Step 4: Monitor the Call

### Watch logs in real-time:
```bash
cd /home/odio/Hacking/codel/ct4
docker logs ct4-api-1 -f --tail 50
```

### Look for these events:
1. ✅ `Received Twilio voice webhook` - Call received
2. ✅ `WebSocket /webhook/voice/twilio/stream` - WebSocket connected
3. ✅ `Twilio media stream started` - Audio streaming started
4. ✅ `Initialized streaming VAD` - Voice activity detection ready
5. ✅ `Speech segment detected` - Speech found in audio
6. ✅ `Transcription job queued` - Sent to worker for transcription
7. ✅ `Transcription completed` - Text extracted from audio

### Check for errors:
```bash
docker logs ct4-api-1 --since 2m 2>&1 | grep -i error
```

Common errors and fixes:
- `ValueError: This method is only valid for couple group conversations` → GROUP needs 3 participants (2 MEMBERS + 1 THERAPIST)
- `ValueError: No ONE_ON_ONE conversation found` → Create ONE_ON_ONE conversation for user
- `Unregistered caller` → User not in database
- `FATAL: Caller has no active GROUP conversation` → Create GROUP conversation

## Step 5: Verify Transcriptions

Check if messages were created:

```bash
cd /home/odio/Hacking/codel/ct4/api
set -a && source .env && set +a && PYTHONPATH=src uv run python -c "
from config.database import get_session
from data.models.message import Message
from data.models.conversation import Conversation
from data.models.enums import ConversationType

with get_session() as session:
    # Find recent VOICE conversation
    voice_conv = session.query(Conversation).filter(
        Conversation.type == ConversationType.VOICE
    ).order_by(Conversation.created_at.desc()).first()

    if voice_conv:
        print(f'Latest VOICE conversation: {voice_conv.id}')
        print(f'  Call SID: {voice_conv.provider_key}')

        # Get messages
        messages = session.query(Message).filter(
            Message.conversation_id == voice_conv.id
        ).order_by(Message.created_at).all()

        print(f'  Messages: {len(messages)}')
        for msg in messages:
            print(f'    - {msg.content[:100]}...')
    else:
        print('No VOICE conversations found')
"
```

## Step 6: Verify Interventions

After transcriptions are created, verify that interventions were generated by the AI coach.

### Start Frontend Server (if not running):
```bash
cd /home/odio/Hacking/codel/ct4/frontend
npm run dev
```

Expected output:
```
  ➜  Local:   http://localhost:5174/
  ➜  Network: http://100.93.144.78:5174/
```

### View Interventions:
Visit the frontend at:
```
http://100.93.144.78:5174/
```

This will show all interventions created during the call. If no interventions appear, check:
- Worker logs for enrichment errors
- OpenAI API key is valid
- Messages exist in database (Step 5)

**⚠️ PORT PATTERN:** Frontend runs on port **5174** for ct4 (follows pattern: ct1=5171, ct2=5172, ct3=5173, ct4=5174). The port MUST match your directory number.

## Step 7: Collect Metrics

### Copy metrics from container:
```bash
cd /home/odio/Hacking/codel/ct4/api
docker cp ct4-api-1:/app/tmp/stream_metrics.log worker_stream_metrics.log
```

### Analyze metrics:
```bash
cd /home/odio/Hacking/codel/ct4/api
uv run python analyze_worker_metrics.py
```

Expected output:
```
Event                               Count    Avg (ms)    P95 (ms)
=================================================================
transcription_job                       5      1250.45     1450.23
voice_message_enrichment                5       850.12      950.45
vad_speech_detection                   10        45.23       55.67
=================================================================
Total events                           20
```

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Call rejected with "Unregistered caller" | User not in database | Run `setup_voice_e2e_users.py` |
| `ValueError: couple group conversations` | GROUP missing THERAPIST | Add coach as THERAPIST to GROUP |
| `ValueError: No ONE_ON_ONE conversation` | Missing ONE_ON_ONE | Create ONE_ON_ONE with user + coach |
| WebSocket crashes | Infrastructure issue | Check Tailscale funnel, Docker logs |
| No transcriptions | OpenAI API issue | Check OPENAI_API_KEY, worker logs |
| No metrics logged | Instrumentation off | Verify `instrument_operation` in code |

## Quick Reference Commands

```bash
# Pre-flight check
cd /home/odio/Hacking/codel/ct4
docker compose ps
sudo tailscale funnel status
curl https://wakeup.tail3b4b7f.ts.net/health

# Setup users
cd api && set -a && source .env && set +a && uv run python setup_voice_e2e_users.py

# Make call (manually from phone)
# Call +16503977712 from +16504850071

# Monitor logs
docker logs ct4-api-1 -f --tail 50

# Check errors
docker logs ct4-api-1 --since 2m 2>&1 | grep -i error

# Collect metrics
docker cp ct4-api-1:/app/tmp/stream_metrics.log worker_stream_metrics.log
uv run python analyze_worker_metrics.py
```

## Skill Dependencies

This skill orchestrates the full E2E workflow and delegates specific tasks to other skills:

- **tailscale-manager** - Infrastructure: Manage Tailscale funnel for webhook access
- **twilio-test-caller** - Testing: Place programmatic test calls with audio
- **docker-log-debugger** - Debugging: Analyze Docker container issues

## Workflow Summary

1. **Setup** (this skill):
   - Verify infrastructure (Docker, Tailscale, API health)
   - Create test users with all required conversation types
   - Verify database integrity

2. **Test** (delegate to `twilio-test-caller`):
   - Place calls programmatically
   - Monitor call progress

3. **Verify** (this skill):
   - Check transcriptions in database
   - Collect and analyze metrics
   - Debug issues if any
