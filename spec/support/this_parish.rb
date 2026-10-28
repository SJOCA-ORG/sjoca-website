# What "this parish" looks like in a string.
#
# Shared by the spec that reads the source and the spec that reads rendered
# HTML, so the two cannot drift apart -- and so adding a term teaches both at
# once. SJTB is in here because it was not, and that is how a monogram in the
# default header template survived long enough to be seeded into the first
# organization anybody would have created.
module ThisParish
  PATTERN = /
    john\s+the\s+baptist | orthodox | vespers | divine\s+liturgy |
    rochester | goodman | sjoca | sjtb | fr\.?\s*david
  /xi
end
