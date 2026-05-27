# AI Blueprint Wizard — Design

## Architecture (Unchanged)
Follows existing Clean Architecture (feature-first) pattern:
```
lib/features/blueprint_wizard/
├── data/
│   ├── datasources/
│   │   └── blueprint_remote_datasource.dart
│   ├── models/
│   │   ├── blueprint_model.dart
│   │   └── project_model.dart
│   └── repositories/
│       └── blueprint_repository_impl.dart
├── domain/
│   ├── entities/
│   │   ├── blueprint.dart
│   │   └── project.dart
│   ├── repositories/
│   │   └── blueprint_repository.dart
│   └── usecases/
│       ├── generate_blueprint.dart
│       └── save_project.dart
└── presentation/
    ├── pages/
    │   ├── wizard_page.dart
    │   ├── goal_input_step.dart
    │   ├── template_selection_step.dart
    │   ├── configuration_step.dart
    │   ├── prompt_preview_step.dart
    │   └── blueprint_result_page.dart
    ├── providers/
    │   └── wizard_provider.dart
    └── widgets/
        ├── duration_slider.dart
        ├── difficulty_selector.dart
        └── blueprint_day_card.dart
```

## Database Schema

### `projects` table
| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | uuid | PK, default gen_random_uuid() | Unique project ID |
| user_id | uuid | FK → auth.users(id), NOT NULL | Owner |
| title | text | NOT NULL | Project/goal title |
| goal_description | text | NOT NULL | Original user goal input |
| template | text | NOT NULL | Selected template key |
| duration_days | integer | NOT NULL, CHECK (7–365) | Target duration |
| difficulty | text | NOT NULL | easy/medium/hard/expert |
| daily_time_minutes | integer | NOT NULL | Daily time commitment |
| generated_prompt | text | | Final prompt sent to AI |
| raw_blueprint_response | text | | Original AI response (for re-import, debugging, regeneration) |
| parsed_blueprint | jsonb | | Structured parsed roadmap |
| status | text | NOT NULL, default 'active' | active/completed/archived |
| created_at | timestamptz | NOT NULL, default now() | Creation timestamp |
| updated_at | timestamptz | NOT NULL, default now() | Last update |

### RLS Policies
- Users can only read/write their own projects
- Service role has full access for edge functions

## Prompt Preview Page — UX Design

### Layout
```
┌─────────────────────────────────────┐
│  ← Back          Prompt Preview     │
├─────────────────────────────────────┤
│                                     │
│  📋 Your Configuration              │
│  ┌───────────────────────────────┐  │
│  │ Goal: Learn Flutter...        │  │
│  │ Template: Learning Goal       │  │
│  │ Duration: 30 days             │  │
│  │ Difficulty: Medium            │  │
│  │ Daily Time: 2 hours           │  │
│  └───────────────────────────────┘  │
│                                     │
│  📝 Generated Prompt                │
│  ┌───────────────────────────────┐  │
│  │ [Scrollable prompt text...]   │  │
│  │                               │  │
│  └───────────────────────────────┘  │
│                                     │
│  ┌─────────────────────────────┐    │
│  │   🔄 Regenerate Prompt      │    │
│  └─────────────────────────────┘    │
│                                     │
│  ┌─────────────────────────────┐    │
│  │   🚀 Generate Blueprint     │    │
│  └─────────────────────────────┘    │
│                                     │
└─────────────────────────────────────┘
```

### "Regenerate Prompt" Behavior
1. User taps "Regenerate Prompt"
2. Bottom sheet or dialog appears with editable fields:
   - Duration slider (7–365)
   - Difficulty dropdown
   - Template selector
3. User modifies values and taps "Apply"
4. Prompt text regenerates in-place
5. Wizard state updates without losing goal text or restarting flow
6. No navigation away from Prompt Preview page

## Duration Validation

### UI Layer (configuration_step.dart / duration_slider.dart)
- Slider: min=7, max=365, divisions=358
- Manual input: TextField with validator (7–365)
- Error message: "Duration must be between 7 and 365 days"

### Domain Layer (entities/project.dart)
- Assertion: `assert(durationDays >= 7 && durationDays <= 365)`

### Data Layer (Supabase)
- CHECK constraint: `duration_days >= 7 AND duration_days <= 365`

## State Management (Riverpod)

### WizardState
```dart
@freezed
class WizardState with _$WizardState {
  const factory WizardState({
    @Default(0) int currentStep,
    @Default('') String goalDescription,
    String? selectedTemplate,
    @Default(30) int durationDays,       // 7–365
    @Default('medium') String difficulty,
    @Default(120) int dailyTimeMinutes,
    String? generatedPrompt,
    String? rawBlueprintResponse,
    Blueprint? parsedBlueprint,
    @Default(false) bool isGenerating,
    String? errorMessage,
  }) = _WizardState;
}
```

## Key Design Decisions
1. **raw_blueprint_response stored separately** — enables debugging, re-parsing with improved logic, and user-triggered regeneration without re-calling AI
2. **Regenerate Prompt is in-page** — no wizard restart, preserves user flow
3. **Duration 7–365** — supports short challenges through year-long transformations
4. **Architecture unchanged** — follows existing feature-first Clean Architecture pattern
