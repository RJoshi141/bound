<p align="center">
  <img src="docs/images/app-icon.png" width="112" alt="Bound app icon, a red wax seal with a blackletter B">
</p>

<h1 align="center">Bound</h1>

<p align="center">
  <em>Your book club, all in one place.</em><br>
  Track what you read, share notes, plan the next meetup.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/iOS-26-221A14?style=flat-square&logo=apple&logoColor=F2EADB" alt="iOS 26">
  <img src="https://img.shields.io/badge/Swift-SwiftUI%20%C2%B7%20SwiftData-8A2C22?style=flat-square&logo=swift&logoColor=F2EADB" alt="SwiftUI and SwiftData">
  <img src="https://img.shields.io/badge/Supabase-Postgres%20%C2%B7%20Realtime-2F4A35?style=flat-square&logo=supabase&logoColor=F2EADB" alt="Supabase">
  <img src="https://img.shields.io/badge/books-Open%20Library-B4572A?style=flat-square" alt="Open Library">
</p>

<p align="center">
  <img src="docs/images/hero.png" width="520" alt="Bound on two iPhones: the start screen with an oil painting of books, and the shelves">
</p>

---

Book clubs live in five places at once. The pick is in a group chat, progress is on Goodreads, notes are in a notes app, and the meetup address is buried somewhere in the thread. Nobody wants spoilers, and nobody knows what page anyone else is on.

**Bound puts it in one place, and makes it feel like paper and ink.**

<p align="center">
  <img src="docs/images/screens.png" width="100%" alt="Four Bound screens: welcome, start a club, shelves with a book lifted, and a book page with club notes">
</p>

## Features

**Shelves that feel like shelves**
To read, Reading now and Finished, standing on oak planks. Tap a spine to lift it off the shelf, tap anywhere else to put it back. Real covers come from Open Library, and each spine takes its colour from the cover's edge.

**Add any book**
Search by title, author or ISBN, or scan the barcode on the back cover.

**Notes that don't spoil**
Every note saves the page its author was on. Notes past your page fold away until you choose to read them. Ruled index cards, star ratings, a "discuss at meetup" tag, and you can edit or delete your own.

**The monthly meetup**
A tear-off ticket with the book, date and place. RSVP Going, Maybe or Can't, and Going lands an ink stamp. The host puts books up for a vote, everyone votes, the host plans the meetup from the winner.

**Live with your club**
Notes, RSVPs and votes show up on everyone's phone in about a second.

**The club ledger**
Every past meetup, like a library due-date card, with the club's average rating and yours.

**Portraits, not initials**
Pick one of six Victorian cut-paper silhouettes and a colour.

**The tear**
Leaving the start screen and joining a club rip the page away to reveal the app underneath.

## Design

<img src="docs/images/palette.png" width="100%" alt="Palette: Paper F2EADB, Ink 221A14, Forest 2F4A35, Oxblood 8A2C22, Rust B4572A, Mustard C69A3A, Gilt A9813A">

| Role | Typeface |
| --- | --- |
| Masthead | UnifrakturMaguntia |
| Headings, shelf names | Instrument Serif |
| Buttons (letterpress small caps) | IM Fell English SC |
| Body | Hanken Grotesk |
| Labels | DM Mono |

Square letterpress buttons, custom paper menus instead of system ones, and a wax seal for the app icon.

<details>
<summary><b>Early lo-fi wireframes</b></summary>
<br>
<img src="docs/images/wireframes.png" width="100%" alt="Lo-fi wireframes of the core flow: join, shelves, book, meetup, club">
</details>

## How it works

- **Offline first.** Your shelves live in SwiftData on the phone and sync to Postgres about a second after each change. The app pulls the server copy when it opens.
- **Live club data.** Members, meetups, RSVPs, votes and notes come from Supabase, and Realtime pushes changes as they happen.
- **Permissions in the database.** Row-level security decides who sees what: clubmates can read your shelf, only hosts plan meetups, and recommendations are visible only to sender and recipient.
- **Passwordless.** Join with a 6-character invite code; sign in with an 8-digit code sent to your email.
- **Real books.** Open Library for search, ISBN lookup and covers. VisionKit reads the barcode and only accepts 978/979 codes, the ones printed on books.

## Stack

| | |
| --- | --- |
| App | Swift, SwiftUI, SwiftData, iOS 26 |
| Backend | Supabase: Postgres + row-level security, Auth, Realtime |
| Books | Open Library |
| Scanning | VisionKit |
| Email | Resend (custom SMTP) |

## Run it yourself

You need Xcode 26 and a free Supabase project.

1. **Database.** In the Supabase SQL Editor, run each file in [`supabase/migrations`](supabase/migrations) in order.
2. **Sign-in.** Under Authentication → Sign In / Providers → Email, keep Email OTP on. The app expects **8-digit** codes (change `JoinClubView.signInCodeLength` if yours differ). Set up custom SMTP and add `{{ .Token }}` to the "Magic link or OTP" and "Confirm sign up" email templates.
3. **Keys.** Copy `Bound/Bound/Backend/Secrets.swift.example` to `Secrets.swift` and add your project URL and **anon public** key. It's git-ignored. Never put the `service_role` key in the app.
4. **Run.** Open `Bound/Bound.xcodeproj` and run. Barcode scanning needs a real iPhone.

<details>
<summary><b>Project layout</b></summary>

```
Bound/Bound/
  App/          root tabs and the tear transition
  Backend/      Supabase client, sign-in, sync, Open Library, covers
  Components/   buttons, avatars, silhouettes, paper menu
  Features/     Onboarding, Shelves, Book, AddBook, Meetup, Club, Me
  Models/       SwiftData models
  Theme/        colours and fonts
  Resources/    font files
supabase/
  migrations/   SQL to set up the database
docs/images/    README images
```
</details>

## Roadmap

- [ ] Recommendations between members
- [ ] Sign in with Apple
- [ ] TestFlight beta
- [ ] Meetup reminders and add to calendar
- [ ] Goodreads import

## Credits

Book data and covers from [Open Library](https://openlibrary.org). Fonts from Google Fonts under the SIL Open Font License.

<p align="center"><sub>Designed and built by <a href="https://rjoshi141.github.io/portfolio-v2/">Ritika Joshi</a></sub></p>
