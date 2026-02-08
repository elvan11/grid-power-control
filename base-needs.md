## Requirements – mobile app for scheduled control of solar + battery

### 1) Goals and baseline behavior

- The app must allow the user to create, save, and use **weekly control schedules** for a battery/solar installation.
- The control must support:
  - **Peak shaving** with a selectable level (in 100 W steps).
  - **Allow/disallow charging from the grid (“grid charging”)**, independent of peak shaving.
- The user must be able to create **multiple daily schedules** and choose which one(s) are active for different days/ranges.

### 2) Core objects (concepts)

**Daily schedule**

- A daily schedule consists of one or more **time segments** within a 24-hour day.
- Each time segment has:
  - Start time (HH:MM)
  - End time (HH:MM)
  - Peak-shaving level (W), adjustable in 100 W steps
  - Grid charging: Allowed / Not allowed

**Weekly assignment**

- A daily schedule can be assigned to:
  - A single day (e.g., Tuesday)
  - A day range (e.g., Monday–Friday)
  - Multiple selected days (e.g., Mon, Wed, Sun)

### 3) Functional requirements – creation and management

- Create a new daily schedule with a name.
- Edit a daily schedule:
  - Add, change, and remove time segments.
  - Reorder segments if needed.
- Copy/duplicate a daily schedule to quickly create variants.
- Delete a daily schedule (with a clear warning if it is used somewhere in the week).
- List all daily schedules and indicate which one(s) are used where in the week.

### 4) Functional requirements – weekly view and schedule selection

- A weekly view where the user can:
  - Assign a daily schedule to a day or day range (e.g., Monday–Friday).
  - Use different daily schedules for different days (e.g., “Weekday”, “Weekend”, “Night charging”).
- It must be possible to store **many daily schedules** and choose them by “checking/activating” for selected days.
- If multiple daily schedules are selected for the same day, the app must have defined behavior:
  - Either: only one active schedule per day (recommended for simplicity)
  - Or: a priority order (the user can sort priority)
  - Or: the app blocks and requires choosing exactly one

### 5) Rules and validation

- Segments must not have invalid times (start < end within the same day).
- Segments within the same daily schedule must not overlap. If the user creates an overlap, the app must:
  - Either prevent it and show an error
  - Or suggest an automatic adjustment (but it must be clear)
- The full 24 hours do not have to be covered by segments:
  - If a time period has no segment, the app must use a defined “default mode” for that time (e.g., “no peak shaving” and “grid charging not allowed”, or a selectable default per schedule).
- Peak-shaving level:
  - Must be specified in watts and rounded/stepped in 100 W increments.
  - Must have min/max limits that the user can choose within (e.g., 0 W up to an upper limit).
- Grid charging is a clear on/off per segment.

### 6) Runtime behavior (what applies “right now”)

- The app must always be able to show:
  - Active daily schedule for today
  - Active segment right now (and its values)
  - Next change time
- Manual “temporary override”:
  - The user can temporarily change the peak-shaving level and/or grid charging.
  - The override must apply until:
    - The next segment start, or
    - A chosen time, or
    - The user turns off the override
  - The app must always clearly show that an override is active.

### 7) Scenario requirements (examples that must be supported)

- “Monday–Friday” uses the schedule “Weekday”; “Saturday–Sunday” uses the schedule “Weekend”.
- In “Weekday”:
  - 06:00–09:00: peak shaving 1200 W, grid charging not allowed
  - 09:00–16:00: peak shaving 600 W, grid charging allowed
  - 16:00–22:00: peak shaving 1500 W, grid charging not allowed
- Ability to quickly create “Weekday v2” by copying and adjusting.
- The user can have multiple saved schedules and switch the active schedule for Monday–Friday with a couple of clicks.

### 8) User flows

- Create daily schedule → add segments → save → assign to day range.
- Change weekly assignment: select day range → select schedule → apply.
- Enable override from the “Today” view → choose values → choose duration → confirm.

### 9) Non-functional behavior requirements (no technical details)

- The app must be consistent: the same schedule must always produce the same control behavior at the same time.
- All changes must be clearly confirmed (so the user knows the new schedule applies).
- It must be possible to undo/cancel changes before saving.
