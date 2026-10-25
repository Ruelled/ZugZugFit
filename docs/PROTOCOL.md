# ZugZugFit guild protocol v2

Prefix `ZugZugFit2`; channel `GUILD` only. Both sender and receiver must enable sharing for their current guild. Receiver accepts only roster members, ignores self and stores caches per guild. No whisper transport, backend, or peer-data relay.

## Snapshot

Header: `2|participant|revision|reported-local-day|epoch-seconds|escaped-display-name`

Remaining newline-delimited rows: `YYYY-MM-DD|escaped-normalized-activity|unit|amount`

Units: `reps`, `minutes`, `sessions`. Activity labels normalize whitespace/case through the same model used for ranking. Non-simple field bytes are percent-encoded. Amounts serialize to four decimal places. Snapshots contain aggregated positive totals from today and 100 preceding local dates; deleted logs are omitted. No notes, schedule details or individual workout timestamps are transmitted.

Maximum 2,000 buckets, 72,000 snapshot bytes, 400 fragments, 180 bytes of payload per fragment. Native packet length is checked against 255 bytes. Unrepresentable oversized snapshots fail rather than silently truncating results. The current payload rounding can lose fractions below 0.0001 units.

Data envelope: `D|transfer-id|index|count|payload-fragment`. Fragments can arrive out of order, duplicates are idempotent, conflicting fragments abort that transfer. At most 32 active sender buffers, expiring after 900 seconds. Apply only complete validated snapshots. Validate all dates, finite bounded amounts, units, IDs, duplicate buckets and header values. No executable deserialization.

A higher revision replaces previous totals. Equal revision with a newer snapshot timestamp refreshes it; older revisions/timestamps cannot overwrite newer data. Corrections, deletions and backfills thus replace rather than add. Participant IDs are generated and stored once in account SavedVariables; alts share them. IDs are claims, not authenticated Battle.net identities. Peers can lie about exercise or identity; the product intentionally provides no anti-cheat guarantees.

## Requests and withdrawal

`Q|2` asks online peers to publish their own snapshots. Local requests are limited to one every 120 seconds. Receiver rate-limits per sender and delays its response; own snapshots are no more frequent than every 60 seconds. Send pacing is one packet/second. Combat/chat restrictions defer sending. Three failed attempts discard a queued transfer and allow a later retry. Guild changes clear queues and buffers.

`X|participant|revision` withdraws a known peer. It is accepted only from a sender previously observed for that participant at an adequate revision. A tombstone rejects replayed older snapshots. Enabling sharing again increments revision. Withdrawal is best effort for online users; it cannot erase offline copies or externally captured data.

Maximum 500 cached participants; stale receipts are pruned after 100 days. Rankings filter current roster membership. Cache size limits can make large guild boards incomplete. Per-guild consent persists. The current implementation has no central discovery/complete-board guarantee and no cross-computer identity merge.

## Challenges

`C|ZC1~id~by~fromName~activity~unitcode~amount~start~finish~icon` announces a challenge. The same `ZC1~...` code is in the chat link. Fields are escaped like share codes. Receivers keep at most 200 challenges and ignore challenges that ended more than 30 days ago. Each publish repeats the sender's active challenges, so a guildmate who logs in later also gets them.

`A|challenge-id|participant|escaped-display-name` tells the guild that a participant accepted a challenge. Challenge progress is not sent separately. Receivers compute it from the snapshot rows of each participant for the challenge activity, unit and dates. Older clients ignore unknown message types.

## Periods and privacy

Monday-start weeks, calendar months and trailing three calendar months are calculated from reported local dates. No realm timestamp is invented for date-only gym backfills. The board separates activity and unit, displays receipt freshness, and may be stale while members are offline. Enabling sharing covers all activity categories in the snapshot range; the UI offers no category-specific privacy filtering. Public announcements use a separate opt-in and queue.

Source references and offline/client evidence boundaries: [development plan](DEVELOPMENT-PLAN.md), [test matrix](TEST-MATRIX.md).
