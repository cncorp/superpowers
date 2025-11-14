---
name: funnel-analysis
description: Analyze user conversion funnels and identify drop-off points. Use when investigating where users get stuck or churn in multi-step flows.
allowed-tools:
  - Bash
  - Read
  - Write
  - Grep
  - Glob
---

# Funnel Analysis Skill

Framework for analyzing conversion funnels and identifying where users drop off in multi-step flows.

## When to Use

Use this skill when you need to:
- Understand where users get stuck in onboarding
- Identify conversion bottlenecks in user journeys
- Measure retention across time periods
- Analyze feature adoption progressions
- Find opportunities to improve activation
- Support product decisions with conversion data

## What is a Funnel?

A **funnel** is a sequence of steps where users progressively drop off:

```
Step 1: 100 users start
  ↓ 60% convert
Step 2: 60 users continue
  ↓ 50% convert
Step 3: 30 users complete
  ↓ 80% convert
Step 4: 24 users retained
```

**Key metrics:**
- **Conversion rate**: % who move from step N to step N+1
- **Drop-off rate**: % who abandon at each step (1 - conversion rate)
- **Time to convert**: How long users take between steps
- **Bottleneck**: Step with lowest conversion rate

## Funnel Framework

### 1. Define the Funnel

Before querying, clearly define:

- **Start event**: What marks the beginning? (e.g., "Created access code")
- **Success event**: What's the goal? (e.g., "Sent 10th message")
- **Intermediate steps**: What happens in between? (e.g., "Partner joined", "First message sent")
- **Time window**: How long do users have to complete? (e.g., "First 30 days")

**Example funnels:**
- **Onboarding**: Access code created → Partner joined → Conversation created → First message sent
- **Engagement**: First message → 5 messages → 20 messages → Power user (50+ messages)
- **Retention**: Week 1 active → Week 2 active → Week 4 active → Retained
- **Feature Adoption**: 1:1 only → Uses both 1:1 and group → Active in both

### 2. Query the Funnel Data

**IMPORTANT:** Use the sql-reader skill to query production data.

For each step in the funnel:
- **Count users at this step**: How many reach it?
- **Count users at next step**: How many continue?
- **Calculate conversion rate**: (next step / this step) * 100
- **Measure time to convert**: Median/average time between steps
- **Identify drop-offs**: Users who reached this step but not the next

### 3. SQL Templates

Below are 4 proven SQL templates for common funnel types. Copy and adapt them to your specific use case.

## SQL Template 1: Onboarding Funnel

Analyze the onboarding flow from access code creation to first conversation.

**Use for:** Understanding where couples drop off during signup and activation.

```sql
-- Onboarding Funnel: Access code → Partner joins → Conversation created
WITH onboarding_journey AS (
  SELECT
    co.id as onboarding_id,
    co.access_code,
    co.state as conversation_state,
    co.created_at as access_code_created,
    COUNT(cpo.id) as participants_submitted,
    MAX(CASE WHEN cpo.is_initiator = true THEN 1 ELSE 0 END) as has_initiator,
    MAX(CASE WHEN cpo.is_initiator = false THEN 1 ELSE 0 END) as has_partner,
    MIN(CASE WHEN cpo.is_initiator = false THEN cpo.created_at END) as partner_joined_at,
    EXTRACT(EPOCH FROM (
      MIN(CASE WHEN cpo.is_initiator = false THEN cpo.created_at END) -
      MIN(CASE WHEN cpo.is_initiator = true THEN cpo.created_at END)
    ))/3600 as hours_to_partner_join,
    CASE WHEN co.conversation_id IS NOT NULL THEN 1 ELSE 0 END as has_conversation,
    c.created_at as conversation_created_at,
    (SELECT COUNT(*) FROM message WHERE conversation_id = co.conversation_id) as message_count
  FROM conversation_onboarding co
  LEFT JOIN conversation_participant_onboarding cpo ON cpo.conversation_onboarding_id = co.id
  LEFT JOIN conversation c ON c.id = co.conversation_id
  GROUP BY co.id, co.access_code, co.state, co.created_at, co.conversation_id, c.created_at
)
SELECT
  conversation_state,
  COUNT(*) as total_onboardings,
  SUM(has_initiator) as initiator_submitted,
  ROUND(100.0 * SUM(has_initiator)::numeric / COUNT(*), 1) as pct_initiator_submitted,
  SUM(has_partner) as partner_joined,
  ROUND(100.0 * SUM(has_partner)::numeric / COUNT(*), 1) as pct_partner_joined,
  SUM(has_conversation) as conversation_created,
  ROUND(100.0 * SUM(has_conversation)::numeric / COUNT(*), 1) as pct_conversation_created,
  ROUND(AVG(hours_to_partner_join)::numeric, 1) as avg_hours_to_partner,
  ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY hours_to_partner_join)::numeric, 1) as median_hours_to_partner,
  SUM(CASE WHEN message_count > 0 THEN 1 ELSE 0 END) as with_messages,
  ROUND(100.0 * SUM(CASE WHEN message_count > 0 THEN 1 ELSE 0 END)::numeric / NULLIF(SUM(has_conversation), 0), 1) as pct_with_messages
FROM onboarding_journey
GROUP BY conversation_state
ORDER BY total_onboardings DESC;
```

