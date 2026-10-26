# Signing in to the editor

Written 26 October 2026, when the admin stopped being local-only.

Until now the editor had no login at all. It refused to serve in production,
which was enough while it ran on one laptop, and is not enough the day
`sjoca.org` points at it.

---

## One lock

The login. Every page under `/admin` requires it, everywhere, including locally.

There was briefly a second: `ADMIN_ENABLED`, an environment variable production
had to be given before the editor would answer at all. It was built when there
was no login and was the only protection, and kept afterwards out of caution.

**Removed on 26 October 2026**, at Mitch's request and rightly. With a real
login it bought almost nothing — and it brought its own bug. The sign-in and
password-reset pages are separate controllers that never inherited it, so with
the switch off the editing pages refused but the login form was still served:
"switched off" did not mean switched off. A second mechanism that is nearly
right is worse than one mechanism that is right.

What it was for, and what replaces it:

| Was for | Now |
|---|---|
| Deploying before the editor should be usable | The login. Nobody signs in without a password. |
| The window while the database is copied up | Copy before the domain points at the site; nobody knows the address. |
| Turning the editor off in a hurry | Change the password, or scale the service down. |

---

## Making an account

```bash
bin/rails admin:user EMAIL=itmanager@sjoca.org     # prompts, twice, hidden
bin/rails admin:users                              # who can sign in
```

The same command changes an existing password. On a server where nothing can be
typed, `PASSWORD=...` works — but never pass a password as a command-line
argument on a shared machine, where it lands in shell history and in the process
list for anyone to read.

**The repo is public.** No password goes in it, and none goes in Rails
credentials either, so one can be changed without a deploy.

---

## What the login does, and why

| | |
|---|---|
| **bcrypt** | Only a one-way digest is stored. A database dump pulled down for local work is not a way in. |
| **Twelve-hour idle limit** | Long enough for a morning's editing; short enough that a session left open on a parish hall computer is dead the next day. |
| **New session on sign-in** | `reset_session` runs first, so a cookie planted before signing in is not valid after. |
| **One answer for every failure** | "That email and password did not match", whether or not the address exists — saying otherwise confirms who has an account. |
| **Equal timing** | A hash is computed even when there is no such user, so a wrong address and a wrong password take the same time to answer. |
| **10 attempts in 3 minutes** | Counted per email address, not per IP: a parish shares an address, and locking the whole building out because one person is guessing is its own kind of failure. |
| **Minimum 8, with a mix** | A capital, a small letter, and a number or symbol. Mitch's call on 26 October 2026, over my preference for plain length — composition rules tend to produce `Password1!`, but 8 with three classes is a defensible bar and it is his parish. |

Failed attempts are logged with the address tried and the IP. Never the password.

---

## The trap this uncovered

`rate_limit` counts through a cache, **and it captures that cache when the
controller class loads** — not per request. The test environment cached into a
null store, so the limiter counted into nothing: present, passing review, and a
complete no-op. The spec caught it; a reading would not have.

Production had no cache store configured either, and would have inherited a
default. It now says what it uses. **If the rate-limiting spec is ever changed to
"skip", that is the symptom of this coming back.**

---

## The spec that matters

`spec/requests/authentication_spec.rb` walks **every GET route under `/admin`**
and asserts each one sends a signed-out visitor to the login page. Add a
controller in six months and forget to protect it, and the suite says so. Nobody
has to remember.

---

## Your own account

`/admin/account`, reached by clicking your name in the top bar. It shows who you
are and lets you change your password.

**It asks for the current password first.** A session left open on a parish hall
computer hands whoever walks past the cookie; it must not also hand them the
account. Changing the password starts a new session and cancels every
outstanding reset link at the same time.

This page was missing for the first few hours after the login was built — reset
by email and a rake task existed, but nothing for somebody already signed in,
which is the first thing anyone looks for.

## Showing the password

Every password field on every admin page carries a **Show / Hide** control —
an eye and a word, because an unlabelled icon is a guess. Added at Mitch's
request, in his words, "for us old people that have a hard time typing".

Not a nicety. These are eight-character passwords with a capital and a symbol,
typed into a field of dots, on a laptop, often through reading glasses. The
alternative to showing it is three failed attempts and a rate limit.

It is applied by script to `input[type=password]` across the whole admin, so a
password field added later is covered without anyone remembering. It is
`type="button"` — a submit button here would sign you in every time you tried
to look — and it puts the cursor back where it was, because changing an input's
type sends it to the end, which is infuriating halfway through typing.

## Forgetting a password

"Forgotten your password?" on the sign-in page sends a link. Built 26 October
2026 and tested by sending a real one.

**The token needs no table of its own.** Rails signs it, and it carries the
password's salt — so **changing the password invalidates every link already
issued**, including the one just used and any a thief is holding. Two hours,
one use, nothing to clean up.

| | |
|---|---|
| Same answer for every address | "If that address has an account, a link is on its way" — whether or not it does. The form must not become a way to find out who has one. |
| 3 requests per 15 minutes | By address. Enough for someone mistyping their own; not enough to post mail at somebody repeatedly. |
| Signed in on success | The link is spent either way, so a second step would only be ceremony. |

**Mail goes through the parish's own Workspace account** — `itmanager@sjoca.org`,
an app password in credentials or `SMTP_PASSWORD` in the environment. That is a
stopgap, said plainly: a second parish is coming and will run as its own
instance, and at that point mail belongs with a service that is nobody's mailbox.
Every setting comes from the environment, so that move is configuration and a
DNS record, not code.

**Until SPF and DKIM exist, reset mail may land in spam** for anyone not on
Gmail. Those records wait on the nameserver move — see [`dns.md`](dns.md).

### The one that would have been nasty

The mail initializer first set `:smtp` in **every** environment where credentials
were present — and the test environment reads the same credentials file. The
suite was one `deliver_now` away from sending real mail to real people. It now
refuses to use anything but `:test` under test, whatever the credentials say.

## Not built yet
- **More than one person**, and roles below superadmin. The model takes them —
  `users.role` exists — but no interface does.
- **Second superadmin.** One account held by one person is the position this
  project is already cleaning up after, both at AWS and in Workspace.
