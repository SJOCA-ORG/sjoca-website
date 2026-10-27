# Moving sjoca.org — the domain, the DNS, and the cutover

Written for Mitch, to follow while doing it. Recorded 26 October 2026;
steps 2 and 3 corrected 27 October after the transfer landed.

The whole point of this document: **you never need access to Amazon Route 53.**
DNS is public by design. Everything the zone serves is readable by anyone, and
it is all written down below.

---

## Where this stands — 27 October 2026

**The domain move is done.** Steps 1 to 4 below are complete. What is left is the
website cutover, which is a separate thing, and is step 5.

| | |
|---|---|
| Registration | **Namecheap**, transferred 26 October 2026. Auto-renew on, registrant contact checked. |
| Renewal | **21 January 2028** — the transfer added a year. |
| DNS | **Namecheap BasicDNS** — `dns1`/`dns2.registrar-servers.com`, delegated 27 October, 22:28 UTC. |
| The zone | Nine records, live and verified at the nameserver and across four public resolvers. |
| Mail | Flowing throughout. Never interrupted. |
| Website | Still Google Sites, deliberately. `www.sjoca.org` returns 200. |

Three things remain, none urgent:

- **DKIM** — generate the key at admin.google.com and add the TXT record. Now
  unblocked, because the DNS is finally ours to edit.
- **Two MX names** — Namecheap's Gmail preset used Google's legacy
  `aspmx2`/`aspmx3.googlemail.com` for the two priority-10 servers instead of
  `alt3`/`alt4.aspmx.l.google.com`. Both are Google's and both deliver; worth
  aligning so that a future reader need not wonder which is right.
  `script/zone_compare.sh` carries it as an **accepted variance**, not a fault.
- **An `A` record on the bare domain** — step 5, and the one thing that must not
  be forgotten on cutover day.

`script/zone_compare.sh` shows all of it at once.

---

## The one idea that makes this safe

Two separate things get muddled together:

| | What it is | How long |
|---|---|---|
| **Registration** | Who the registrar is — Amazon today, Namecheap next. | 5–7 days |
| **DNS** | Which nameservers answer, and what records they serve. This is where `www` and mail actually live. | Hours |

**Transferring the registration does not move your DNS.** Route 53 keeps
answering until the nameservers are changed, which is a separate action you take
later. That is what lets this be four reversible steps instead of one big bang.

And the step that actually ends the old website — repointing `www` — is the
**last** one, is a single record, and is undone by putting the old value back.
Moving the domain does not switch off the Google Sites site. Repointing `www` does.

---

## The zone we had to reproduce

Read from public DNS on 26 October 2026, while Route 53 was still authoritative.
This is what had to be carried across, and it is the baseline written into
`script/zone_compare.sh`.

```
NS       ns-118.awsdns-14.com
         ns-757.awsdns-30.net
         ns-1141.awsdns-14.org
         ns-1971.awsdns-54.co.uk

MX       1   aspmx.l.google.com
         5   alt1.aspmx.l.google.com
         5   alt2.aspmx.l.google.com
         10  alt3.aspmx.l.google.com
         10  alt4.aspmx.l.google.com

TXT  @   google-site-verification=V_TjGTgxUH0EINZKqMGn_Q-HtPw-t54Rjs0eucgf5sI

CNAME www  ghs.googlehosted.com     <- the Google Sites website

A    @   (none)                     <- why sjoca.org fails without the www
```

**How sure is this?** Three checks were run against the AWS nameservers directly:

- A full zone dump (`AXFR`) — refused, as every public nameserver should.
- A wildcard probe — none exists.
- 24 likely names asked one at a time (`mail`, `webmail`, `autodiscover`, `smtp`,
  `imap`, `vpn`, `portal`, `blog`, `giving`, `donate`, `staging`, `dev`, `lists`…)
  — **every one empty.**

Public DNS only answers questions you know to ask, so a record at a name nobody
guessed would not appear. Given the above, that is unlikely. The verification
step below catches it anyway, before it can do harm.

