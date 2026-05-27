# AI Blueprint Wizard — Implementation Tasks

## Phase 1: Foundation
- [ ] 1. Create feature folder structure (`lib/features/blueprint_wizard/`)
- [ ] 2. Define domain entities: `Blueprint`, `Project`, `DayPlan`, `Task`
- [ ] 3. Define repository interface (`BlueprintRepository`)
- [ ] 4. Create Supabase migration: `projects` table with `raw_blueprint_response` column and CHECK constraint (duration_days 7–365)
- [ ] 5. Set up Riverpod `WizardState` and `WizardNotifier`

## Phase 2: Wizard UI
- [ ] 6. Create `WizardPage` with step navigation and progress indicator
- [ ] 7. Build `GoalInputStep` — text field with 10–500 char validation
- [ ] 8. Build `TemplateSelectionStep` — grid of template cards
- [ ] 9. Build `ConfigurationStep` — duration slider (7–365), difficulty selector, time commitment
- [ ] 10. Build `PromptPreviewStep` — assembled prompt display + "Regenerate Prompt" button + "Generate Blueprint" button
- [ ] 11. Implement "Regenerate Prompt" bottom sheet (edit duration/difficulty/template in-place, regenerate without restart)
- [ ] 12. Build `BlueprintResultPage` — day-by-day roadmap display

## Phase 3: Data Layer
- [ ] 13. Implement `BlueprintRemoteDatasource` (Supabase edge function call)
- [ ] 14. Implement `BlueprintRepositoryImpl`
- [ ] 15. Create prompt assembly logic (template + config → prompt string)
- [ ] 16. Create blueprint response parser (AI text → structured `Blueprint`)
- [ ] 17. Implement project save (including `raw_blueprint_response`)

## Phase 4: Integration
- [ ] 18. Wire wizard flow end-to-end (goal → template → config → preview → generate → result)
- [ ] 19. Add error handling (timeout, network, parse failures)
- [ ] 20. Add loading states and animations
- [ ] 21. Add navigation entry point from main app (dashboard or drawer)

## Phase 5: Polish
- [ ] 22. Duration validation at all layers (UI, domain, DB)
- [ ] 23. Edge cases: empty response, malformed JSON, partial blueprint
- [ ] 24. Accessibility: semantic labels, contrast, screen reader support
