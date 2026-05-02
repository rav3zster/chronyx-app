# Chronyx

AI-powered productivity tracking app — Chronyx helps you track time,
set goals, view analytics, and receive AI-driven insights to improve focus.

## Features

- Time tracking (start/stop sessions)
- Goals system (daily targets, streaks)
- Analytics (Wrapped-style summaries and top tasks)
- AI Coach (rule-based insights and suggestions)

## Tech stack

- Flutter (UI)
- Riverpod (state management)
- Supabase (Postgres + Auth)
- Clean Architecture (feature-first: data / domain / presentation)

## Project Structure

This repository follows a feature-first layout. Each feature folder groups
its own `data`, `domain`, and `presentation` layers, for example:

- `lib/features/time_tracking/data/...` — datasources, models
- `lib/features/time_tracking/domain/...` — entities, repositories
- `lib/features/time_tracking/presentation/...` — providers, pages, widgets

This keeps feature code modular, easy to test, and straightforward to
navigate when adding or removing features.

## Screenshots (placeholders)

> Replace these with real screenshots before publishing.

- Dashboard: `assets/screenshots/dashboard.png`
- Goals: `assets/screenshots/goals.png`
- Analytics: `assets/screenshots/analytics.png`
- AI Coach: `assets/screenshots/ai_coach.png`

## How to run

Set your Supabase credentials and run the app with Flutter. Example (Windows/macOS/Linux):

```bash
flutter run -d <device> \
	--dart-define=SUPABASE_URL=https://your-project.supabase.co \
	--dart-define=SUPABASE_ANON_KEY=your_anon_key
```

Notes:

- Replace `<device>` with a target (e.g., `chrome`, `android`, `ios`).
- You can also set environment variables in your IDE's run configuration.

## Future improvements

- Integrate LLM-based AI suggestions (server-side or client-side)
- Push notifications for goals and reminders
- Cross-device sync improvements and conflict resolution

---

If you want, I can add ready-to-use screenshot placeholders, update `pubspec.yaml`
assets, and create a short project demo GIF to include in this README.