**Those five MX records are Google Workspace's standard published set** — the
same for every Workspace domain on earth. Even with no access at all, they are
reproducible exactly.

---

## What was missing, and went in with the move

Route 53 had none of these. Two of the three are now live.

| | Type | Host | Value | Why |
|---|---|---|---|---|
| ✓ | TXT | `@` | `v=spf1 include:_spf.google.com ~all` | Without it, anyone can send email claiming to be from @sjoca.org. |
| ✓ | TXT | `_dmarc` | `v=DMARC1; p=none; rua=mailto:itmanager@sjoca.org` | Reports on who is trying. `p=none` only watches; it rejects nothing. |
| — | TXT | `google._domainkey` | the DKIM key — see below | Survives forwarding, where SPF does not. |

Five years of parish email went out with nothing asserting who was allowed to send
it. That was the real finding of this exercise, and it had nothing to do with the
website.

### DKIM

**What it is.** SPF says "these servers are allowed to send for us". DKIM says
something stronger about each individual message: Google signs every outgoing
message with a private key, and publishes the matching public key in DNS. A
receiving server checks the signature and knows the message genuinely came from
sjoca.org and was not altered on the way.

**Why bother.** Mail that gets forwarded — to a personal Gmail, to a parish list
— usually fails SPF, because the forwarding server is not one of Google's. DKIM
survives forwarding. Without it you can never safely turn DMARC up from
`p=none` to actually rejecting forgeries, because doing so would throw away real
parish mail.

Right now there is no DKIM record: `google._domainkey.sjoca.org` is empty.

**You can do this.** `itmanager@sjoca.org` reaches admin.google.com — confirmed
26 October 2026.

**Where to find it.** admin.google.com → **Apps** → **Google Workspace** →
**Gmail** → **Authenticate email**. Pick sjoca.org, then **Generate new record**
— take the 2048-bit key, leave the prefix as `google`.

It hands you a TXT record:

| Type | Host | Value |
|---|---|---|
| TXT | `google._domainkey` | `v=DKIM1; k=rsa; p=` + a very long key |

Add it to DNS, go back to that page, and press **Start authentication**. Google
checks for the record and may take up to 48 hours to confirm.

**The gotcha.** A 2048-bit key is longer than 255 characters, which is the most
a single DNS text string can hold, so it has to be stored as several chunks.
Namecheap normally does this for you when you paste the whole value. If it
refuses the record or the verification never completes, that is the reason —
split the value into quoted pieces, or fall back to a 1024-bit key, which is
weaker but fits.

**When.** Now, whenever there is half an hour. The blocker is gone: the DNS is
ours, so the record can simply be added under **Advanced DNS**, which exists now
that BasicDNS is the active selection.

Three things, in this order, and the order is the only part that matters:

1. Generate the key at admin.google.com. Changes nothing on its own.
2. Add the TXT record at Namecheap. It sits inert in DNS until step 3.
3. **Then** press **Start authentication** on that same Google screen.

Pressing it before the record exists makes Google look, find nothing, and leave
the domain unauthenticated — then you are debugging a wait rather than a fault.

**Do not enter a placeholder.** In DKIM, `p=` with an empty value is valid syntax
meaning *this key is revoked*. A half-filled record is not inert, it is a
statement, and it is the opposite of the one you want.

**Afterwards, much later.** Once SPF and DKIM have both been verified and the
DMARC reports look clean for a few weeks, DMARC can be raised from `p=none` to
`p=quarantine` and eventually `p=reject`. That is the point at which forging
parish email stops working. Not now, and not in the same week as the cutover.

---

## The order of operations

### Step 0 — There is no console, and that is settled

Amazon's confirm-or-cancel email links into the Route 53 console. **Mitch cannot
reach it.** AWS Support issued the auth code after verifying he was the admin who
had lost the ability to log in; the account itself stayed shut. So the zone can
never be read directly, and the "start the transfer immediately" link is closed
too.

Neither matters.