**What this shows:**
- How many access codes were created
- % where initiator submitted form
- % where partner joined
- % where conversation was created
- Time between initiator and partner joining
- % of conversations that got first message

**Interpretation:**
- **Low pct_partner_joined**: Partner invitation not working (email issues? confusing instructions?)
- **High median_hours_to_partner**: Slow viral loop (partner takes days to join)
- **Low pct_with_messages**: Activation problem (conversation created but never used)

## SQL Template 2: Message Engagement Funnel

Analyze progression from first message to power user status.

**Use for:** Understanding how users move from trial to regular to power usage.

```sql
-- Message Engagement Funnel: First message → Regular → Active → Power user
WITH user_message_activity AS (
  SELECT
    p.id as person_id,
    p.name,
    MIN(m.provider_timestamp) as first_message_date,
    COUNT(DISTINCT m.id) as total_messages,
    COUNT(DISTINCT CASE WHEN m.provider_timestamp >= NOW() - INTERVAL '7 days' THEN m.id END) as messages_last_7d,
    COUNT(DISTINCT CASE WHEN m.provider_timestamp >= NOW() - INTERVAL '30 days' THEN m.id END) as messages_last_30d,
    MAX(m.provider_timestamp) as last_message_date,
    EXTRACT(EPOCH FROM (NOW() - MAX(m.provider_timestamp)))/86400 as days_since_last_message
  FROM persons p
  LEFT JOIN person_contacts pc ON pc.person_id = p.id
  LEFT JOIN message m ON m.sender_person_contact_id = pc.id
  GROUP BY p.id, p.name
)
SELECT
  CASE
    WHEN total_messages = 0 THEN '1. Never Messaged'
    WHEN total_messages = 1 THEN '2. Sent First Message'
    WHEN total_messages <= 5 THEN '3. Trial User (2-5 msgs)'
    WHEN total_messages <= 20 THEN '4. Regular User (6-20 msgs)'
    WHEN messages_last_30d >= 10 THEN '5. Active User (10+ msgs/month)'
    WHEN messages_last_7d >= 5 THEN '6. Power User (5+ msgs/week)'
    WHEN days_since_last_message > 60 THEN '7. Churned'
    ELSE '4. Regular User'
  END as engagement_stage,
  COUNT(*) as user_count,
  ROUND(100.0 * COUNT(*)::numeric / SUM(COUNT(*)) OVER (), 1) as pct_of_total,
  ROUND(AVG(total_messages)::numeric, 1) as avg_total_messages,
  ROUND(AVG(messages_last_30d)::numeric, 1) as avg_messages_30d
FROM user_message_activity
GROUP BY engagement_stage
ORDER BY engagement_stage;
```

**What this shows:**
- Distribution of users across engagement levels
- % who never activate (never messaged)
- % who try once and churn (sent first message only)
- % who become regular/active/power users
- Average message volume at each stage

