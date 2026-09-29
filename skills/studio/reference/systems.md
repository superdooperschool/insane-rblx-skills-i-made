# systems — the interrogation

Load this when the task is a system that does not exist yet. Ask all four groups and keep asking
until the answers are unambiguous. The user wants to be pushed for specifics: a vague answer
("make it good", "a normal amount") gets a follow-up with concrete options, never a guess.

Do not write code until every answer is a number, a path, or a name.

## 1. Data and persistence

- Does this save? Which DataStore key or profile field?
- What happens to players who already have data: migration, or default?
- Attribute or child `Configuration`? One instance holds only **1024 bytes of attributes total**,
  and past the cap `SetAttribute` silently refuses, so the symptom is that the LAST attribute
  written vanishes. A child `Configuration` gets its own 1024 bytes.
- Anything created on join means client readers must rebind through `ChildAdded`, because client
  scripts load before the server has finished setting up the player.

## 2. Server authority and exploit surface

- Who validates? Server decides. The client sends intent only, never values.
- Every new RemoteEvent is new attack surface. What is the rate limit, what is the payload cap,
  and what does a spammed call cost the server?
- Can the client reach the reward without doing the work?
- Anything the client can compute, an exploiter can fake. Anything the server does not check, it
  has accepted.

## 3. Where instances live

- Built from the EDIT datamodel (persists) or at server boot (resets every restart)? World
  geometry belongs in Edit-callable builder modules, not inline in a service.
- Which folder, exact path.
- Who authors the visuals: the user or this skill? Default is that the skill authors structure
  and the user restyles.

## 4. Balance and config

- Real numbers into the config module up front: prices, level gates, rates, caps.
- How it interacts with the existing progression spine: levels, rebirth, currencies, skill trees.
- Watch for a config module whose in-file tuning table beats the explorer Value instances
  **silently**. Read the getter order before telling the user a number is live.

## Then

Write the playtest list (3-6 bullets). If a bullet cannot be written, something above is still
unanswered. Only then start editing.