**The transfer completed on its own**, as expected. Under ICANN rules a transfer
the losing registrar does not answer goes through after five days — which is what
the **2026-10-31** date in Amazon's email was. Nothing needed clicking. It landed
on **26 October**, ahead of that.

**And the zone is known as well as it can be.** On 26 October, with Route 53
still authoritative, **162 names** were asked for directly — every common mail,
Google, DKIM, web, admin and service name (`mail`, `webmail`, `autodiscover`,
`smtp`, `imap`, `vpn`, `giving`, `donate`, `sermons`, `newsletter`, `staging`,
`_dmarc`, `google._domainkey`, `_acme-challenge`, and 148 more). Plus a wildcard
probe and an attempted zone dump.

**Only `www` exists.** The seven records above are the whole zone.

The remaining risk — a record at a name nobody thought of — is now small, and the
verification step below catches it anyway, because Route 53 keeps answering until
the nameservers are switched.

**One thing to watch:** whoever holds the AWS account could cancel the transfer
before the 31st. Unlikely, but `script/domain_watch.sh` will say so — the status
would leave `pendingTransfer` with the registrar still Amazon.

### Step 1 — Transfer the registration to Namecheap  *(can start today)*

You have the auth code from Amazon.

- The domain must be **unlocked** at Amazon, and WHOIS privacy off long enough to
  receive the confirmation email. It goes to the registrant contact,
  `mitch@catprint.com`.
- Takes **5–7 days** on its own. Amazon emails a link to approve it
  **immediately** — worth using, and safe: Namecheap keeps the existing
  nameservers, so nothing about the site or mail changes. Capture the zone
  (step 0) before you click it.
- `script/domain_watch.sh` answers "is it done yet" in one line, and checks that
  the nameservers, the five MX records, the www CNAME and the Google
  verification token are all still intact.
- **Namecheap keeps the existing nameservers on a transfer.** It does not switch
  DNS to itself. Site and mail carry on untouched — this is what makes the step
  safe.
- A transfer **adds a year**, pushing renewal from 21 January 2027 to 2028.

Afterwards: turn **auto-renew on**, check the registrant contact, and put the
login in whatever the parish uses for shared credentials — not a personal account.
This project exists partly because the last person's account became unreachable.

**Done, 27 October** — auto-renew on, registrant contact checked. The shared-credentials
part is the one that outlives all of us; it is on [`TODO.md`](TODO.md) if it is not
done yet.

### Steps 2 and 3 — Build the zone, and switch the nameservers

**These turned out to be one action, not two.** Written up after doing it on
27 October, replacing what this document guessed beforehand — which was wrong in
three places, each of which cost time.

#### What is actually there

**There is no Advanced DNS tab while the nameservers are Custom DNS.** Namecheap
hides it completely — not greyed out, absent. So host records cannot be staged in
advance, and the plan of "type the records, then flip" was never available.

The only path is a wizard, and it runs forward only:

```
Domain List -> MANAGE -> Nameservers -> Namecheap BasicDNS
  -> three checkboxes:  [x] update Host Records
                        [x] update Mail Settings
                        [ ] leave Host Records and Mail Settings
  -> Host Records screen   (Record Name, Host, Target, TTL)
  -> Mail Settings screen  (MX | MXE | Email Forwarding | Private Email)
  -> SAVE
```

The Mail Settings screen offers **Cancel or Save, with no way back** to host
records. Cancel discards everything typed and leaves the domain untouched — we
did that once by accident, which is how we know the wizard commits nothing until
that final save.

**Which is the one piece of luck in the whole sequence.** Because it commits in a
single action, the zone goes live *complete*, with the delegation change. The gap
this document worried about — Namecheap authoritative for a half-built zone —
cannot happen by this route.

Tick **both** of the first two boxes. Tick only Mail Settings and the host records
screen never appears.

#### What went in

Host Records — four rows. `Record Name` is a free-text label, not part of DNS;
`Host` is the subdomain and `Target` is the value.

