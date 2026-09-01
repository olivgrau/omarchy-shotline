# Scenario and story

Fictional, but built so that any developer recognises it. Every name, company
and number is made up. The app in the material is a purpose-built mock
(`demo-app/pedalio.html`), so no real customer data shows up in the screenshots.

## The situation

**Pedalio** is a fictional bike rental with 40 bikes across four stations. The
ops team lives in the booking dashboard all day. Friday, 16:40, just before
everyone leaves, Mia from ops writes:

> "The rentals list is wrong front to back. Can you take a look?"

You click through the app for ten minutes and find four problems:

1. **The filter lies.** The chip says "Status: Paid", yet pending and cancelled
   bookings sit in the list. The total only sums the paid ones. List and total
   contradict each other.
2. **The dates are US format.** `03/04/2026` is the 3rd of April in one place
   and the 4th of March in another. The end date falls before the start date,
   and the duration reads `-7 h`.
3. **Saving fails.** `PATCH /api/rentals/0413` returns 500,
   `ValidationError: startDate must be ISO-8601`.
4. **On narrow screens the total is gone.** The table scrolls sideways, the
   "Amount" column sits off screen, and nothing hints at it.

## The actual problem

Finding the bugs took ten minutes. Writing them down takes longer.

> "In the detail sheet, in the field top right next to the customer name, the
> date renders in the American format, and further down that is why the
> duration is negative, those two are probably connected…"

Three sentences for what a screenshot settles in one. And the longer the text
gets, the more the agent guesses.

## What Shotline makes of it

Four times `SUPER + SHIFT + K`. Drag the region, the size sits in the frame,
type the comment, move on. On the dates, one press of the pen: two red boxes,
two words next to them. Then `SUPER + SHIFT + L`.

The agent directory now holds:

```
shotline-2026-09-01-pedalio-rentals/
  01-filter-says-status-paid-but-pending-and.png
  02-dates-render-as-mm-dd-yyyy-end-date-is-b.png
  03-saving-a-pending-rental-fails-patch-api.png
  04-on-narrow-screens-the-amount-column-is-p.png
  session.html    to look at
  session.md      for the agent
```

And the clipboard holds the finished sentence you hand the agent. Ten minutes
of typing become twenty seconds of clicking.

## The angle for the post

Not "I built a screenshot tool", but:
**your agent does not need a better prompt, it needs your screen.**
