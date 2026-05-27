# Chronyx — Product Direction (Source of Truth)

## Platform Priority

**Chronyx is Android-first.**

| Platform | Status | Use case |
|----------|--------|----------|
| Android  | ✅ Primary | Tracking, habits, focus, roadmap execution, AI coach. Full feature set. |
| Web      | 🟡 Deferred | Eventually used for analytics viewing, roadmap planning, account sync. NOT for heavy tracking. |
| iOS      | 🟡 Deferred | Possible later. Auto usage tracking will not work (Apple does not expose Screen Time). |
| Desktop  | 🟡 Optional | Permission-based productivity tracking only, opt-in. Not a launch target. |

## Implications

- **Do NOT optimize for Flutter Web** in new work. Web compatibility should remain non-breaking, but no feature should be blocked waiting for web support.
- **Prefer mobile-native interactions**: bottom sheets, haptics, swipe gestures, system back, edge-to-edge. Touch-first sizing.
- **Test responsive layouts on phone-shaped viewports first**, then verify they don't break on tablet/desktop.
- **Performance budget**: target mid-tier Android devices (Snapdragon 7-class, 4GB RAM). Avoid expensive blur stacks, large image rebuilds, infinite repeating animations on screen entry.
- **Native plugins are encouraged** when needed for Android features (e.g. `UsageStatsManager`, haptics, foreground services). Wrap in abstractions so web can no-op.

## Feature Priority Order

1. Android UX quality
2. Mobile responsiveness on phones (then tablets)
3. Native-feeling interactions (haptics, transitions, edge-to-edge)
4. Performance on Android devices
5. Clean mobile navigation

## Future: Smart Usage Tracking (v2 — DEFERRED)

Once core Chronyx is complete, add Android-only auto usage tracking:

- Use `UsageStatsManager` (Android system API) — no background service needed
- Read foreground time only — never count backgrounded apps
- Require explicit `PACKAGE_USAGE_STATS` permission via Settings flow
- Categorize apps into: **productive / learning / distraction / neutral**
- Smart defaults + per-app override
- Local storage first; Supabase sync later
- Integrate into existing analytics, life insights, AI coach as a second data source alongside manual sessions
- Web/iOS: graceful "Available on Android" placeholder

**Do NOT implement v2 yet.** Architecture extension points exist in `lib/features/app_usage/` (skeleton only). Implementation begins after the current core experience phases land.

## Current Priority

Finish Chronyx core experience and dashboard intelligence:
- Delight & personality (Phase 3) — in progress
- Page transitions, Today Focus card evolution, smart onboarding empty states
- Reliability + session quality polish

Defer all v2 work (auto tracking, desktop, iOS) until core feels complete.
