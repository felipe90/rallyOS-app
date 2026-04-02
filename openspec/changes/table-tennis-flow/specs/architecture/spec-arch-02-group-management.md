# SPEC-ARCH-02: Architecture - Group Management

## Purpose

Definir la arquitectura del frontend para crear y administrar Round Robin Groups.

---

## Core Components

### 1. Group Creation Flow

```
┌─────────────────────────────────────────────────────────────┐
│                   CREATE GROUP MODAL                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Group Name: [A ▼]  (or custom: [___])                    │
│                                                             │
│  ─────────────────────────────────────────────────────     │
│                                                             │
│  Available Players (not in any group):                     │
│  ┌─────────────────────────────────────────────────────┐  │
│  │ ⭐ P1 (Seed 1) - ELO 1850        [+ Add]            │  │
│  │ ⭐ P5 (Seed 2) - ELO 1720         [+ Add]            │  │
│  │   P3 - ELO 1650                   [+ Add]            │  │
│  │   P7 - ELO 1580                   [+ Add]            │  │
│  │   P9 - ELO 1420                   [+ Add]            │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                             │
│  ─────────────────────────────────────────────────────     │
│                                                             │
│  Group Members (3-5 required):                             │
│  ┌─────────────────────────────────────────────────────┐  │
│  │ 1. ⭐ [P1] - Head of Group          [Remove]        │  │
│  │ 2. [P5]                             [Remove]        │  │
│  │ 3. [P3]                             [Remove]        │  │
│  │ 4. [P7]                             [Remove]        │  │
│  │                                                       │  │
│  │ [Empty Slot]                                   [Add] │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                             │
│  Matches to generate: 6                                    │
│                                                             │
│  [Cancel]                                    [Create Group] │
└─────────────────────────────────────────────────────────────┘
```

### 2. Seeding Algorithm

```typescript
interface SeedingService {
  /**
   * Automatically seed players into groups
   * ensuring heads of groups are separated
   */
  autoSeed(
    players: Player[],
    groupCount: number
  ): SeedAssignment[];
  
  /**
   * Suggest optimal group distribution
   * based on ELO/ranking
   */
  suggestDistribution(
    players: Player[],
    groups: RoundRobinGroup[]
  ): Suggestion[];
}

interface SeedAssignment {
  player: Player;
  groupId: string;
  seed: number; // 1 = head
  reason: string;
}
```

### 3. Group List View

```
┌─────────────────────────────────────────────────────────────┐
│  GROUPS                                    [+ New Group]     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────────────────────────────────────┐  │
│  │ GROUP A                              ⚙️ Edit  🗑️    │  │
│  │ ──────────────────────────────────────────────────   │  │
│  │ ⭐ P1 (Head) - ELO 1850                              │  │
│  │   P2 - ELO 1720                                      │  │
│  │   P3 - ELO 1650                                      │  │
│  │   P4 - ELO 1580                                      │  │
│  │                                                      │  │
│  │ Status: PENDING (4/6 matches)                       │  │
│  │ [View Matches]                                      │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐  │
│  │ GROUP B                              ⚙️ Edit  🗑️    │  │
│  │ ──────────────────────────────────────────────────   │  │
│  │ ⭐ P5 (Head) - ELO 1820                              │  │
│  │   P6 - ELO 1700                                      │  │
│  │   P7 - ELO 1620                                      │  │
│  │   P8 - ELO 1550                                      │  │
│  │                                                      │  │
│  │ Status: IN_PROGRESS (2/6 matches)                  │  │
│  │ [View Matches]                                      │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                             │
│  [Generate Bracket from Groups]                            │
└─────────────────────────────────────────────────────────────┘
```

---

## API Endpoints

### POST /tournaments/:id/groups

Create a new Round Robin group.

```typescript
interface CreateGroupRequest {
  name: string;
  member_entry_ids: string[];
  advancement_count?: number; // default: 2
}

interface CreateGroupResponse {
  group: RoundRobinGroup;
  matches: Match[];
  message: string;
}
```

### PATCH /groups/:id

Update group (add/remove members, change name).

```typescript
interface UpdateGroupRequest {
  name?: string;
  // Member changes handled via separate endpoints
}

interface AddMemberRequest {
  entry_id: string;
  seed?: number;
}

interface RemoveMemberRequest {
  member_id: string;
}
```

