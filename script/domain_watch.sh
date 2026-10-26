#!/usr/bin/env bash
# Is the sjoca.org transfer done, and is anything broken?
#
# Run it whenever you want to know. It answers in one line, then shows the
# records that must not change.
set -u
DOMAIN="${1:-sjoca.org}"

w=$(whois "$DOMAIN" 2>/dev/null)
registrar=$(printf '%s\n' "$w" | grep -i '^Registrar:' | head -1 | cut -d: -f2- | sed 's/^ *//')
status=$(printf '%s\n' "$w"  | grep -i '^Domain Status:' | head -1 | awk '{print $3}')
expiry=$(printf '%s\n' "$w"  | grep -i '^Registry Expiry Date:' | head -1 | cut -d: -f2- | cut -dT -f1 | sed 's/^ *//')

echo "registrar : ${registrar:-unknown}"
echo "status    : ${status:-unknown}"
echo "expires   : ${expiry:-unknown}"
echo

case "$status" in
  pendingTransfer)
    echo ">> STILL MOVING. Nothing to do. Check again in a few hours."
    echo "   If Namecheap emailed you asking to confirm, answer it -- otherwise"
    echo "   this sits for the full five days before completing on its own." ;;
  *)
    if printf '%s' "$registrar" | grep -qi namecheap; then
      echo ">> IT HAS LANDED. Do the checks below NOW, before anything else."
    else
      echo ">> Not at Namecheap yet, and not marked as transferring."
      echo "   If this persists, the transfer may have failed -- check your email."
    fi ;;
esac

echo
echo "--- these must not change until you deliberately change them ---"
printf 'nameservers : '; dig +short NS "$DOMAIN" | sort | tr '\n' ' '; echo
printf 'mail (MX)   : '; n=$(dig +short MX "$DOMAIN" | wc -l | tr -d ' '); echo "$n records"
dig +short MX "$DOMAIN" | sort | sed 's/^/              /'
printf 'www         : '; dig +short CNAME www."$DOMAIN"; echo
printf 'verification: '; dig +short TXT "$DOMAIN" | grep -o 'google-site-verification=[^"]*' || echo "MISSING"

echo
if [ "$n" != "5" ]; then
  echo "!! MAIL: expected 5 MX records and found $n. Fix this before anything else."
fi
if ! dig +short CNAME www."$DOMAIN" | grep -q ghs.googlehosted.com; then
  echo "!! WWW no longer points at Google Sites. Expected while cutting over; alarming otherwise."
fi
