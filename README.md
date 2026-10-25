# Bound

A book club app for iOS. Your books sit on wooden shelves, your club leaves spoiler-safe notes in the margins, and the monthly meetup gets planned in the app instead of a group chat.

SwiftUI and SwiftData on the phone, Supabase behind it.

## What it does

- **Shelves.** To read, Reading now and Finished, on oak planks. Tap a spine to lift it, tap anywhere else to put it back. Spines take their colour from the book's real cover.
- **Add any book.** Search Open Library by title, author or ISBN, or scan the barcode on the back cover.
- **Club notes.** Ratings and notes on each book, saved with the page you were on. Notes past your page fold away until you choose to read them. Edit or delete your own.
- **Meetups.** The host puts books up for a vote and plans the meetup. Members RSVP and vote. Everything updates live on everyone's phone.
- **Club ledger.** Every past meetup, with the club's average rating and yours.
- **Portraits.** Pick one of six Victorian silhouettes and a colour.
- **Sign-in.** Join with a club's invite code or start your own, using a code sent to your email. No passwords.
- **The tear.** Leaving the start screen and joining a club rip the page away to reveal the app underneath.

## Stack

| | |
| --- | --- |
| App | Swift, SwiftUI, SwiftData, iOS 26 |
| Backend | Supabase: Postgres with row-level security, Auth (email codes), Realtime |
| Books | Open Library search and covers |
| Scanning | VisionKit (EAN-13, ISBN 978/979 only) |
| Email | Custom SMTP through Resend |

## How the data works

- Your shelves live in SwiftData so the app works offline. Changes sync to Supabase about a second after you make them, and the app pulls the server copy when it opens.
- Club data (members, meetups, RSVPs, votes, notes) comes from the server, and Realtime pushes changes as they happen.
- Who can see what is decided in the database, not the app. You can read your clubmates' shelves, only hosts can plan meetups, and recommendations are visible only to their sender and recipient.

## Running it

You need Xcode 26 and a free Supabase project.

1. **Database.** In the Supabase SQL Editor, run each file in `supabase/migrations` in order (`0001`, `0002`, `0003`).
2. **Sign-in.** Under Authentication → Sign In / Providers → Email, keep Email OTP on. The app expects **8-digit** codes; if your project sends a different length, change `JoinClubView.signInCodeLength`. Supabase's built-in email is heavily rate-limited, so set up custom SMTP (Authentication → Emails → SMTP) and add `{{ .Token }}` to the "Magic link or OTP" and "Confirm sign up" templates.
3. **Keys.** Copy `Bound/Bound/Backend/Secrets.swift.example` to `Secrets.swift` and fill in your project URL and **anon public** key. `Secrets.swift` is git-ignored. Never put the `service_role` key in the app.
4. **Run.** Open `Bound/Bound.xcodeproj` and run on an iPhone or the Simulator. Barcode scanning needs a real phone.

## Project layout

```
Bound/Bound/
  App/          root tabs and the tear transition
  Backend/      Supabase client, sign-in, shelf/notes sync, club sync, Open Library, covers
  Components/   buttons, avatars, silhouettes, paper menu and other shared views
  Features/     Onboarding, Shelves, Book, AddBook, Meetup, Club, Me
  Models/       SwiftData models
  Theme/        colours, fonts, font registration
  Resources/    font files
supabase/
  migrations/   SQL to set up the database
```

## Not built yet

- Recommendations between members (the Club tab still shows sample ones)
- Sign in with Apple
- Push notifications and meetup reminders
- Add to calendar, real map location for the meetup, Goodreads import

## Credits

Book data and covers from [Open Library](https://openlibrary.org). Fonts from Google Fonts under the SIL Open Font License: UnifrakturMaguntia, Instrument Serif, IM Fell English SC, Hanken Grotesk and DM Mono.
