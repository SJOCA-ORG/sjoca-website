#!/usr/bin/env bash
# Does the new DNS say the same thing as the old DNS?
#
# Asks Amazon's nameservers and Namecheap's the same questions, and compares both
# against the zone as it was captured on 26 October 2026 -- which is written into
# this script, so the check still works after Route 53 is gone and there is
# nothing left to ask.
#
# Run it twice: once while step 2 is in progress (Namecheap will say "no zone",
# which is correct and expected), and again in the minute after step 3 flips the
# nameservers, when every line should read "as captured".
#
# See docs/dns.md. No account access is needed for any of this.
set -u

DOMAIN="${1:-sjoca.org}"
AMAZON="ns-118.awsdns-14.com"
NAMECHEAP="dns1.registrar-servers.com"

# ---- the zone as captured, 26 October 2026 -------------------------------
# Seven records, verified against 162 probed names. The first four existed in
# Route 53; the last three are ones we are ADDING, so "absent" on the Amazon
# side is right and "present" on the Namecheap side is the goal.
BASE_mx="1 aspmx.l.google.com,10 alt3.aspmx.l.google.com,10 alt4.aspmx.l.google.com,5 alt1.aspmx.l.google.com,5 alt2.aspmx.l.google.com,"
BASE_verify="google-site-verification=V_TjGTgxUH0EINZKqMGn_Q-HtPw-t54Rjs0eucgf5sI,"
BASE_www="ghs.googlehosted.com,"
BASE_root=""
BASE_spf=""
BASE_dmarc=""
BASE_dkim=""

NEW_KINDS=" spf dmarc dkim "          # expected to be absent at Amazon
LABELS="mx:mail (5 MX records)
verify:Google verification TXT
www:www CNAME
root:A on the bare domain
spf:SPF TXT (new)
dmarc:DMARC TXT (new)
dkim:DKIM TXT (new)"

ask() { dig +short "$2" "$3" "@$1" 2>/dev/null | sed 's/"//g; s/\.$//' | sort; }

reachable() {
  dig +time=3 +tries=1 "$DOMAIN" SOA "@$1" 2>/dev/null \
    | grep -q 'status: NOERROR'
}

fingerprint() {   # server kind
  local s=$1 k=$2 v
  case "$k" in
    mx)     ask "$s" MX    "$DOMAIN"                      | tr '\n' ',' ;;
    verify) ask "$s" TXT   "$DOMAIN" | grep '^google-site-verification=' | tr '\n' ',' ;;
    spf)    ask "$s" TXT   "$DOMAIN" | grep '^v=spf1'     | tr '\n' ',' ;;
    www)    ask "$s" CNAME "www.$DOMAIN"                  | tr '\n' ',' ;;
    root)   ask "$s" A     "$DOMAIN"                      | tr '\n' ',' ;;
    dmarc)  ask "$s" TXT   "_dmarc.$DOMAIN" | grep '^v=DMARC1' | tr '\n' ',' ;;
    dkim)   v=$(ask "$s" TXT "google._domainkey.$DOMAIN" | grep '^v=DKIM1' | tr -d '\n')
            [ -n "$v" ] && printf 'a %s-character key,' "${#v}" ;;
  esac
}

verdict() {   # kind baseline actual   -> one word or phrase
  local k=$1 base=$2 got=$3
  if [ "$base" = "$got" ]; then
    [ -z "$base" ] && echo "absent" || echo "as captured"
  elif [ -z "$got" ]; then
    echo "MISSING"
  elif [ -z "$base" ]; then
    echo "present"
  else
    echo "DIFFERS"
  fi
}

# ---- is each side answering at all? --------------------------------------
amazon_up=no;    reachable "$AMAZON"    && amazon_up=yes
namecheap_up=no; reachable "$NAMECHEAP" && namecheap_up=yes

echo "comparing $DOMAIN"
echo "  amazon    $AMAZON   $([ $amazon_up = yes ]    && echo "answering" || echo "NOT answering -- Route 53 zone gone?")"
echo "  namecheap $NAMECHEAP  $([ $namecheap_up = yes ] && echo "answering" || echo "no zone yet (correct until step 3)")"
echo
printf '%-28s %-16s %-16s %s\n' "record" "baseline" "amazon" "namecheap"
printf '%-28s %-16s %-16s %s\n' "----------------------------" "----------------" "----------------" "----------------"

problems=0
while IFS=: read -r kind label; do
  eval "base=\$BASE_$kind"
  shown=$([ -z "$base" ] && echo "(none)" || echo "${base%%,*}" | cut -c1-15)

  if [ $amazon_up = yes ]; then
    got_a=$(fingerprint "$AMAZON" "$kind"); v_a=$(verdict "$kind" "$base" "$got_a")
  else
    v_a="unreachable"
  fi

  if [ $namecheap_up = yes ]; then
    got_n=$(fingerprint "$NAMECHEAP" "$kind"); v_n=$(verdict "$kind" "$base" "$got_n")
  else
    v_n="no zone"
  fi

  printf '%-28s %-16s %-16s %s\n' "$label" "$shown" "$v_a" "$v_n"

  # What counts as a problem depends on which side and whether it is a new record.
  case "$v_a" in MISSING|DIFFERS) problems=$((problems+1)) ;; esac
  if [ $namecheap_up = yes ]; then
    case "$v_n" in MISSING|DIFFERS) problems=$((problems+1)) ;; esac
    case "$NEW_KINDS" in *" $kind "*)
      [ "$v_n" = absent ] && echo "   .. still to add at Namecheap" ;;
    esac
  fi
done <<< "$LABELS"

echo
# ---- and what is actually being served to the world right now ------------
printf 'the world currently asks : '; dig +short NS "$DOMAIN" | sort | tr '\n' ' '; echo
printf 'and is answered with     : '; n=$(dig +short MX "$DOMAIN" | wc -l | tr -d ' '); echo "$n MX records, www -> $(dig +short CNAME www."$DOMAIN")"
echo

if [ "$n" != "5" ]; then
  echo "!! MAIL: expected 5 MX records in public DNS and found $n."
  echo "   Fix that in Namecheap Advanced DNS before anything else. Senders queue"
  echo "   and retry for days, so nothing is lost yet -- but do it now."
  exit 1
fi

if [ $problems -gt 0 ]; then
  echo "!! $problems record(s) disagree with the captured zone. Read the table above."
  echo "   A DIFFERS or MISSING on the namecheap column is a typo to correct."
  echo "   A DIFFERS on the amazon column means somebody edited Route 53."
  exit 1
fi

echo ">> Every record agrees with the zone as captured."
if [ $namecheap_up = no ]; then
  echo "   Namecheap holds no zone yet, which is right until step 3. Nothing is"
  echo "   verifiable there in advance -- see docs/dns.md, step 3."
fi
