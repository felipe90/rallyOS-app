# Políticas de Seguridad

## Scores

```sql
CREATE POLICY "Scores insert/update allowed only for assigned referee" 
ON scores FOR ALL
USING (EXISTS (
    SELECT 1 FROM matches m
    WHERE m.id = scores.match_id
    AND m.referee_id = auth.uid()
));
```

## Tournament Entries

```sql
CREATE POLICY "Entry owner or organizer can update status"
ON tournament_entries FOR UPDATE
USING (
    -- Entry owner
    EXISTS (
        SELECT 1 FROM entry_members em
        JOIN persons p ON em.person_id = p.id
        WHERE em.entry_id = tournament_entries.id
        AND p.user_id = auth.uid()
    )
    OR
    -- Organizer
    EXISTS (
        SELECT 1 FROM categories c
        JOIN tournament_staff ts ON c.tournament_id = ts.tournament_id
        WHERE c.id = tournament_entries.category_id
        AND ts.user_id = auth.uid()
        AND ts.role = 'ORGANIZER'
    )
);
```

## Elo History (Solo lectura)

```sql
CREATE POLICY "Elo history is read only for users" 
ON elo_history FOR SELECT
USING (true);
-- NO INSERT policy = clientes no pueden escribir
```