### DELETE /groups/:id

Delete group and all its matches.

```typescript
// Returns confirmation dialog data
interface DeleteGroupResponse {
  group_name: string;
  members_count: number;
  matches_count: number;
  warning: string; // "This will delete 6 matches"
}
```

### POST /tournaments/:id/groups/auto-seed

Auto-generate groups based on seeding algorithm.

```typescript
interface AutoSeedRequest {
  group_count: number;
  members_per_group: number; // 3-5
  advancement_count?: number;
}

interface AutoSeedResponse {
  groups: Array<{
    name: string;
    members: Array<{
      entry_id: string;
      seed: number;
      person: Person;
    }>;
  }>;
  unassigned: Person[]; // Players not placed
}
```

---

## Frontend Components

### GroupCard Component

```typescript
interface GroupCardProps {
  group: RoundRobinGroup;
  onEdit: (group: RoundRobinGroup) => void;
  onDelete: (group: RoundRobinGroup) => void;
  onViewMatches: (group: RoundRobinGroup) => void;
  isEditable: boolean;
}
```

### GroupMemberList Component

```typescript
interface GroupMemberListProps {
  members: GroupMember[];
  onReorder: (memberId: string, newSeed: number) => void;
  onRemove: (memberId: string) => void;
  showSeeding: boolean;
}
```

### SeedingIndicator Component

```typescript
interface SeedingIndicatorProps {
  seed: number;
  isHead: boolean; // seed === 1
}

// Visual: ⭐ for heads, numbered for others
// P1 ⭐ (Head)
// P2
```

---

## State Management

### useGroupsStore

```typescript
interface GroupsState {
  groups: RoundRobinGroup[];
  loading: boolean;
  error: string | null;
  
  // Computed
  availablePlayers: Person[]; // Not in any group
  totalMatches: number;
  groupsReady: boolean; // All groups have 3-5 members
  
  // Actions
  fetchGroups: (tournamentId: string) => Promise<void>;
  createGroup: (data: CreateGroupRequest) => Promise<Group>;
  updateGroup: (groupId: string, data: UpdateGroupRequest) => Promise<void>;
  deleteGroup: (groupId: string) => Promise<void>;
  addMember: (groupId: string, entryId: string) => Promise<void>;
  removeMember: (groupId: string, memberId: string) => Promise<void>;
  autoSeed: (groupCount: number) => Promise<void>;
}
```

---

## Validation Rules

| Rule | UI Behavior |
|------|------------|
| 3-5 members per group | Disable "Create" if < 3, warn if > 5 |
| Unique seeds | Auto-increment, allow manual override |
| One player per group | Filter out already-assigned players |
| Head separation | Visual indicator if heads clash |
| No duplicate group names | Disable name if exists |

---

## Error Handling

### Insufficient Members

```typescript
// When trying to create group with < 3 members
const insufficientMembers = () => (
  <Alert type="warning">
    Need at least 3 players to create a Round Robin group.
    Add more players or reduce group count.
  </Alert>
);
```

### Seeding Conflict

```typescript
// When two heads end up in same group
const seedingConflict = () => (
  <Alert type="error">
    Seeding conflict: Two group heads cannot be in the same group.
    System will automatically adjust.
  </Alert>
);
```

---

## Offline Considerations

### Optimistic Updates

```typescript
// When adding a member
const addMember = async (groupId: string, entryId: string) => {
  // Optimistic update
  setGroups(prev => prev.map(g => 
    g.id === groupId 
      ? { ...g, members: [...g.members, { entry_id: entryId, temporary: true }] }
      : g
  ));
  
  try {
    await api.addMember(groupId, entryId);
    // Invalidate to get server truth
    queryClient.invalidateQueries(['groups', tournamentId]);
  } catch (error) {
    // Rollback on error
    queryClient.invalidateQueries(['groups', tournamentId]);
  }
};
```

### Sync Conflict Resolution

```typescript
// If another user modified the group while offline
interface ConflictResolution {
  serverVersion: RoundRobinGroup;
  localVersion: RoundRobinGroup;
  
  resolution: 'server_wins' | 'merge' | 'manual';
}
```
