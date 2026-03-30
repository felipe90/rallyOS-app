# SDD Spec: Tournament Registration (Attendee)

- **Status:** DRAFT
- **Phase:** SPECIFICATION
- **Owner:** rallyos-orchestrator
- **Linked Skills:** `supabase-db-agent`, `mobile-ui-agent`, `edge-functions-agent`

---

## 1. Goal
Provide a seamless, high-integrity registration flow for athletes. Ensure that entries are only confirmed once payment is validated via webhook.

## 2. Triggers
- User taps "Register" on a Tournament Dashboard card.
- User selects a category.
- User completes payment via Stripe/Mercado Pago.

## 3. High-Level Requirements

| Req ID | Requirement | Agent |
|---|---|---|
| R-1 | Create `tournament_entries` as `PENDING_PAYMENT` initially. | `supabase-db-agent` |
| R-2 | Launch Payment Sheet (Stripe/MP). | `mobile-ui-agent` |
| R-3 | Handle webhook to set status to `CONFIRMED`. | `edge-functions-agent` |
| R-4 | Optimistic UI update for the athlete. | `offline-state-agent` |

---

## 4. Scenarios

### Scenario A: Successful Registration (Happy Path)
- **Given:** Athlete is authenticated and has a valid profile.
- **And:** Tournament "Copa Medellín" is in `REGISTRATION` status.
- **When:** Athlete clicks "Join Singles A" and completes payment.
- **Then:** Resulting `tournament_entry` is updated to `status: CONFIRMED`.
- **And:** A new event is added to the `community_feed`.

### Scenario B: Payment Failed
- **Given:** Athlete initiates registration.
- **When:** Payment is declined or aborted by the user.
- **Then:** `tournament_entry` remains `REQUIRES_PAYMENT`.
- **And:** The athlete is prompted to retry from the Dashboard.

---

## 5. Security Guardrails (Security-Auditor)

- [ ] **No Manual Bypass:** Ensure no client can bypass the `payments` check to confirm an entry.
- [ ] **Category ELO Check:** Verify the athlete's ELO matches the category `elo_min`/`elo_max` before allowing registration.

---

## 6. Next Tasks (Task-Tracker)

1. [ ] Implement `check_elo_registration_trigger` (SQL)
2. [ ] Create `RegistrationScreen.tsx` (UI)
3. [ ] Configure Stripe Payment Webhook (Edge)