| Record Name | Type | Host | Target | TTL |
|---|---|---|---|---|
| `website-google-sites` | CNAME | `www` | `ghs.googlehosted.com.` | **5 min** |
| `google-workspace-verification` | TXT | `@` | `google-site-verification=V_TjGTgxUH0EINZKqMGn_Q-HtPw-t54Rjs0eucgf5sI` | Automatic |
| `spf-who-may-send-mail` | TXT | `@` | `v=spf1 include:_spf.google.com ~all` | Automatic |
| `dmarc-reports-only` | TXT | `_dmarc` | `v=DMARC1; p=none; rua=mailto:itmanager@sjoca.org` | Automatic |

The `www` CNAME gets a **five-minute TTL** on purpose: it is the record that
changes at cutover and the one you would want to put back fastest.

The DMARC reports go to `itmanager@sjoca.org`, not to Fr David — they are daily
XML attachments from every mail provider on earth, and they need to reach somebody
who will act on them. Keep the address **inside sjoca.org**: pointing `rua` at an
outside domain requires a matching authorisation record in *that* domain's DNS
(`sjoca.org._report._dmarc.example.com`), and without it every reporter silently
discards the reports.

Mail Settings — choose **MX**. Not MXE (points mail at a single IP), not Email
Forwarding, not Private Email; the last two move parish mail to Namecheap's own
servers, which would be a quiet disaster.

#### The fault, and why it did not hurt

**The Mail Settings screen silently dropped all five MX records.** Host records
saved, the delegation changed, and the zone went live with **no mail routing at
all** — `status: NOERROR, ANSWER: 0`, authoritative, certain there were no MX
records. Namecheap confirmed a glitch on their side and investigated.

It did no harm, for a reason worth understanding: **the `.org` registry had not yet
published the new delegation.** For about ten minutes after the save, whois showed
`dns1/dns2.registrar-servers.com` while the registry still answered with the four
AWS names — so the world kept asking Route 53, which kept serving the right MX
records. The error existed only in a zone nobody was being sent to yet.

That grace period is not something to rely on, but it is the reason the sequence in
this document is safe: **every irreversible thing happens behind an hour of TTL.**

The fix was Namecheap's **Gmail preset** on the Mail Settings screen, which created
the five records in one click. It used Google's legacy names for the two
priority-10 servers:

| Priority | Route 53 served | The preset created |
|---|---|---|
| 1 | `aspmx.l.google.com` | `aspmx.l.google.com` ✓ |
| 5 | `alt1.aspmx.l.google.com` | `alt1.aspmx.l.google.com` ✓ |
| 5 | `alt2.aspmx.l.google.com` | `alt2.aspmx.l.google.com` ✓ |
| 10 | `alt3.aspmx.l.google.com` | `aspmx2.googlemail.com` |
| 10 | `alt4.aspmx.l.google.com` | `aspmx3.googlemail.com` |

All four hosts resolve and all four are Google's. The `googlemail.com` names are
what Google published years ago and still runs. Mail delivers either way, and
those two only matter if the first three are unreachable. Recorded as an accepted
variance in `script/zone_compare.sh`, to be aligned when convenient.

#### Doing this for another parish

The second parish is coming, so: **use the Gmail preset from the start.** It is
the only part of the Mail Settings screen that demonstrably works, it produces
Google's own record set, and it removes five chances to mistype a hostname. Then
correct the two priority-10 names afterwards if exactness matters.

And expect no advance verification. Namecheap's nameservers answer `REFUSED` for a
domain until BasicDNS is selected, so there is nothing to compare against until
the moment of the flip. Verify immediately after, not before.

### Step 4 — Verify, then stop

Done, 27 October. The results:

```
delegated to   dns1.registrar-servers.com  dns2.registrar-servers.com
MX             5 records
TXT @          google-site-verification=V_TjGTgxUH0EINZKqMGn…   intact
TXT @          v=spf1 include:_spf.google.com ~all              new
TXT _dmarc     v=DMARC1; p=none; rua=mailto:itmanager@…         new
CNAME www      ghs.googlehosted.com.  ->  HTTP 200
```