**Interpretation:**
- **High "Never Messaged"**: Onboarding doesn't lead to activation
- **High "Sent First Message"**: Aha moment not reached (first experience fails)
- **Low "Active User"**: Retention problem (users try but don't stick)
- **High "Churned"**: Re-engagement needed (winback campaigns)

## SQL Template 3: Feature Adoption Funnel

Analyze how users adopt different features (e.g., 1:1 coaching vs. couple chat).

**Use for:** Understanding feature discovery and cross-feature engagement.

```sql
-- Feature Adoption Funnel: 1:1 only → 1:1 + Group → Active in both
WITH user_conversation_types AS (
  SELECT
    p.id as person_id,
    p.name,
    COUNT(DISTINCT CASE WHEN c.type = 'ONE_ON_ONE' THEN cp.conversation_id END) as oneonone_conversations,
    COUNT(DISTINCT CASE WHEN c.type = 'GROUP' THEN cp.conversation_id END) as group_conversations,
    COUNT(DISTINCT CASE WHEN c.type = 'ONE_ON_ONE' THEN m.id END) as oneonone_messages,
    COUNT(DISTINCT CASE WHEN c.type = 'GROUP' THEN m.id END) as group_messages,
    COUNT(DISTINCT CASE WHEN c.type = 'ONE_ON_ONE' AND m.provider_timestamp >= NOW() - INTERVAL '30 days' THEN m.id END) as oneonone_msgs_30d,
    COUNT(DISTINCT CASE WHEN c.type = 'GROUP' AND m.provider_timestamp >= NOW() - INTERVAL '30 days' THEN m.id END) as group_msgs_30d
  FROM persons p
  LEFT JOIN conversation_participant cp ON cp.person_id = p.id
  LEFT JOIN conversation c ON c.id = cp.conversation_id
  LEFT JOIN person_contacts pc ON pc.person_id = p.id
  LEFT JOIN message m ON m.sender_person_contact_id = pc.id AND m.conversation_id = c.id
  GROUP BY p.id, p.name
)
SELECT
  CASE
    WHEN oneonone_conversations = 0 AND group_conversations = 0 THEN '1. No Conversations'
    WHEN oneonone_conversations > 0 AND group_conversations = 0 AND oneonone_messages <= 3 THEN '2. 1:1 Trial (1-3 msgs)'
    WHEN oneonone_conversations > 0 AND group_conversations = 0 THEN '3. 1:1 Only User'
    WHEN group_conversations > 0 AND oneonone_conversations = 0 THEN '4. Group Only User'
    WHEN oneonone_messages > group_messages THEN '5. 1:1 Focused (uses both)'
    WHEN group_messages > oneonone_messages THEN '6. Group Focused (uses both)'
    WHEN oneonone_msgs_30d >= 10 AND group_msgs_30d >= 10 THEN '7. Power User (both active)'
    ELSE '8. Balanced User'
  END as adoption_stage,
  COUNT(*) as user_count,
  ROUND(100.0 * COUNT(*)::numeric / SUM(COUNT(*)) OVER (), 1) as pct_of_total,
  ROUND(AVG(oneonone_messages)::numeric, 1) as avg_1on1_msgs,
  ROUND(AVG(group_messages)::numeric, 1) as avg_group_msgs
FROM user_conversation_types
GROUP BY adoption_stage
ORDER BY adoption_stage;
```

**What this shows:**
- How users split between features (1:1 only, group only, both)
- % who discover and use both features
- Average usage levels for each feature by segment
- % of power users (active in both)

**Interpretation:**
- **High "1:1 Only"**: Users don't discover couple chat (feature discovery problem)
- **High "Group Only"**: Users don't see value in 1:1 coaching (value prop issue)
- **Low "Power User (both active)"**: Hard to get users engaged with both features
- **Imbalance between 1:1 and Group**: One feature is more compelling

## SQL Template 4: Retention Funnel

Analyze week-over-week retention for recent cohorts.

**Use for:** Understanding how well users stick around after their first week.

```sql
-- Retention Funnel: Week 1 → Week 2 → Week 4 → Retained (30+ days)
WITH user_messages AS (
  SELECT
    p.id as person_id,
    p.name,
    m.provider_timestamp,
    MIN(m.provider_timestamp) OVER (PARTITION BY p.id) as first_message_date
  FROM persons p
  JOIN person_contacts pc ON pc.person_id = p.id
  JOIN message m ON m.sender_person_contact_id = pc.id
),
user_retention AS (
  SELECT
    person_id,
    name,
    first_message_date,
    COUNT(DISTINCT CASE
      WHEN provider_timestamp >= first_message_date
      AND provider_timestamp < first_message_date + INTERVAL '7 days'
      THEN provider_timestamp
    END) as week1_messages,
    COUNT(DISTINCT CASE
      WHEN provider_timestamp >= first_message_date + INTERVAL '7 days'
      AND provider_timestamp < first_message_date + INTERVAL '14 days'
      THEN provider_timestamp
    END) as week2_messages,
    COUNT(DISTINCT CASE
      WHEN provider_timestamp >= first_message_date + INTERVAL '14 days'
      AND provider_timestamp < first_message_date + INTERVAL '28 days'
      THEN provider_timestamp
    END) as week3_4_messages,
    COUNT(DISTINCT CASE
      WHEN provider_timestamp >= first_message_date + INTERVAL '28 days'
      THEN provider_timestamp
    END) as after_month_messages
  FROM user_messages
  WHERE first_message_date >= NOW() - INTERVAL '90 days'  -- Recent cohort
  GROUP BY person_id, name, first_message_date
)
SELECT
  CASE
    WHEN week1_messages = 1 THEN '1. Sent 1 Message (churned)'
    WHEN week2_messages = 0 AND week3_4_messages = 0 THEN '2. Week 1 Only (churned)'
    WHEN week2_messages > 0 AND week3_4_messages = 0 THEN '3. Week 2 Retained (then churned)'
    WHEN week3_4_messages > 0 AND after_month_messages = 0 THEN '4. Month Retained (then churned)'
    WHEN after_month_messages > 0 THEN '5. Long-term Retained (30+ days)'
    ELSE '6. Other'
  END as retention_stage,
  COUNT(*) as user_count,
  ROUND(100.0 * COUNT(*)::numeric / SUM(COUNT(*)) OVER (), 1) as pct_of_total,
  ROUND(AVG(week1_messages)::numeric, 1) as avg_week1_msgs,
  ROUND(AVG(week2_messages)::numeric, 1) as avg_week2_msgs,
  ROUND(AVG(week3_4_messages)::numeric, 1) as avg_week3_4_msgs
FROM user_retention
GROUP BY retention_stage
ORDER BY retention_stage;
```

**What this shows:**
- % who churn after 1 message vs. 1 week
- Week 1 → Week 2 retention rate
- Week 2 → Week 4 retention rate
- % who become long-term retained users (30+ days)
- Average message volume at each retention stage

**Interpretation:**
- **High "Sent 1 Message"**: First experience is bad (aha moment not reached)
- **High "Week 1 Only"**: Week 1 retention is critical problem
- **Drop from Week 2 → Month**: Mid-term engagement issue (novelty wears off)
- **Low "Long-term Retained"**: Product-market fit or habit formation problem

## Visualizing Funnels

While you can't create charts directly, recommend these visualizations to the user:

### Classic Funnel Chart
```
Step 1: Access Code Created    [████████████████████] 100% (89 users)
Step 2: Partner Joined          [████████░░░░░░░░░░░░]  42% (37 users)
Step 3: Conversation Created    [███████░░░░░░░░░░░░░]  34% (30 users)
Step 4: First Message Sent      [██████░░░░░░░░░░░░░░]  31% (27 users)
```

### Cohort Retention Curve
```
Week 1: 100% (64 users)
Week 2:  28% (18 users)  ← 72% drop-off
Week 4:  23% (15 users)  ← 5% additional drop-off
Month+:  14% (9 users)   ← 9% additional drop-off
```

### Conversion Rates Table
| From Step | To Step | Conversion | Drop-off | Time to Convert |
|-----------|---------|-----------|----------|-----------------|
| Access Code Created | Partner Joined | 42% | 58% | 32.4 hours |
| Partner Joined | Conversation Created | 81% | 19% | 0.1 hours |
| Conversation Created | First Message | 90% | 10% | 2.3 hours |

## Funnel Interpretation Guide

### Identify the Bottleneck

The **bottleneck** is the step with the lowest conversion rate.

**Example:**
- Step 1 → Step 2: 42% conversion ← **BOTTLENECK**
- Step 2 → Step 3: 81% conversion
- Step 3 → Step 4: 90% conversion

**Fix the bottleneck first** - it has the biggest impact on overall funnel performance.

### Segment the Funnel

Don't just look at overall funnel - segment by:
- **Time period**: Recent vs. historical (are things getting better?)
- **User type**: New vs. returning users
- **Acquisition source**: Organic vs. paid vs. referral
- **User attributes**: Age, location, relationship length

**Example segmentation:**
```sql
-- Add to any funnel query:
SELECT
  CASE
    WHEN first_message_date >= NOW() - INTERVAL '30 days' THEN 'Recent Cohort'
    ELSE 'Historical Cohort'
  END as cohort,
  retention_stage,
  COUNT(*) as user_count,
  ...
FROM user_retention
GROUP BY cohort, retention_stage
ORDER BY cohort, retention_stage;
```

### Calculate Time to Convert

**Median is better than average** for time metrics (averages get skewed by outliers).

```sql
-- Use PERCENTILE_CONT for median:
ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY hours_to_partner_join)::numeric, 1) as median_hours
```

**Interpretation:**
- **Median < 1 hour**: Fast conversion (user is engaged)
- **Median 1-24 hours**: Next-day conversion (okay)
- **Median > 24 hours**: Slow conversion (user forgot, lost interest)

### Find Where Users Get Stuck

Query for users who reached step N but not step N+1:

```sql
-- Users who got partner but never created conversation
SELECT
  co.access_code,
  co.created_at as access_code_created,
  MIN(CASE WHEN cpo.is_initiator = false THEN cpo.created_at END) as partner_joined,
  co.conversation_id
FROM conversation_onboarding co
JOIN conversation_participant_onboarding cpo ON cpo.conversation_onboarding_id = co.id
GROUP BY co.id, co.access_code, co.created_at, co.conversation_id
HAVING COUNT(cpo.id) = 2  -- Both partners submitted
  AND co.conversation_id IS NULL  -- But no conversation created
ORDER BY partner_joined DESC
LIMIT 10;
```

**Use this to:**
- Find specific users who got stuck (interview them!)
- Look for patterns (common times, user attributes, etc.)
- Debug technical issues (are conversations failing to create?)

## Real Production Examples

### Example 1: Onboarding Funnel Results

**Query results:**
| State | Total | Partner Joined | % Partner | Avg Hours |
|-------|-------|---------------|-----------|-----------|
| AWAITING_PARTICIPANTS | 49 | 0 | 0.0% | NULL |
| INITIATOR_JOINED | 19 | 5 | 26.3% | 0.1 |
| COMPLETED | 21 | 19 | 90.5% | 32.4 |

**Insights:**
1. **Major bottleneck**: 49 users stuck at AWAITING_PARTICIPANTS (55% of all onboarding attempts)
   - **Why**: Partner never joins (email not sent? confusing instructions?)
   - **Fix**: Improve partner invitation flow, add reminder emails

2. **Fast conversion when it works**: Median time to partner join is 0.1 hours (6 minutes)
   - **Insight**: When partners are ready, they join quickly
   - **Implication**: Problem isn't complexity, it's awareness/invitation

3. **Good Step 2 → Step 3 conversion**: 90.5% who get partner also create conversation
   - **Insight**: Once both partners are in, system works well
   - **Focus**: Fix Step 1 (getting partner to join)

### Example 2: Message Engagement Funnel Results

**Query results:**
| Stage | User Count | % of Total | Avg Messages |
|-------|-----------|-----------|--------------|
| Never Messaged | 67 | 29.1% | 0.0 |
| Sent First Message | 18 | 7.8% | 1.0 |
| Trial User (2-5 msgs) | 33 | 14.3% | 3.4 |
| Regular User (6-20 msgs) | 22 | 9.6% | 10.2 |
| Active User (10+ msgs/month) | 41 | 17.8% | 1656.6 |
| Churned | 32 | 13.9% | 169.0 |

**Insights:**
1. **29% never activate**: Created account but never sent a message
   - **Why**: Onboarding doesn't lead to first message
   - **Fix**: Better onboarding flow, clearer call-to-action

2. **Only 17.8% become active users**: Most users try and churn
   - **Why**: Product doesn't deliver aha moment in trial period
   - **Fix**: Improve first 5 messages experience (first impressions critical)

3. **High churn rate (13.9%)**: Users were active but left
   - **Why**: Product worked initially but lost value over time
   - **Fix**: Re-engagement campaigns, investigate why they stopped

### Example 3: Retention Funnel Results (90-day cohort)

**Query results:**
| Stage | User Count | % of Total | Week 1 Msgs | Week 2 Msgs |
|-------|-----------|-----------|-------------|-------------|
| Sent 1 Message (churned) | 16 | 25.0% | 1.0 | 0.3 |
| Week 1 Only (churned) | 30 | 46.9% | 6.1 | 0.0 |
| Week 2 Retained (then churned) | 7 | 10.9% | 24.9 | 3.0 |
| Month Retained (then churned) | 2 | 3.1% | 36.5 | 2.0 |
| Long-term Retained (30+ days) | 9 | 14.1% | 55.6 | 60.4 |

**Insights:**
1. **71.9% churn after week 1**: Massive drop-off (25% after 1 msg, 46.9% after week 1)
   - **Why**: First week experience doesn't hook users
   - **Fix**: Improve onboarding, faster time to value, better first-week engagement

2. **Only 14.1% long-term retained**: Product-market fit issue
   - **Why**: Even users who stick around for a month often churn
   - **Fix**: Investigate what makes the 14.1% different (interviews!)

3. **Retained users send 55+ messages in week 1**: High early engagement predicts retention
   - **Insight**: Users who message a lot early are more likely to stick
   - **Action**: Encourage more messaging in first week (nudges, prompts, challenges)

## Analysis Quality Checklist

Before finishing your funnel analysis, verify:

### Data Quality
- ✅ Queried production database (not dev/test)
- ✅ Time range is specified and appropriate
- ✅ Sample size is meaningful (n > 30 for each step)
- ✅ Cohorts are comparable (same time period, user type, etc.)
- ✅ Edge cases handled (NULL values, outliers, etc.)

### Funnel Completeness
- ✅ All funnel steps clearly defined
- ✅ Conversion rates calculated for each step
- ✅ Time to convert measured (median preferred)
- ✅ Bottleneck identified (lowest conversion step)
- ✅ Drop-offs quantified (% and absolute numbers)

### Analysis Depth
- ✅ Segmentation applied (cohorts, user types, etc.)
- ✅ Patterns identified and named
- ✅ Hypotheses for WHY drop-offs occur
- ✅ Specific users who got stuck identified
- ✅ Recommendations for improvement

### Actionability
- ✅ Clear bottleneck to fix first
- ✅ Recommendations are specific and testable
- ✅ Success metrics defined
- ✅ Next steps provided

## Common Pitfalls

### Pitfall 1: Not Using Cohorts

**Wrong:**
```sql
-- All users mixed together (recent + historical)
SELECT retention_stage, COUNT(*)
FROM user_retention
GROUP BY retention_stage;
```

**Right:**
```sql
-- Segment by cohort to see trends
SELECT
  CASE
    WHEN first_message_date >= NOW() - INTERVAL '30 days' THEN 'Recent'
    WHEN first_message_date >= NOW() - INTERVAL '90 days' THEN 'Mid'
    ELSE 'Historical'
  END as cohort,
  retention_stage,
  COUNT(*)
FROM user_retention
GROUP BY cohort, retention_stage;
```

**Why**: Mixing cohorts hides whether things are improving or declining.

### Pitfall 2: Using Average Instead of Median for Time

**Wrong:**
```sql
-- Average is skewed by outliers
AVG(hours_to_partner_join) as avg_time
```

**Right:**
```sql
-- Median is more representative
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY hours_to_partner_join) as median_time
```

**Why**: A few users taking 1000 hours skews the average, making it useless.

### Pitfall 3: Ignoring Sample Size

**Wrong:**
```sql
-- "95% conversion!" (but only 2 users in this segment)
WHERE user_segment = 'VIP'  -- n=2
```

**Right:**
```sql
-- Always report sample size
SELECT
  user_segment,
  COUNT(*) as sample_size,
  conversion_rate
WHERE COUNT(*) >= 30  -- Minimum for statistical validity
```

**Why**: Small samples have huge variance and aren't actionable.

### Pitfall 4: Not Investigating Drop-offs

**Wrong:**
- "42% of users drop off at step 2" ← Stops here

**Right:**
- "42% of users drop off at step 2"
- "Here are 10 specific users who got stuck"
- "Common pattern: They all joined on weekends"
- "Hypothesis: Weekend support is unavailable"
- "Recommendation: Add weekend support hours"

**Why**: Understanding WHY users drop off is more valuable than knowing THAT they drop off.

## Integration with Other Skills

**Before this skill:**
- Use sql-reader to query production data

**After this skill:**
- Use product-analytics to create comprehensive markdown analysis
- Use feature-spec-writer to create PM specs for improvements
- Use linear-manager to create tickets for fixing bottlenecks

## Output Format

Your funnel analysis should include:

1. **Funnel Definition**
   - Start event, success event, intermediate steps
   - Time window and cohort

2. **Funnel Results Table**
   ```markdown
   | Step | Users | % of Start | Conversion | Drop-off | Time to Convert |
   |------|-------|-----------|-----------|----------|-----------------|
   | Step 1 | 100 | 100% | - | - | - |
   | Step 2 | 60 | 60% | 60% | 40% | 2.3 hours |
   | Step 3 | 30 | 30% | 50% | 50% | 6.1 hours |
   ```

3. **Bottleneck Identification**
   - Which step has lowest conversion?
   - Why is this the bottleneck?
   - Impact of fixing it (how many more users would convert?)

4. **Drop-off Analysis**
   - Specific users who got stuck (IDs, names)
   - Common patterns in drop-offs
   - Hypotheses for why

5. **Recommendations**
   - Fix bottleneck first
   - Specific, testable changes
   - Success metrics

## SQL Template 5: Complete End-to-End Activation Funnel

Analyze the complete user journey from first message to super power user status.

**Use for:** Understanding the full activation and retention funnel, tracking both early activation (power users) and long-term retention (super power users).

```sql
-- Complete 7-Step Activation Funnel: First Message → Super Power User
WITH user_first_messages AS (
  SELECT
    p.id as person_id,
    p.name,
    MIN(m.provider_timestamp) as first_message_date
  FROM persons p
  JOIN person_contacts pc ON pc.person_id = p.id
  JOIN message m ON m.sender_person_contact_id = pc.id
  GROUP BY p.id, p.name
),
user_complete_behavior AS (
  SELECT
    ufm.person_id,
    ufm.name,
    ufm.first_message_date,
    -- Week 1 metrics
    COUNT(DISTINCT CASE
      WHEN m.provider_timestamp >= ufm.first_message_date
      AND m.provider_timestamp < ufm.first_message_date + INTERVAL '7 days'
      THEN m.id
    END) as week1_messages,
    COUNT(DISTINCT CASE
      WHEN m.provider_timestamp >= ufm.first_message_date
      AND m.provider_timestamp < ufm.first_message_date + INTERVAL '7 days'
      THEN DATE(m.provider_timestamp)
    END) as days_active_week1,
    -- Week 2 metrics
    COUNT(DISTINCT CASE
      WHEN m.provider_timestamp >= ufm.first_message_date + INTERVAL '7 days'
      AND m.provider_timestamp < ufm.first_message_date + INTERVAL '14 days'
      THEN m.id
    END) as week2_messages,
    -- Month 1 metrics
    COUNT(DISTINCT CASE
      WHEN m.provider_timestamp >= ufm.first_message_date
      AND m.provider_timestamp < ufm.first_message_date + INTERVAL '30 days'
      THEN m.id
    END) as month1_messages,
    -- Current / lifetime metrics (for Super Power User)
    COUNT(DISTINCT m.id) as total_messages,
    COUNT(DISTINCT CASE
      WHEN m.provider_timestamp >= NOW() - INTERVAL '7 days'
      THEN m.id
    END) as messages_last_7d,
    EXTRACT(EPOCH FROM (NOW() - ufm.first_message_date))/86400 as days_tenure
  FROM user_first_messages ufm
  JOIN person_contacts pc ON pc.person_id = ufm.person_id
  JOIN message m ON m.sender_person_contact_id = pc.id
  GROUP BY ufm.person_id, ufm.name, ufm.first_message_date
)
SELECT
  funnel_step,
  users,
  ROUND(100.0 * users::numeric / (SELECT COUNT(*) FROM user_first_messages), 1) as pct_of_start,
  ROUND(100.0 * users::numeric / LAG(users) OVER (ORDER BY step_num), 1) as conversion,
  ROUND(100.0 * (LAG(users) OVER (ORDER BY step_num) - users)::numeric / LAG(users) OVER (ORDER BY step_num), 1) as drop_off
FROM (
  SELECT 1 as step_num, 'Step 1: First Message Sent' as funnel_step, COUNT(*) as users
  FROM user_first_messages

  UNION ALL

  SELECT 2, 'Step 2: 5+ Messages Week 1', COUNT(CASE WHEN week1_messages >= 5 THEN 1 END)
  FROM user_complete_behavior

  UNION ALL

  SELECT 3, 'Step 3: Active 5+ Days Week 1', COUNT(CASE WHEN days_active_week1 >= 5 THEN 1 END)
  FROM user_complete_behavior

  UNION ALL

  SELECT 4, 'Step 4: Week 2 Retained', COUNT(CASE WHEN week2_messages > 0 THEN 1 END)
  FROM user_complete_behavior

  UNION ALL

  SELECT 5, 'Step 5: 100+ Messages Month 1', COUNT(CASE WHEN month1_messages >= 100 THEN 1 END)
  FROM user_complete_behavior

  UNION ALL

  SELECT 6, 'Step 6: Power User (50+ msgs Week 1 + 5+ days)',
         COUNT(CASE WHEN week1_messages >= 50 AND days_active_week1 >= 5 THEN 1 END)
  FROM user_complete_behavior

  UNION ALL

  SELECT 7, 'Step 7: Super Power User (50+ last 7d + 500+ lifetime + 60+ days)',
         COUNT(CASE WHEN messages_last_7d >= 50 AND total_messages >= 500 AND days_tenure >= 60 THEN 1 END)
  FROM user_complete_behavior
) funnel_data
ORDER BY step_num;
```

**What this shows:**
- Complete user journey from signup to super power user
- Critical activation milestones (5+ messages, 5+ days active)
- Retention signals (week 2 engagement)
- Volume thresholds (100+ messages month 1)
- Early activation metric (power user: 50+ Week 1 + 5+ days)
- Ultimate retention metric (super power user: aged + sustained high engagement)

**Interpretation:**
- **Low Step 1 → Step 2**: Users try once but don't engage (improve first experience)
- **Low Step 2 → Step 3**: Users message but don't build daily habit (focus on consistency)
- **Low Step 3 → Step 6**: Consistent users don't reach high volume (encourage more messaging)
- **Step 6 → Step 7 retention**: Track how many power users sustain to become super power users (retention challenge)

## Finding Activation Thresholds

**Goal:** Identify what metrics predict long-term engagement (becoming a power user).

**Method:** Compare power users vs. non-power users to find the activation threshold.

### Step 1: Define Power Users

```sql
-- Define power users based on current engagement
WITH user_message_stats AS (
  SELECT
    p.id as person_id,
    COUNT(DISTINCT m.id) as total_messages,
    COUNT(DISTINCT CASE WHEN m.provider_timestamp >= NOW() - INTERVAL '7 days' THEN m.id END) as messages_last_7d,
    EXTRACT(EPOCH FROM (NOW() - MIN(m.provider_timestamp)))/86400 as days_since_first_msg
  FROM persons p
  JOIN person_contacts pc ON pc.person_id = p.id
  JOIN message m ON m.sender_person_contact_id = pc.id
  GROUP BY p.id
)
SELECT
  CASE
    WHEN messages_last_7d >= 50 OR total_messages >= 500 THEN 'Power User'
    WHEN days_since_first_msg >= 60 AND total_messages >= 10 THEN 'Old Non-Power'
    ELSE 'Other'
  END as user_type,
  COUNT(*) as count
FROM user_message_stats
GROUP BY user_type;
```

### Step 2: Compare First Week Behavior

```sql
-- Compare what power users did in week 1 vs. non-power users
WITH user_classification AS (
  -- [Same as above to classify users]
),
first_week_analysis AS (
  SELECT
    uc.user_type,
    COUNT(DISTINCT m.id) as week1_messages,
    COUNT(DISTINCT DATE(m.provider_timestamp)) as days_active_week1
  FROM user_classification uc
  JOIN person_contacts pc ON pc.person_id = uc.person_id
  JOIN message m ON m.sender_person_contact_id = pc.id
  WHERE m.provider_timestamp >= [first_message_date]
    AND m.provider_timestamp < [first_message_date] + INTERVAL '7 days'
  GROUP BY uc.person_id, uc.user_type
)
SELECT
  user_type,
  COUNT(*) as total_users,
  ROUND(AVG(week1_messages)::numeric, 1) as avg_week1_msgs,
  ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY week1_messages)::numeric, 1) as median_week1_msgs,
  COUNT(CASE WHEN days_active_week1 >= 5 THEN 1 END) as achieved_5_days,
  ROUND(100.0 * COUNT(CASE WHEN days_active_week1 >= 5 THEN 1 END)::numeric / COUNT(*), 1) as pct_5_days,
  COUNT(CASE WHEN week1_messages >= 50 THEN 1 END) as achieved_50_msgs,
  ROUND(100.0 * COUNT(CASE WHEN week1_messages >= 50 THEN 1 END)::numeric / COUNT(*), 1) as pct_50_msgs
FROM first_week_analysis
GROUP BY user_type;
```

### Step 3: Find the Threshold

**Look for metrics where power users are significantly different (2-3x more likely):**

Example results:
| Metric | Power Users | Non-Power (60+ days) | Ratio |
|--------|------------|---------------------|--------|
| 5 Days Active Week 1 | 78.8% | 25.3% | **3.1x** |
| 50+ Messages Week 1 | 54.5% | 10.3% | **5.3x** |
| Both (50+ msgs + 5+ days) | 48.5% | 9.2% | **5.3x** |

**Threshold found:** 50+ messages in week 1 AND 5+ days active predicts power users with 5.3x accuracy.

### Step 4: Validate False Positives

Check how many non-power users achieved the threshold (false positive rate):

- **"5+ Days Active" alone:** 25.3% false positive rate (too high)
- **"50+ Messages" alone:** 10.3% false positive rate (good)
- **"Both combined":** 9.2% false positive rate (best predictor)

**Recommendation:** Use the combined threshold (50+ messages AND 5+ days) as your power user activation metric.

## Real Production Examples

### Example 4: Complete Activation Funnel Results

**Query results:**
| Step | Milestone | Users | % of Start | Drop-off |
|------|-----------|-------|-----------|----------|
| 1 | First Message Sent | 163 | 100.0% | - |
| 2 | 5+ Messages Week 1 | 110 | 67.5% | **32.5%** |
| 3 | Active 5+ Days Week 1 | 51 | 31.3% | **53.6%** ← Biggest |
| 4 | Week 2 Retained | 74 | 45.4% | - |
| 5 | 100+ Messages Month 1 | 41 | 25.2% | - |
| 6 | Power User | 24 | **14.7%** | - |
| 7 | Super Power User | 14 | **8.6%** | - |

**Insights:**

1. **8.6% ultimate retention rate**: Only 14 out of 163 users become super power users
   - **Super Power User = 50+ msgs last 7d + 500+ lifetime + 60+ days tenure**
   - These are the "aged super power users" with sustained high engagement
   - **Ultimate North Star** to track long-term product success

2. **14.7% early activation rate**: 24 users become power users in Week 1
   - **Power User = 50+ messages in Week 1 AND 5+ days active**
   - **Leading indicator** - can identify by day 7
   - **Target:** Increase to 25% (70% improvement)

3. **Power User → Super Power User retention: 58%**
   - 24 users activated as power users in Week 1
   - Only 14 sustained to become super power users (58% retention)
   - **10 users churned** despite strong Week 1 start
   - **Retention challenge:** Keep power users engaged long-term

4. **Biggest bottleneck: Step 2 → Step 3 (53.6% drop-off)**
   - 110 users sent 5+ messages, but only 51 came back 5+ days
   - **Problem:** Users engage in bursts, not consistently
   - **Fix:** Daily streak notifications, "Can you use the product 5 days this week?" challenge
   - **Impact:** If 50% of 5+ message users hit 5+ days (vs current 46%), would increase power users from 24 to ~41 (+71%)

5. **Multiple paths to engagement:**
   - **Fast Track (14.7%):** 50+ messages + 5+ days in week 1 → Power User
   - **Slow Burn (30.6%):** Lower week 1 → Week 2 retention → Build up over month
   - **Don't give up on slow starters** - 45.4% come back in week 2

6. **The activation threshold:**
   - **Power User = 50+ messages in Week 1 AND 5+ days active**
   - This metric is 5.3x more predictive than other metrics
   - Only 9.2% false positive rate (non-power users who achieve this)

**Actions:**

1. **Track TWO North Star metrics:**
   - **Week 1 Power User Rate (14.7%)** - early activation leading indicator
   - **Super Power User Rate (8.6%)** - ultimate retention goal

2. **Day 3-5 intervention** for users who sent 5+ messages but aren't hitting 5 days active

3. **Daily engagement prompts** days 1-7 to build consistency habit

4. **Celebrate streaks:** "3 day streak! 🔥", "Keep it going!"

5. **Power user retention program:** Special engagement for users who hit Week 1 power user threshold to sustain them to super power status

6. **A/B test** different prompting strategies to improve consistency

## Notes

- **Keep funnels simple** - Aim for 6-7 steps for clarity (you can always add detail later)
- **Always start with the simplest funnel** - 3-4 steps to identify the biggest bottleneck
- **Consider TWO end states** when appropriate:
  - **Early activation** (e.g., Power User in Week 1) - leading indicator
  - **Long-term retention** (e.g., Super Power User after 60+ days) - ultimate success metric
- **Segment, segment, segment** - Overall metrics hide important patterns
- **Focus on the bottleneck** - Fixing it has biggest impact
- **Interview stuck users** - Qualitative data explains WHY
- **Measure time to convert** - Reveals urgency and engagement
- **Track trends over time** - Are funnels improving or declining?
- **Find activation thresholds** - Compare power vs non-power users to identify what predicts success
- **Validate with false positives** - Check how many non-power users achieved your threshold
- **Track retention between milestones** - e.g., What % of power users sustain to super power status?

Remember: Good funnel analysis doesn't just count drop-offs - it explains WHY users drop off and HOW to fix it.
