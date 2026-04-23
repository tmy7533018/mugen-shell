# Battery

Status: **draft** — decisions captured, a few open questions below.

## Concept

Wrap the existing PowerMenu bar icon with a **circular ring meter** whose fill represents battery percentage. The power menu icon in the center keeps its original click-to-open-power-panel behavior; the ring adds battery information without consuming additional bar space.

Desktop users (no battery device) see the original icon unchanged — no ring is drawn.

## Placement

Right section of the bar ([.config/mugen-shell/components/bar/BarRightSection.qml](../../.config/mugen-shell/components/bar/BarRightSection.qml)), unchanged position — the existing [PowerMenu bar icon](../../.config/mugen-shell/components/ui/PowerMenu.qml) is augmented in place.

## Visual design

- **Ring:** Canvas or `Shape` with `PathArc` around the 24x24 power icon.
- **Fill:** proportional to battery percentage. 100% = full circle, lower % = shorter arc (clockwise from 12 o'clock).
- **Center:** the existing SVG/Text menu icon, BlobEffect hover, click behavior — all unchanged.

### Color states

| State | Condition | Ring color |
|---|---|---|
| Normal | ≥ 20% | Matugen accent |
| Low | < 20% | Warning (orange) |
| Critical | < 10% | Red + pulse animation |
| Charging (any %) | — | Animated sweep highlight overlay |
| Full while charging | 100% + plugged in | Static green |

### Charging animation

A highlight sweep travels clockwise along the ring ("breathing" sweep). Designed not to clash with the hover BlobEffect — sweep runs on the ring, blob on the background.

### Critical pulse

Ring color pulses between red and darker red at low frequency (~1 Hz) when battery drops below critical threshold. Stops when charging starts.

## Thresholds

| Threshold | Value | Behavior |
|---|---|---|
| Low | 20% | Ring color changes to warning, notification once |
| Critical | 10% | Ring turns red + pulse, notification |
| Emergency | 5% | Stronger notification ("plug in now") |

MVP: thresholds are hard-coded constants. Post-MVP: expose through Settings panel.

## Notifications

Delivered via existing [NotificationManager](../../.config/mugen-shell/components/managers/NotificationManager.qml).

- Each threshold fires **once per discharge cycle**. State is reset when charging starts.
- Messages:
  - 20%: "Battery at 20%"
  - 10%: "Battery low — 10%"
  - 5%: "Critical — plug in now"

## Click behavior

- **Left click:** unchanged — opens the power menu panel.
- **Right click:** (open question — see below)
- **Hover:** BlobEffect as today.

## Data source

**UPower D-Bus** (`org.freedesktop.UPower`).

Reasoning:
- Abstracts laptop battery + Bluetooth peripheral batteries under one API.
- Provides time-to-full and time-to-empty estimates without manual calculation.
- Standard across Linux desktop environments, cleaner than reading `/sys/class/power_supply/BAT*`.
- Fits the existing Quickshell D-Bus usage pattern.

**Dependency note:** UPower must be running. If `upower.service` is inactive, the ring is not drawn (same behavior as no-battery environment).

## Edge cases

| Case | Behavior |
|---|---|
| No battery device (desktop) | No ring drawn; original PowerMenu icon rendered as-is |
| UPower not running | Same as no battery device |
| Multiple laptop batteries (rare, e.g., ThinkPad with slice battery) | Aggregate as single percentage |
| Bluetooth device battery | **Not** shown on the bar — surfaced in Bluetooth panel instead |
| Battery reports 0% briefly during probe | Suppress notifications if reading is <1s old |

## Theming

- Normal ring color derives from Matugen `accent`.
- Warning/critical colors are fixed (orange / red) but blended with Matugen surface color for tonal consistency.
- BlobEffect is unchanged (still tinted on hover).
- No BlobEffect on the ring itself — that's reserved for the Volume panel.

## Open questions

- **Tooltip:** Show `85% · 2h 30m remaining` on hover? The ring fill may already be enough — a tooltip adds precision but also visual clutter. Default: no tooltip in MVP, add later if users ask.
- **Right click action:** Currently emits `rightClicked()` (purpose unclear — needs code check). If free, could surface a battery details popup (time remaining, device name, cycle count). Otherwise leave unchanged.
- **Ring dimensions:** Icon is 24x24. Ring radius and stroke thickness TBD. Candidate: outer diameter 32–36, stroke 3–4px. Needs visual prototyping.

## Out of scope (MVP)

- Configurable thresholds.
- Per-device battery history / graphs.
- Power profile switching (performance / balanced / power-saver).
- Integration with `tlp` or `power-profiles-daemon`.
