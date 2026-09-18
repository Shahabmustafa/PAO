# PAO

**PAO** (پاؤ) is a give-away marketplace app — post items you no longer need for free, browse what others are giving away, and arrange the handoff through in-app chat.

## Features

- **Give & Get** — post an item with photos, category and condition; browse and request items others have posted
- **Requests & Chat** — send a "Give Me" request, chat with the owner, and accept a request to hand an item over
- **Wishlist** — save items you're interested in for later
- **Profiles & Feedback** — public profiles with donation count and star ratings/reviews after an exchange
- **Location** — filter listings by province
- **Real-time updates** — listings and requests refresh live via Supabase Realtime
- **Light & dark themes**, with the choice remembered between sessions
- **Account management** — edit profile, and fully delete your account and data at any time

## Tech Stack

- [Flutter](https://flutter.dev) — cross-platform app (Android, iOS)
- [Supabase](https://supabase.com) — auth, Postgres database, storage, and realtime
- [Provider](https://pub.dev/packages/provider) — state management

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (see `environment.sdk` in `pubspec.yaml` for the required version)
- A [Supabase](https://supabase.com) project

### Setup

1. Clone the repo and install dependencies:

   ```bash
   git clone git@github.com:Shahabmustafa/PAO.git
   cd PAO
   flutter pub get
   ```

2. Copy `.env.example` to `.env` and fill in your Supabase project's URL and anon key:

   ```bash
   cp .env.example .env
   ```

3. In the Supabase SQL editor, run each script under [`supabase/`](supabase) (in the order listed there) to create the required tables, views, storage buckets, and RLS policies.

4. Run the app:

   ```bash
   flutter run
   ```

## Project Structure

The app follows a feature-first structure under `lib/features/`, where each feature (e.g. `home`, `auth`, `chat`, `requests`) has its own `data/` (models, repositories, Supabase datasources) and `presentation/` (screens, providers, widgets) layers. Shared code — theming, reusable widgets, routing — lives under `lib/core/`.
