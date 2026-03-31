# RallyOS — Open-Source Tournament Engine

RallyOS is a professional, offline-first tournament management platform designed for amateur racket sports (Padel, Tennis, Pickleball, etc.). 

It focuses on high-performance refereeing, real-time social engagement, and robust ELO-based matchmaking, even in environments with poor connectivity.

## 🚀 Tech Stack

- **Mobile:** React Native + Expo + NativeWind (Tailwind CSS)
- **Backend:** Supabase (PostgreSQL + Edge Functions + Realtime)
- **Local State:** TanStack Query (Optimistic UI) + Zustand + SQLite
- **Architecture:** Spec-Driven Development (SDD) & Offline-First

## 📊 Project Status

### MVP Backend: ✅ COMPLETE

```yaml
Security (RLS):      ✅ 13 tables protected
Tournament Flow:    ✅ Free tournaments, check-in, brackets
ELO Calculation:     ✅ Automatic with K-factor
Bracket System:     ✅ Single elimination with seeding
Clubs:              ✅ Organization management
Community Feed:     ✅ Activity feed with auto-events
──────────────────────────────────────
Mobile App:         🔲 Pending
Payment Flow:      🔲 Post-MVP
```

### Specs & Migrations

```yaml
Specs:         21 created
Use Cases:    10 verbose
Migrations:    18 applied
```

## 🧠 AI-First Development

This repository is optimized for AI-assisted development.
- **`AGENTS.md`**: Provides immediate context for AI coding agents.
- **Local Docs**: `webdocs/` - RallyOS documentation with Mermaid diagrams

## 🛠 Getting Started

### Prerequisites

- [Node.js](https://nodejs.org/) (v20+)
- [Docker](https://www.docker.com/) (required for local Supabase)
- [Supabase CLI](https://supabase.com/docs/guides/cli)

### Local Database Setup

1. **Start Supabase:**
   ```bash
   supabase start
   ```

2. **Reset & Seed:**
   ```bash
   supabase db reset
   ```
   *This applies all migrations and loads the "Copa Pádel Medellín 2026" test scenario.*

3. **Verify Security:**
   ```bash
   psql postgres://postgres:postgres@localhost:54322/postgres -f supabase/tests/security_tests.sql
   ```

## 📜 Principles

- **Offline-First:** All actions are optimistic and queued if the network is down.
- **Integrity:** Financial and competitive integrity (ELO) is enforced by database triggers and RLS, not the client.
- **Tactile:** The UI is designed for outdoor usability with high contrast and massive touch targets.

## 📖 Documentation

- **Local Docs**: http://localhost:3000 (run `cd webdocs && python3 -m http.server 3000`)
- **Specs**: `openspec/changes/mvp-tournament-flow/specs/`
- **Use Cases**: `openspec/changes/mvp-tournament-flow/usecases/`

---
*Built with ❤️ by Raikenwolf & the RallyOS Community.*
