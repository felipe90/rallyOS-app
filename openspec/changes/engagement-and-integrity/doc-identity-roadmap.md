# Roadmap: Trusted Athletes (Post-MVP)

## Intent

As RallyOS scales, the risk of "Identity Manipulation" (Smurfing, multi-accounting) grows. While the MVP prioritizes ease of entry over strict verification, this document outlines the long-term vision to ensure competitive integrity.

## Strategic Pillars

### 1. Social Trust (Peer Validation)

- **The Concept**: "Crowdsourced Identity."
- **Implementation**:
    - **Vouching System**: New accounts start in "UNVOUCHED" status. They need 3 validated players (Gold rank or higher) to "Vouch" for them after a match to unlock full tournament privileges.
    - **Community Karma**: Players who vouch for a Smurf also lose "Karma points" if that Smurf is later banned.

### 2. Social Linked Accounts

- **The Concept**: Tie the athlete's ID to their real-world persona.
- **Implementation**:
    - **OAuth Enforced**: Support linking to Instagram/WhatsApp for profile public display.
    - **Verified Icons**: A "Blue Checkmark" for users who have linked an account or provided a National ID.

### 3. AI-Based Anomaly Detection

- **The Concept**: Systematic ELO monitoring.
- **Implementation**:
    - Flag accounts that perform drastically better than their initial self-reported skill level.
    - Automatic "Promotion" to higher categories if a player wins a 500-ELO category tournament with 0 sets lost.

### 4. Biometric (High-End Events)

- **The Concept**: Face-ID or In-Person verification.
- **Implementation**:
    - For professional tournaments (prize pool involved), the Organizer MUST perform an on-site check-in using the app's camera etc.

## Current MVP Mitigation

- **Manual Audit**: Organizers have the authority to BAN or REMOVE entries that they suspect are Smurfs.
- **ELO Correction**: The `rollback_match()` function can be used to re-adjust ratings if an identity fraud is discovered mid-tournament.
