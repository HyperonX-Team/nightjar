# DESIGN

Product: Nightjar
Type: Covert safety utility, Android only, Flutter.
Audience: People in unsafe households who need a discreet way to alert trusted contacts.

## Identity

A matte office calculator that happens to be a lifeline. Paper ledger, not a phone app.

## Visual language

Quiet utilitarian. Physical calculator. No gradients, no glow, no glass.

## Palette

Core neutrals: Paper #E9E5DB, Ink #1C1B18.
Key surface: #D9D3C6 (neutral, does not count against the palette cap).
Accent: Oxide #9C3D2E. Used on the "=" key and exactly one primary action per setup screen. On the contact page it marks live status only.
No gradients. No glow. Flat surfaces.

## Typography

- IBM Plex Sans for UI and setup. Reason: engineered, neutral, legible at small sizes, not the default AI roster.
- IBM Plex Mono for the display only. Reason: fixed-width digits prevent the display from shifting as numbers are typed, the way a physical calculator behaves.
- Bundle font files in assets. No runtime font fetch.

## Layout

One device face. Display at top with a hairline ledger rule, 4x5 key grid below. Max width 420dp, centered on tablets. Keys are rectangles with 6dp radius and a 1dp inset border, not pills (R-11). Press state translates the key 1px and darkens it. No shadow except that depression.

## Identity motif

The ledger rule under the display, repeated as the divider on setup screens and the contact page.

## Motion

Press states only. No entrance animations, no loops, no pulsing dots.

## Dials

ENERGY 1 / RHYTHM 1 / MOTION 1.
Reason: the disguise must be boring, and the contact page must not perform.

## Copy

No em dashes (R-02). No buzzwords (R-16). Specific labels: Set a PIN, Add three contacts, Send a test alert.

## Breakpoints

320dp to 420dp for the calculator. Tablet centers the calculator at 420dp. No horizontal overflow (R-03).