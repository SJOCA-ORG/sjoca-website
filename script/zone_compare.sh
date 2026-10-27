#!/usr/bin/env bash
# Is the parish's DNS saying what it should say?
#
# Two questions, kept apart on purpose, because confusing them produced a false
# alarm on 27 October that sent somebody looking for a fault that was not there:
#
#   1. TRUTH -- what do the authoritative nameservers hold? Asked directly, so
#      no cache anywhere can colour the answer. A wrong answer here is a fault.
#
#   2. PROPAGATION -- what are public resolvers currently handing out? These lag,
#      and worse, they cache ABSENCE: Namecheap's SOA sets negative caching to
#      3601 seconds, so a resolver that asked for MX records during a gap will
#      insist there are none for the next hour even after they exist. That is
#      not a fault, it is arithmetic, and the script says so rather than shouting.
#
# Run it any time. No account access is needed for any of it.
# See docs/dns.md.
set -u

DOMAIN="${1:-sjoca.org}"
REGISTRY="a0.org.afilias-nst.info"
RESOLVERS="8.8.8.8 1.1.1.1 9.9.9.9 208.67.222.222"
OLD_AWS="ns-118.awsdns-14.com"          # kept while Route 53 still answers

# ---- the zone as captured from Route 53, 26 October 2026 -----------------
# Seven records, verified against 162 probed names. The first four were what
# Amazon served; the last three are ones we added at the move.
BASE_mx="1 aspmx.l.google.com,10 alt3.aspmx.l.google.com,10 alt4.aspmx.l.google.com,5 alt1.aspmx.l.google.com,5 alt2.aspmx.l.google.com,"
BASE_verify="google-site-verification=V_TjGTgxUH0EINZKqMGn_Q-HtPw-t54Rjs0eucgf5sI,"
BASE_www="ghs.googlehosted.com,"
BASE_root=""
BASE_spf=""
BASE_dmarc=""
BASE_dkim=""

# ---- differences we have looked at and accepted --------------------------
# A finding either gets fixed or gets a signature; it never just gets ignored.
# Each line: kind|the value we will also accept|why
ACCEPTED="mx|1 aspmx.l.google.com,10 aspmx2.googlemail.com,10 aspmx3.googlemail.com,5 alt1.aspmx.l.google.com,5 alt2.aspmx.l.google.com,|Namecheap's Gmail preset used Google's legacy names for the two priority-10 servers: aspmx2/aspmx3.googlemail.com where Route 53 had alt3/alt4.aspmx.l.google.com. All four are Google's and all four deliver, and these two are the third tier of fallback. NOT being changed, decided 27 Oct 2026: Namecheap's Mail Settings is one radio button, Gmail preset OR Custom MX, and Custom does not carry the preset's records over -- so correcting two names means retyping all five in the screen that silently dropped all five once already. Cosmetic exactness is not worth a mail outage. See docs/TODO.md."

WANTED="mx verify www root spf dmarc dkim"
label_for() { case "$1" in
  mx)     echo "mail (5 MX records)" ;;
  verify) echo "Google verification TXT" ;;
  www)    echo "www CNAME" ;;
  root)   echo "A on the bare domain" ;;
  spf)    echo "SPF TXT" ;;
  dmarc)  echo "DMARC TXT" ;;
  dkim)   echo "DKIM TXT" ;;
esac; }

ask() { dig +time=3 +tries=1 +short "$2" "$3" "@$1" 2>/dev/null | sed 's/"//g; s/\.$//' | sort; }

answering() { dig +time=3 +tries=1 "$DOMAIN" SOA "@$1" 2>/dev/null | grep -q 'status: NOERROR'; }

fingerprint() {   # server kind
  local s=$1 k=$2 v
  case "$k" in
    mx)     ask "$s" MX    "$DOMAIN"                                        | tr '\n' ',' ;;
    verify) ask "$s" TXT   "$DOMAIN" | grep '^google-site-verification='    | tr '\n' ',' ;;
    spf)    ask "$s" TXT   "$DOMAIN" | grep '^v=spf1'                       | tr '\n' ',' ;;
    www)    ask "$s" CNAME "www.$DOMAIN"                                    | tr '\n' ',' ;;
    root)   ask "$s" A     "$DOMAIN"                                        | tr '\n' ',' ;;
    dmarc)  ask "$s" TXT   "_dmarc.$DOMAIN" | grep '^v=DMARC1'              | tr '\n' ',' ;;
    dkim)   v=$(ask "$s" TXT "google._domainkey.$DOMAIN" | grep '^v=DKIM1' | tr -d '\n')
            [ -n "$v" ] && printf 'a %s-character key,' "${#v}" ;;
  esac
}