And confirmed propagated, not just present — 8.8.8.8, 1.1.1.1, 9.9.9.9 and
208.67.222.222 all served five MX records and the right `www`.

**Nothing changed for the parish.** Mail flowed without interruption, and the
website being served is still the Google Sites one. That is the correct end state
for the domain move: the parish is on its own DNS, and nobody noticed.

Then stop. The website cutover is separate.

### Step 5 — The cutover, later

> #### Do not forget the `A` record
>
> `sjoca.org` with no `www` has never worked. There is a CNAME on `www` and
> **nothing on the apex**, so anyone who types the domain the way it is said aloud
> — and the way it is printed on everything — reaches nothing at all.
>
> It could not be fixed before now: the fix is a record in a zone we did not
> control. On cutover day it becomes one more line in a zone we do.
>
> **Both records change in the same edit**, so the domain is never half-moved:
>
> | Type | Host | Value |
> |---|---|---|
> | ALIAS (or A) | `@` | Render's address |
> | CNAME | `www` | Render's address |
>
> Namecheap's ALIAS record works at the apex where a CNAME is not allowed. Render
> will name the exact value when the domain is added there.

Reversed by putting `ghs.googlehosted.com.` back on `www` and deleting the apex
record. The `www` TTL is five minutes, so that reversal is live in five minutes.

Do not reach this step until the new site is deployed, carrying the right content,
with a login on the admin and Fr David's review behind it.

---


## Checking your work

Run these from any machine. No account access needed.

**`script/zone_compare.sh`** is the whole check, and it asks two questions it
keeps deliberately apart:

```
sjoca.org
  delegated to : dns1.registrar-servers.com dns2.registrar-servers.com
  asking       : dns1.registrar-servers.com

WHAT THE AUTHORITATIVE NAMESERVER HOLDS
  record                     expected           found
  mail (5 MX records)        1 aspmx.l.google.  accepted variance
  Google verification TXT    google-site-verif  as captured
  www CNAME                  ghs.googlehosted.  as captured
  A on the bare domain       (none)             absent
  SPF TXT                    (none)             present
  DMARC TXT                  (none)             present
  DKIM TXT                   (none)             absent

WHAT PUBLIC RESOLVERS ARE HANDING OUT
  8.8.8.8            5 MX, www -> ghs.googlehosted.com.
  1.1.1.1            5 MX, www -> ghs.googlehosted.com.
  ...
```

**The two halves are not the same question, and conflating them produced a false
alarm.** On 27 October the script reported "0 MX records — fix this before
anything else" when the zone had been correct for several minutes. It had asked
one machine's resolver, which had cached *the absence* of MX records during the
glitch — and Namecheap's SOA sets negative caching to **3601 seconds**, so that
"no such record" would have stood for an hour whatever the truth was.

So: the top half is truth, asked of the authoritative nameserver with no cache in
the way, and a fault there is real. The bottom half is propagation, and a resolver
disagreeing means wait, not edit. The script now says which is which, finds the
authoritative nameserver from the registry rather than assuming, and treats the
two legacy MX names as an **accepted variance** — a difference somebody looked at
and signed for, which is not the same as a difference nobody noticed.

**`script/domain_watch.sh`** is the other one: registrar, status, expiry, and the
records that must not change, in one line each.

**If mail ever looks wrong, fix the MX records first and ask questions after** —
but check the top half of the output first, because the fault may be in the
asking. A website being down is embarrassing; mail going wrong is worse, because
what arrives at the parish arrives once. Senders queue and retry for days, so
minutes of bad DNS cost nothing. That is a reason not to panic, not a reason to
leave it.

---

## What can be done in parallel

Steps 1 to 4 blocked nothing, and that was the point. They moved the parish's DNS
off an account nobody could reach while leaving the **old Google Sites website
still serving** — the parish noticed nothing, because there was nothing to notice.

What remains on the website track: Fr David's review, and the content being right.
See [`TODO.md`](TODO.md).

The two tracks meet once, at step 5, and step 5 is two DNS records in one edit.
