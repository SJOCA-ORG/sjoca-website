# Moving sjoca.org — the domain, the DNS, and the cutover

Written for Mitch, to follow while doing it. Recorded 26 October 2026;
steps 2 and 3 corrected 27 October after the transfer landed.

The whole point of this document: **you never need access to Amazon Route 53.**
DNS is public by design. Everything the zone serves is readable by anyone, and
it is all written down below.

---

## Where this stands — 27 October 2026

| | |
|---|---|
| Registration | **Done.** Registrar reads `NameCheap, Inc.`, updated 26 Oct 14:13 UTC. |
| Renewal | Pushed to **21 January 2028** — the transfer's added year arrived. Auto-renew is on and the registrant contact is checked. |
| Lock | `transferPeriod` + `clientTransferProhibited` — the normal 60-day post-transfer lock. It does **not** block nameserver or DNS changes. |
| Nameservers | Still the four AWS ones. **Route 53 is still authoritative and still readable**, which is what makes step 2 safe to do carefully. |
| DNS records | Unchanged from the capture below, re-read 27 October. |

Next action: **step 2**, below.

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

**When.** Generate the key and enter the record **during step 2**, with everything
else. There is no reason to make a second trip: generating a key changes nothing
on its own, and the TXT record sits inert in DNS until you press **Start
authentication**. So the order is

1. Step 2 — generate the key at admin.google.com, and type the record in with the
   others.
2. Step 3 — flip the nameservers.
3. Confirm mail still flows (step 4).
4. *Then* go back to Authenticate email and press **Start authentication**.

Pressing it before step 3 would have Google look at Route 53, which does not have
the record and which you cannot edit. That is the only ordering that matters.

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

### Step 2 — Build the zone at Namecheap  *(do this now)*

**Do not touch the Nameservers dropdown in this step.** Leave it on **Custom DNS**
with the four AWS names. Everything here happens under **Advanced DNS**, where
Namecheap will store host records and show a banner saying they are not in use —
which is exactly what you want. They go live the moment step 3 flips the dropdown,
so the zone is complete *before* it is ever asked a question.

The earlier draft of this document had you select BasicDNS here and verify
afterwards. That ordering does not work; see the note at the head of step 3.

Enter these under **Advanced DNS**:

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
| TXT | `google._domainkey` | `v=DKIM1; k=rsa; p=` + the key from admin.google.com | — |

The first seven lines are what Route 53 serves today, copied exactly. The last
three are new and are the reason this step is worth doing attentively rather than
quickly — see [What is missing](#what-is-missing-and-should-be-added-while-you-are-in-there)
above for why each one earns its place, and the DKIM note for where the key comes
from.

**Delete Namecheap's parking records first.** New domains arrive with a
`CNAME www -> parkingpage.namecheap.com` and an A record on `@`. They will fight
the real ones.

Leave `@` with no A record for now. It gets one at cutover.

**Then stop and read it back.** This is the one moment Route 53 is still running
beside what you have just typed, so a comparison is possible:

```bash
script/zone_compare.sh
```

At this point it can only reach one of the two sides: Namecheap holds no zone
until step 3, so its column reads `no zone`. What it gives you is the Amazon
column and the baseline, printed side by side — the authoritative values, on
screen, to read your seven copied lines against. Do that, then go to step 3.

### Step 3 — Switch the nameservers

On the domain page, the **Nameservers** dropdown will read **Custom DNS** with the
four AWS names. Change it to **Namecheap BasicDNS** and save. That is the whole
action — Namecheap tells the `.org` registry and the world follows.

#### Why this cannot be verified in advance

Checked on 27 October: asking Namecheap's nameservers about sjoca.org returns

```
dig sjoca.org SOA @dns1.registrar-servers.com   ->   status: REFUSED
```

**They hold no zone for this domain**, and selecting BasicDNS is what creates one.
So there is no way to compare Namecheap against Amazon *before* flipping. The
comparison the earlier draft promised was not available.

What replaces it is the ordering in step 2: type every record while the dropdown
is still Custom DNS, so the zone exists complete at the instant it goes live, then
check within seconds of saving.

#### How long, really

Not 48 hours, as this document used to say. Measured at the registry:

| Record | TTL |
|---|---|
| The `NS` delegation, at the `.org` registry | **3600s** — one hour |
| `MX` | **300s** — five minutes |

So the change spreads in about an hour, and a mistake spreads in an hour too —
which cuts both ways and is the better trade. A correction reaches the world in
five minutes for mail. Lowering TTLs a day ahead would be the usual precaution and
needs Route 53 access; at these TTLs it buys nothing.

#### The minute after you press save

```bash
script/zone_compare.sh
```

Now it can reach both sides, and it compares them line by line. Everything should
read `agree`. If the MX lines do not, fix them in Advanced DNS and run it again —
mail first, questions after.

#### And if mail is briefly wrong, nothing is lost

The old warning in this document was more frightening than the truth. A sending
server that cannot deliver **queues the message and retries for days**; Google
retries for about four. A gap of minutes or hours in the MX records delays mail,
it does not bounce it. What loses mail is a wrong-but-working MX pointing at a
server that accepts and discards — which is not a mistake available here, because
every value in the table is Google's own.

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

**`script/zone_compare.sh`** is the whole check. It asks each nameserver directly,
holds the 26 October capture as a baseline, and prints one line per record. It
keeps working after Route 53 is gone, because the baseline is written into the
script.

```
record                       baseline         amazon           namecheap
---------------------------- ---------------- ---------------- ----------------
mail (5 MX records)          1 aspmx.l.googl  as captured      as captured
Google verification TXT      google-site-ver  as captured      as captured
www CNAME                    ghs.googlehoste  as captured      as captured
A on the bare domain         (none)           absent           absent
SPF TXT (new)                (none)           absent           present
DMARC TXT (new)              (none)           absent           present
DKIM TXT (new)               (none)           absent           present
```

`absent` in the amazon column for the last three is right — they are the records
being added. `MISSING` or `DIFFERS` anywhere is a typo to go and fix; the script
exits non-zero and says which column means what.

**`script/domain_watch.sh`** is the other one: registrar, status, expiry, and the
records that must not change, in one line each.

**After flipping** — watch the change spread:

```bash
dig +short NS sjoca.org          # should become the Namecheap pair
dig +short MX sjoca.org          # must stay the five Google records
dig +short CNAME www.sjoca.org   # ghs.googlehosted.com until cutover day
```

**If mail ever looks wrong, fix the MX records first and ask questions after.**
A website being down is embarrassing. Mail going wrong is worse, because what
arrives at the parish arrives once. The reassurance in step 3 holds — senders
queue and retry for days, so minutes of bad DNS cost nothing — but that is a
reason not to panic, not a reason to leave it.

---

## What can be done in parallel

Step 1 blocked nothing, and steps 2–4 block nothing either. They move the parish's
DNS off an account nobody can reach, and leave the **old Google Sites website
still serving**. The website work carries on beside them: login, rehearsing the
revert, deploying, copying the database up. See [`TODO.md`](TODO.md).

The two tracks only meet at step 5, and step 5 is one DNS record.
