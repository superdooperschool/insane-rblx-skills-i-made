---
name: retention-engine
description: Use when designing, auditing or improving anything people are meant to come BACK to - a game, an app, a dashboard, a SaaS onboarding, a tool. Triggers include "why do people churn", "make this addictive", "improve retention", "D1/D7", "make people come back", "engagement", "the game is boring after X minutes", or any request to make a product sticky. Scores the thing on 15 questions and names the single missing structural piece.
---

# Retention Engine

When the audit below finds a gap, build the missing piece.

## The one thing to check first

**Time-scale lamination.** List every loop in the product and its period. You need loops at roughly
1s, 1m, 10m, 1h, 1d, 1w — each about 10x the last. Loops with *similar* periods synchronise, complete
together and produce a clean exit. Loops spaced 10x apart are almost never simultaneously idle, so the
user is permanently mid-flight.

Nine times out of ten, a thing that does not retain has **only one time scale**. Find that before
suggesting anything else. It is a scheduling property, not content, so it is cheap to fix and
expensive to skip.

## Pull vs push

- **Pull** — the next minute is genuinely worth more (mastery, discovery, a wanted reward). Scales
  forever, generates word of mouth.
- **Push** — stopping costs something (expiring timers, breaking streaks, decay). Works fast, has a
  ceiling, and past a point converts users into resentful ex-users.

**Target 80% pull.** Count the push mechanics out loud in any recommendation you make.

## The loop must have four beats

Trigger → Action → **Variable** reward → **Investment**.

- No variance in the reward = it is a job. The response tracks prediction error, not magnitude.
- No investment beat = it is a treadmill. Investment is what makes loop N+1 better than loop N, and
  it is the beat almost every failed product skips.

## The audit (score 0-2 each, be harsh)

1. Core action easy at minute 1, still improvable at hour 200?
2. Does every loop end with an investment that improves the next one?
3. Loops at 1s / 1m / 10m / 1h / 1d / 1w? Name them. Which are missing?
4. Is there a visible unfinished thing at every moment?
5. Something valuable the user can see but not yet have?
6. Any variable reward, with near miss shown and a pity floor?
7. A set with visible holes in it?
8. Persistent visible choices that differ between users?
9. Can the user tell they are getting better?
10. A reason to return tomorrow specifically?
11. A reason to be present at a particular time?
12. Anything undocumented worth writing down and sharing? (this is free distribution)
13. Do other users' actions ever become visible?
14. Push mechanics under 20% of total?
15. Is it still good for someone who pays nothing and misses a week?

**Under 20/30 it does not retain**, regardless of content quality. Report the score, then name the
*single* highest-leverage missing piece rather than listing all of them.

## Three cliffs, three different fixes

- **Bounce (first 90s)** — confusion or bad performance. Fix onboarding and frame rate/latency.
- **Session 2 (D1)** — nothing happened while they were away, nothing tells them what to do on
  return. Fix with long timers that matured plus an explicit next task.
- **Week 2 (D7)** — they solved it. Fix with collection, optional deep systems, discovery.

Most teams fix the first, ignore the second, never reach the third. **Diagnose which cliff before
proposing anything.**

## The line (non-negotiable)

Never recommend: paid randomness, punishing absence with loss, manufactured scarcity pressuring
immediate spend, or anything that makes a user feel they will lose what they have unless they pay or
return. Especially where the audience includes minors.

Test: does the mechanic make the product better for someone who spends nothing and misses a week? If
it makes their experience actively worse rather than merely slower, do not ship it.

## Output shape

Do not dump all 15 answers. Produce:
1. The score.
2. Which cliff is the actual bottleneck, with the evidence.
3. **One** structural fix, with what to build and how to measure it moved.
4. What to instrument so it becomes a number instead of an opinion.
