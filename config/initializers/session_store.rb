# The session cookie, and why its name begins with __Host-.
#
# Tenants live on sibling subdomains of one domain: clubA.example.com,
# clubB.example.com. Same-origin policy keeps their pages, storage and scripts
# apart -- but COOKIES ARE NOT ORIGIN-SCOPED. Any page may set a cookie with
# Domain=.example.com, and every sibling then receives it.
#
# That is an ordinary footnote in most applications and a real risk in this one,
# because this app's whole premise is that an AI writes JavaScript into a
# tenant's pages. Script running on one organization's site could set a cookie
# named like the session cookie, scoped to the parent domain, and have the
# browser send it to another organization's site -- "cookie tossing". It does
# not read the other session; it replaces it, which is enough to confuse an
# editor into acting in the wrong place, or to log them out repeatedly with no
# explanation.
#
# The __Host- prefix is the defence, and it is enforced by the browser rather
# than by us: a cookie whose name begins __Host- is rejected outright unless it
# is Secure, has Path=/, and has NO Domain attribute. A tossed cookie must carry
# a Domain to reach a sibling, so it can never bear this name.
#
# Authentication#current_user checks may_act_in? on every request, so a session
# from another organization is refused anyway. This stops it being sent at all,
# which is the difference between a defence and a backstop.
#
# In development and test the cookie keeps an ordinary name: __Host- requires
# Secure, and a Secure cookie over plain http is accepted by browsers only
# because localhost is treated as trustworthy -- a rule that does not hold for
# every tool a contributor might use. The prefix matters where the siblings
# are, which is production.
Rails.application.config.session_store :cookie_store,
  key: Rails.application.config.force_ssl ? "__Host-session" : "_sjoca_session",
  secure: Rails.application.config.force_ssl,
  httponly: true,
  path: "/",
  same_site: :lax
