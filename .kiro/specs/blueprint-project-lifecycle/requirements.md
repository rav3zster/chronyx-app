# Requirements Document

## Introduction

This feature redesigns the entire Blueprint → Project lifecycle in Chronyx so that a blueprint behaves like a complete productivity system rather than a one-shot generator. Today, after a blueprint is completed or its tasks are deleted, the user is dropped onto a dead-end Project Detail screen that only shows "No tasks yet. This project may have been saved without a parsed blueprint." This is a broken experience with no recovery path.

The redesign introduces a full project status model (draft, active, paused, completed, archived, deleted), automatic status transitions driven by user activity, an intelligent state-aware Project Detail dashboard, a completion experience with statistics and insights, a blueprint recovery system that reconstructs lost tasks from the stored blueprint JSON, and the Supabase schema additions and safe migration needed to support all of the above.

The work is Android-first and must preserve the existing Clean Architecture + Riverpod + Supabase structure. The schema migration must be idempotent and safe for existing rows, and all database errors must surface as real Postgres errors rather than being swallowed. No screen in this lifecycle may leave the user in a dead end; every state must present at least one forward action.

## Glossary

- **Lifecycle_System**: The overall Blueprint → Project lifecycle subsystem covering status, transitions, recovery, dashboard, and completion. Used when a requirement applies broadly across the feature.
- **Project**: A user-created blueprint project with an AI-generated roadmap, persisted in the `projects` table.
- **Project_Status**: The lifecycle state of a Project. One of: draft, active, paused, completed, archived, deleted.
- **Project_Task**: A single actionable item belonging to a Project, persisted in the `project_tasks` table.
- **Parsed_Blueprint**: The structured roadmap (days and tasks) stored as JSONB in the `projects.parsed_blueprint` column.
- **Status_Manager**: The component responsible for evaluating and applying Project_Status transitions.
- **Project_Repository**: The domain repository contract (and its Supabase-backed implementation) for project and task persistence.
- **Project_Detail_Screen**: The Android screen that displays a single Project (formerly the dead-end screen).
- **Project_Dashboard**: The state-aware content rendered inside the Project_Detail_Screen for an active or paused Project (hero, Today's Focus, analytics, timeline, smart actions).
- **Completion_Experience**: The UI presented when a Project reaches completed status, including statistics, smart insights, and forward actions.
- **Recovery_System**: The component that reconstructs missing Project_Tasks from a Parsed_Blueprint.
- **Smart_Actions_Sheet**: The Android bottom sheet exposing contextual project actions.
- **Migration_Script**: The idempotent SQL migration that widens the schema for the new lifecycle.
- **Completion_Percentage**: An integer 0–100 representing the proportion of Project_Tasks marked completed.
- **Completion_Streak**: The count of consecutive active days on which the user completed at least one Project_Task.
- **Soft_Delete**: Marking a Project as deleted (is_deleted = true, status = deleted) while retaining the row for a 30-day retention window before permanent removal.
- **Retention_Window**: The 30-day period after Soft_Delete during which a deleted Project is recoverable before permanent removal.
- **Momentum_Score**: A computed metric summarizing recent task-completion activity, shown in the mini Progress Analytics card.

## Requirements

### Requirement 1: Project Status Model

**User Story:** As a Chronyx user, I want my projects to carry a meaningful lifecycle status, so that the app shows the right actions and content for where each project actually is.

#### Acceptance Criteria

1. THE Lifecycle_System SHALL support exactly six Project_Status values: draft, active, paused, completed, archived, and deleted.
2. WHEN a Project is created from a blueprint without being started, THE Lifecycle_System SHALL assign the Project a Project_Status of draft.
3. WHERE a Project_Status is draft, THE Project_Detail_Screen SHALL present the actions Start Blueprint, Edit Blueprint, and Delete.
4. WHERE a Project_Status is active, THE Project_Detail_Screen SHALL present the actions Continue Today, Pause Blueprint, Edit Blueprint, Regenerate Day, and View Analytics.
5. WHERE a Project_Status is paused, THE Project_Detail_Screen SHALL present the actions Resume, Edit, and Delete.
6. WHERE a Project_Status is completed, THE Project_Detail_Screen SHALL present the Completion_Experience with the actions Create New Blueprint, Regenerate Similar, Duplicate, Archive, and Delete.
7. WHERE a Project_Status is archived, THE Project_Detail_Screen SHALL render the Project as read-only and present the actions Duplicate, Restore, and Delete permanently.
8. WHERE a Project_Status is deleted, THE Lifecycle_System SHALL exclude the Project from the default project list and retain the Project for the Retention_Window.

### Requirement 2: Automatic Status Transitions

**User Story:** As a Chronyx user, I want my project status to update automatically as I work, so that I never have to manually manage state.

#### Acceptance Criteria

1. WHEN the user starts the first session on a Project whose Project_Status is draft, THE Status_Manager SHALL transition the Project_Status from draft to active and set started_at to the transition time.
2. WHEN all Project_Tasks for an active Project are marked completed, THE Status_Manager SHALL transition the Project_Status from active to completed and set completed_at to the transition time.
3. WHEN the user pauses an active Project, THE Status_Manager SHALL transition the Project_Status from active to paused and set paused_at to the transition time.
4. WHEN the user resumes a paused Project, THE Status_Manager SHALL transition the Project_Status from paused to active.
5. WHEN the user restores an archived Project, THE Status_Manager SHALL transition the Project_Status from archived to active and set archived_at to null.
6. WHEN the user deletes a Project, THE Status_Manager SHALL perform a Soft_Delete by setting Project_Status to deleted, setting is_deleted to true, and setting deleted_at to the deletion time.
7. IF a requested status transition is not defined for the current Project_Status, THEN THE Status_Manager SHALL reject the transition and surface a descriptive error without modifying the Project.
8. WHEN any Project_Status transition is applied, THE Status_Manager SHALL update last_active_at to the transition time.

### Requirement 3: State-Aware Project Detail Screen (Fix Dead End)

**User Story:** As a Chronyx user, I want the Project Detail screen to show useful, state-aware content and at least one forward action in every case, so that I am never stuck on a dead-end screen.

#### Acceptance Criteria

1. THE Project_Detail_Screen SHALL render content determined by the Project_Status and the availability of Parsed_Blueprint and Project_Tasks, and SHALL NOT display a generic "No tasks yet" message.
2. IF a Project has no Parsed_Blueprint and no Project_Tasks, THEN THE Project_Detail_Screen SHALL display a "Blueprint data missing" state presenting the actions Regenerate Blueprint and Delete Project.
3. WHILE a Project_Status is completed, THE Project_Detail_Screen SHALL display the Completion_Experience.
4. IF a Project has a Parsed_Blueprint but zero Project_Tasks and its Project_Status is not completed, THEN THE Project_Detail_Screen SHALL display a "No tasks remaining" state presenting the actions Restore from blueprint, Regenerate tasks, and Delete blueprint.
5. THE Project_Detail_Screen SHALL present at least one forward action in every renderable state.

### Requirement 4: Intelligent Project Dashboard

**User Story:** As a Chronyx user actively following a blueprint, I want a rich dashboard that shows my progress and today's work, so that I always know where I stand and what to do next.

#### Acceptance Criteria

1. WHILE a Project_Status is active or paused, THE Project_Dashboard SHALL display a hero section showing Completion_Percentage, a progress ring, the current Completion_Streak, and the estimated remaining days.
2. WHEN the Project_Dashboard renders the hero section, THE Project_Dashboard SHALL display the current day position relative to total duration in the format "Day {current}/{total}".
3. THE Project_Dashboard SHALL display a Today's Focus card listing the Project_Tasks scheduled for the current day, their combined estimated minutes, and their priority, with a primary action labeled Start Session.
4. IF no Project_Tasks are scheduled for the current day, THEN THE Today's Focus card SHALL display a no-tasks-today message presenting an action to view the timeline or regenerate the day.
5. THE Project_Dashboard SHALL display a mini Progress Analytics card showing time spent during the current week, the most active category, the completion trend, and the Momentum_Score.
6. WHEN the user taps the mini Progress Analytics card, THE Project_Dashboard SHALL navigate to the full analytics view for the Project.
7. THE Project_Dashboard SHALL display a collapsible Timeline view listing each day with its completion state, where each day is shown as completed, in progress, or locked.
8. THE Project_Dashboard SHALL provide a Smart_Actions_Sheet exposing the actions Edit, Pause, Duplicate, Regenerate Remaining Days, Archive, and Delete.

### Requirement 5: Completion Experience

**User Story:** As a Chronyx user who finishes a blueprint, I want a rewarding completion experience with my stats and insights, so that I feel accomplished and know what to do next.

#### Acceptance Criteria

1. WHEN a Project_Status becomes completed, THE Completion_Experience SHALL display the header "Blueprint Completed".
2. THE Completion_Experience SHALL display the statistics total days completed, total tasks completed, estimated hours invested, Completion_Streak, and completion date.
3. THE Completion_Experience SHALL display the smart insights strongest category, most active days, and average consistency.
4. THE Completion_Experience SHALL present the primary actions Create New Blueprint, Regenerate Similar, Duplicate, Archive, and Delete.
5. WHERE an AI Reflection summary is available, THE Completion_Experience SHALL display the AI Reflection summary.
6. IF an AI Reflection summary cannot be generated, THEN THE Completion_Experience SHALL display the statistics and insights without the AI Reflection summary and SHALL NOT block the Completion_Experience.

### Requirement 6: Blueprint Recovery System

**User Story:** As a Chronyx user, I want the app to rebuild my project tasks from my saved blueprint if they go missing, so that I never lose my work.

#### Acceptance Criteria

1. WHERE a Project has a Parsed_Blueprint, THE Recovery_System SHALL provide a Restore Blueprint action that reconstructs Project_Tasks from the Parsed_Blueprint.
2. WHEN the user invokes Restore Blueprint, THE Recovery_System SHALL create one Project_Task for each task in the Parsed_Blueprint, preserving day number, title, description, estimated minutes, and sort order.
3. WHEN the Recovery_System reconstructs Project_Tasks, THE Recovery_System SHALL set each reconstructed Project_Task status to pending.
4. IF a Project has no Parsed_Blueprint when Restore Blueprint is invoked, THEN THE Recovery_System SHALL reject the operation and present the "Blueprint data missing" state.
5. WHEN the Recovery_System completes reconstruction, THE Recovery_System SHALL reload the Project_Detail_Screen so the reconstructed Project_Tasks are displayed.
6. IF reconstruction fails due to a persistence error, THEN THE Recovery_System SHALL surface the underlying Postgres error and SHALL leave the existing Project_Tasks unchanged.

### Requirement 7: Soft Delete and Retention

**User Story:** As a Chronyx user, I want deleting a project to be recoverable for a while, so that an accidental delete does not permanently destroy my work.

#### Acceptance Criteria

1. WHEN the user deletes a Project that is not archived, THE Lifecycle_System SHALL perform a Soft_Delete rather than removing the row.
2. WHILE a Project is within the Retention_Window, THE Lifecycle_System SHALL retain the Project row and its associated Project_Tasks.
3. WHEN a soft-deleted Project has been in deleted status for 30 days, THE Lifecycle_System SHALL permanently remove the Project and its associated Project_Tasks.
4. WHERE a Project_Status is archived and the user selects Delete permanently, THE Lifecycle_System SHALL permanently remove the Project and its associated Project_Tasks without applying the Retention_Window.
5. THE Lifecycle_System SHALL exclude Projects whose is_deleted is true from the default project list.

### Requirement 8: Progress and Statistics Tracking

**User Story:** As a Chronyx user, I want my progress metrics to stay accurate as I complete tasks, so that the dashboard and completion stats reflect reality.

#### Acceptance Criteria

1. WHEN a Project_Task is marked completed, THE Lifecycle_System SHALL set the Project_Task completed_at to the completion time and recalculate the Project completion_percentage, completed_tasks, and completed_days.
2. THE Lifecycle_System SHALL calculate Completion_Percentage as the integer percentage of Project_Tasks whose status is completed relative to the total number of Project_Tasks, bounded between 0 and 100.
3. WHEN time-tracking sessions are recorded against a Project_Task, THE Lifecycle_System SHALL accumulate the session minutes into the Project_Task actual_minutes and the Project actual_minutes_spent.
4. WHEN the user completes at least one Project_Task on a calendar day that is consecutive with the previous active day, THE Lifecycle_System SHALL increment the Project streak_days.
5. IF the user completes no Project_Task on a calendar day after a prior active day, THEN THE Lifecycle_System SHALL reset the Project streak_days to 0 on the next completion.
6. WHEN a Project_Task completion state changes, THE Lifecycle_System SHALL update the Project last_active_at to the change time.

### Requirement 9: Supabase Schema Additions and Safe Migration

**User Story:** As a developer, I want an idempotent, backward-compatible migration that adds the lifecycle columns and widens the status constraint, so that existing data is preserved and the deployment is safe to re-run.

#### Acceptance Criteria

1. THE Migration_Script SHALL add to the projects table the columns status (default 'draft'), started_at, completed_at, paused_at, archived_at, completion_percentage (default 0), completed_days (default 0), completed_tasks (default 0), estimated_total_minutes (default 0), actual_minutes_spent (default 0), streak_days (default 0), last_active_at, is_deleted (default false), and deleted_at.
2. THE Migration_Script SHALL add to the project_tasks table the columns is_completed (default false), completed_at, actual_minutes (default 0), and sort_order.
3. THE Migration_Script SHALL replace the projects status CHECK constraint so that status is constrained to the values draft, active, paused, completed, archived, and deleted.
4. WHEN the Migration_Script is executed more than once, THE Migration_Script SHALL complete without error and SHALL NOT duplicate columns, constraints, or indexes.
5. WHEN the Migration_Script runs against a database containing existing project rows, THE Migration_Script SHALL preserve the existing status value of each existing row.
6. WHERE existing project rows have a status value of active, completed, or archived, THE Migration_Script SHALL keep those rows valid under the widened CHECK constraint.
7. THE Migration_Script SHALL change the projects status column default from 'active' to 'draft' for newly inserted rows while leaving existing rows unchanged.

### Requirement 10: Error Handling and Architecture Preservation

**User Story:** As a developer, I want lifecycle operations to respect Clean Architecture and surface real database errors, so that the codebase stays maintainable and failures are observable.

#### Acceptance Criteria

1. THE Lifecycle_System SHALL implement persistence operations through the Project_Repository contract within the existing Clean Architecture and Riverpod structure.
2. IF a Supabase or Postgres operation fails, THEN THE Project_Repository SHALL surface the underlying error to the caller and SHALL NOT swallow or silently discard the error.
3. WHEN a lifecycle operation fails, THE Project_Detail_Screen SHALL display an error state that presents at least one forward action and SHALL NOT leave the user on a blank or dead-end screen.
4. THE Lifecycle_System SHALL target Android-first interaction patterns, using bottom sheets for the Smart_Actions_Sheet, and SHALL remain non-breaking on other platforms without requiring web-specific optimization.

## Backward-Compatibility and Migration Risk Notes

- The existing migration `001_create_projects.sql` defines the projects `status` CHECK as `IN ('active', 'completed', 'archived')` with a default of `'active'`. The new model adds `draft`, `paused`, and `deleted`, and changes the default to `'draft'`. The Migration_Script must drop and recreate the CHECK constraint (idempotently) before any rows can be written with the new statuses. Risk: any row inserted with a new status before the constraint is widened will fail — the constraint change must run first.
- Existing project rows default to `active`. After migration, those rows remain `active` (a valid status), so in-flight projects are unaffected. Only newly created projects default to `draft`.
- The existing domain `ProjectStatus` enum has only `active`, `completed`, `archived`. Extending it to include `draft`, `paused`, `deleted` is a domain change that must be coordinated with the data-layer model mapping (`fromJson`/`jsonKey`) to avoid silently coercing unknown statuses to `active`.
- `is_completed` on `project_tasks` is additive alongside the existing `status` enum (`pending`, `in_progress`, `completed`, `skipped`). The migration and mapping must keep `is_completed` consistent with `status = 'completed'` to avoid divergence.
