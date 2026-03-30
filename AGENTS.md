# AGENTS.md — RallyOS Application Repository

This repository contains the source code for the RallyOS mobile application and Supabase backend.

## AI Steering Context

**CRITICAL:** This repository contains the *implementation* only. The full architectural context, design specs, and specialized AI skills are located in the local knowledge base:

> **Knowledge Base Path:** `../rallyOS/`
> **Primary Specs:** `../rallyOS/docs/`
> **AI Skills:** `../rallyOS/.ai/skills/`

**Load the following skills from the knowledge base before major changes:**
- UI/UX: `../rallyOS/.ai/skills/mobile-ui-agent/SKILL.md`
- Data/Sync: `../rallyOS/.ai/skills/offline-state-agent/SKILL.md`
- Database/RLS: `../rallyOS/.ai/skills/supabase-db-agent/SKILL.md`

---

## Tech Stack
- Frontend: React Native (Expo) + NativeWind
- Backend: Supabase (PostgreSQL + Edge Functions)
- State: TanStack Query + Zustand
- Strategy: Offline-First / Spec-Driven Development

---

## Getting Started (Local DB)
1. Ensure Docker is running.
2. Run `supabase start`.
3. Run `supabase db reset` to apply migrations and seed data.
4. Run security tests: `psql postgres://postgres:postgres@localhost:54322/postgres -f supabase/tests/security_tests.sql`
