# Moving sjoca.org — the domain, the DNS, and the cutover

Written for Mitch, to follow while doing it. Recorded 26 October 2026.

The whole point of this document: **you never need access to Amazon Route 53.**
DNS is public by design. Everything the zone serves is readable by anyone, and
it is all written down below.

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

## The zone as it stands

Read from public DNS on 26 October 2026. This is the complete list.

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

## What is missing, and should be added while you are in there

None of these exist today.

| Type | Host | Value | Why |
|---|---|---|---|
| TXT | `@` | `v=spf1 include:_spf.google.com ~all` | Without it, anyone can send email claiming to be from @sjoca.org. |
| TXT | `_dmarc` | `v=DMARC1; p=none; rua=mailto:frdavid@sjoca.org` | Reports on who is trying. `p=none` only watches; it rejects nothing. |

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

**When.** After the nameservers are on Namecheap (step 3) and you have confirmed
mail still flows. It needs to go into whichever DNS is authoritative, and until
step 3 that is Route 53, which you cannot edit. Generating the key early is
harmless — nothing changes until you press Start authentication — but there is
no advantage either.

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

**The transfer completes on its own.** Under ICANN rules a transfer the losing
registrar does not answer goes through after five days — which is what the
**2026-10-31** date in that email is. Nothing to click. It lands by then.

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

### Step 2 — Build the zone at Namecheap  *(when the domain lands, not before)*

Namecheap can only manage DNS for a domain already in your account, so this waits
for the transfer to complete. Check as soon as it appears — if **Advanced DNS** is
editable during "pending transfer", you can get a head start.

Set the domain to **Namecheap BasicDNS**, then enter, under **Advanced DNS**:

| Type | Host | Value | Priority |
|---|---|---|---|
| MX | `@` | `aspmx.l.google.com.` | 1 |
| MX | `@` | `alt1.aspmx.l.google.com.` | 5 |
| MX | `@` | `alt2.aspmx.l.google.com.` | 5 |
| MX | `@` | `alt3.aspmx.l.google.com.` | 10 |
| MX | `@` | `alt4.aspmx.l.google.com.` | 10 |
| TXT | `@` | `google-site-verification=V_TjGTgxUH0EINZKqMGn_Q-HtPw-t54Rjs0eucgf5sI` | — |
| CNAME | `www` | `ghs.googlehosted.com.` | — |
| TXT | `@` | `v=spf1 include:_spf.google.com ~all` | — |
| TXT | `_dmarc` | `v=DMARC1; p=none; rua=mailto:frdavid@sjoca.org` | — |

**Delete Namecheap's parking records first.** New domains arrive with a
`CNAME www -> parkingpage.namecheap.com` and an A record on `@`. They will fight
the real ones.

Leave `@` with no A record for now. It gets one at cutover.

### Step 3 — Switch the nameservers

On the domain page, the **Nameservers** dropdown will read **Custom DNS** with the
four AWS names. Change it to **Namecheap BasicDNS** and save. That is the whole
action — Namecheap tells the `.org` registry and the world follows.

**Do step 2 completely first, and verify it.** Flip this before the records exist
and there is a window where Namecheap answers for sjoca.org with nothing in it:
**website down and mail bouncing.**

Expect up to **48 hours** where some of the internet asks Route 53 and some asks
Namecheap. Because both serve identical records, nobody notices. (Normally you
would lower TTLs a day ahead to shorten this; that needs Route 53 access, so
simply allow the time.)

### Step 4 — Verify, then stop

After step 3 you are still running **the old Google Sites website**, on your own
DNS, with mail flowing. Nothing has changed for the parish. Confirm it:

- `https://www.sjoca.org` loads the current site.
- Send a message to a @sjoca.org address and watch it arrive.

Then stop. Steps 1–3 are the domain move. The website cutover is separate.

### Step 5 — The cutover, later

One record: point `www` at Render, and add an ALIAS on `@` so the bare
`sjoca.org` finally works — a fault on the current site, not something we
introduced. Reversed by putting `ghs.googlehosted.com.` back.

Do not reach this step until the new site is deployed, carrying the right
content, and has a login on the admin.

---

## Checking your work

Run these from any machine. No account access needed.

**Before flipping the nameservers** — ask Namecheap and Amazon the same questions
and compare. They must agree on every line.

```bash
# What Namecheap will serve once it is authoritative
for r in MX TXT; do dig +short $r sjoca.org @dns1.registrar-servers.com; done
dig +short CNAME www.sjoca.org @dns1.registrar-servers.com

# What Amazon serves today
for r in MX TXT; do dig +short $r sjoca.org @ns-118.awsdns-14.com; done
dig +short CNAME www.sjoca.org @ns-118.awsdns-14.com
```

**After flipping** — watch the change spread:

```bash
dig +short NS sjoca.org          # should become the Namecheap pair
dig +short MX sjoca.org          # must stay the five Google records
dig +short CNAME www.sjoca.org   # ghs.googlehosted.com until cutover day
```

**If mail ever looks wrong, fix the MX records first and ask questions after.**
A website being down is embarrassing. Mail bouncing loses things that were sent
to the parish and never arrive again.

---

## What can be done in parallel

Step 1 blocks nothing. While the transfer runs, the website work carries on:
login, rehearsing the revert, merging to `main`, deploying, copying the database
up. See [`TODO.md`](TODO.md).

The two tracks only meet at step 5, and step 5 is one DNS record.
