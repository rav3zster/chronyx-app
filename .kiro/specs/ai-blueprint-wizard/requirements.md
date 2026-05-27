# AI Blueprint Wizard — Requirements

## Overview
An AI-powered project/roadmap generation wizard that lets users define a goal, configure parameters, preview the generated prompt, and receive a structured daily blueprint (roadmap) broken into actionable tasks.

---

## Functional Requirements

### FR-1: Wizard Flow
- Multi-step wizard: Goal Input → Template Selection → Configuration → Prompt Preview → Generation → Result
- User can navigate back/forward between steps
- Progress indicator shows current step

### FR-2: Goal Input
- User enters a free-text goal description (e.g., "Learn Flutter in 30 days", "Build a SaaS MVP")
- Minimum 10 characters, maximum 500 characters

### FR-3: Template Selection
- Predefined templates: AI Engineer Roadmap, Fitness Transformation, Startup Plan, Learning Goal, Custom
- Each template provides default configuration values
- User can select one template per project

### FR-4: Configuration
- **Duration**: 7–365 days (slider + manual input)
- **Difficulty**: Easy / Medium / Hard / Expert
- **Daily time commitment**: 30 min – 8 hours
- Validation enforces duration range of 7–365 days

### FR-5: Prompt Preview Page
- Displays the fully assembled prompt before sending to AI
- Shows: goal, template, duration, difficulty, time commitment
- **"Regenerate Prompt" button**: allows user to go back and change duration, difficulty, or template, then regenerate the prompt without restarting the entire wizard
- User can manually edit the prompt text (optional advanced mode)
- "Generate Blueprint" button to proceed

### FR-6: Blueprint Generation
- Sends prompt to AI backend (Gemini / OpenAI via edge function)
- Shows loading state with progress indication
- Handles errors gracefully (timeout, rate limit, network)

### FR-7: Blueprint Result
- Displays structured daily roadmap with tasks
- Each day has: day number, title, tasks list, estimated time
- User can save blueprint as a project

### FR-8: Project Persistence
- Saved blueprints stored in `projects` table
- **`raw_blueprint_response`** column stores the original AI response text
  - Purpose: future re-import, debugging, roadmap regeneration
- Projects linked to authenticated user

---

## Non-Functional Requirements

### NFR-1: Performance
- Prompt generation (local assembly): < 100ms
- AI response: timeout at 60 seconds with retry option

### NFR-2: UX
- Wizard must be completable in under 2 minutes (excluding AI wait time)
- Regenerate Prompt flow should not lose previously entered data

### NFR-3: Data Integrity
- Raw AI response always preserved regardless of parsing outcome
- Duration validation enforced at UI and data layer (7–365 days)

---

## Duration Range Rationale
Target duration: **7–365 days**

Users may create:
- AI engineer roadmaps (60–180 days)
- Fitness transformations (30–365 days)
- Startup plans (90–365 days)
- Long-term learning goals (30–365 days)
- Short sprints or challenges (7–30 days)