accepted_value() { printf '%s\n' "$ACCEPTED" | awk -F'|' -v k="$1" '$1==k {print $2}'; }
accepted_why()   { printf '%s\n' "$ACCEPTED" | awk -F'|' -v k="$1" '$1==k {print $3}'; }

# ---- who is authoritative, according to the registry itself --------------
AUTH=$(dig +time=3 +tries=2 NS "$DOMAIN" "@$REGISTRY" +noall +authority 2>/dev/null \
        | awk '$4=="NS" {print $5}' | sed 's/\.$//' | sort | head -1)
ALL_NS=$(dig +time=3 +tries=2 NS "$DOMAIN" "@$REGISTRY" +noall +authority 2>/dev/null \
        | awk '$4=="NS" {print $5}' | sed 's/\.$//' | sort | tr '\n' ' ')

echo "$DOMAIN"
echo "  delegated to : ${ALL_NS:-UNKNOWN -- could not reach the registry}"
echo "  asking       : ${AUTH:-nobody}"
old_up=no; answering "$OLD_AWS" && old_up=yes
[ $old_up = yes ] && echo "  (Route 53 still answers on $OLD_AWS, so it can still be compared)"
echo

if [ -z "$AUTH" ] || ! answering "$AUTH"; then
  echo "!! The delegated nameserver is not answering for $DOMAIN. Nothing else here"
  echo "   can be trusted until that is understood."
  exit 1
fi

# ---- 1. truth -----------------------------------------------------------
echo "WHAT THE AUTHORITATIVE NAMESERVER HOLDS"
printf '  %-26s %-18s %s\n' "record" "expected" "found"
faults=0; accepted=0
for k in $WANTED; do
  eval "base=\$BASE_$k"
  got=$(fingerprint "$AUTH" "$k")
  want=$([ -z "$base" ] && echo "(none)" || printf '%s' "${base%%,*}" | cut -c1-17)

  if [ "$got" = "$base" ]; then
    found=$([ -z "$base" ] && echo "absent" || echo "as captured")
  elif [ -n "$(accepted_value "$k")" ] && [ "$got" = "$(accepted_value "$k")" ]; then
    found="accepted variance"; accepted=$((accepted+1))
  elif [ -z "$got" ]; then
    found="MISSING"; faults=$((faults+1))
  elif [ -z "$base" ]; then
    found="present"
  else
    found="DIFFERS"; faults=$((faults+1))
  fi
  printf '  %-26s %-18s %s\n' "$(label_for "$k")" "$want" "$found"
done

if [ $old_up = yes ]; then
  echo
  echo "  and Route 53, for comparison:"
  for k in mx verify www; do
    got=$(fingerprint "$OLD_AWS" "$k"); eval "base=\$BASE_$k"
    printf '  %-26s %s\n' "$(label_for "$k")" "$([ "$got" = "$base" ] && echo "agrees with the capture" || echo "CHANGED since the capture")"
  done
fi

# ---- 2. propagation -----------------------------------------------------
echo
echo "WHAT PUBLIC RESOLVERS ARE HANDING OUT"
lagging=0
for r in $RESOLVERS; do
  n=$(dig +time=3 +tries=1 +short MX "$DOMAIN" "@$r" 2>/dev/null | grep -c .)
  w=$(dig +time=3 +tries=1 +short CNAME "www.$DOMAIN" "@$r" 2>/dev/null | head -1)
  printf '  %-18s %s MX, www -> %s\n' "$r" "$n" "${w:-nothing}"
  [ "$n" = 5 ] || lagging=$((lagging+1))
done

echo
if [ $faults -gt 0 ]; then
  echo "!! $faults record(s) are wrong at the nameserver itself. That is a real fault."
  echo "   MISSING or DIFFERS on mail is the one to fix before anything else."
  exit 1
fi

echo ">> The zone is right at the source."
[ $accepted -gt 0 ] && { echo; echo "   accepted variance, on the record:"; for k in $WANTED; do [ -n "$(accepted_value "$k")" ] && printf '   - %s: %s\n' "$(label_for "$k")" "$(accepted_why "$k")"; done; }

if [ $lagging -gt 0 ]; then
  echo
  echo "   $lagging of the public resolvers has not caught up. Give it an hour:"
  echo "   Namecheap's SOA sets negative caching to 3601 seconds, so a resolver"
  echo "   that asked during a gap will keep saying 'no such record' for that"
  echo "   long after the record exists. It is not a fault and there is nothing"
  echo "   to fix -- re-run this later rather than editing anything."
fi
