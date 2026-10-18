module Admin
  # What a turn actually cost, in money.
  #
  # Here because a parish has to decide whether to keep paying for this, and
  # "about twenty dollars" from a developer is not something a council can
  # check. The numbers come from the usage the API reports, stored on every
  # message, so this is a record rather than an estimate.
  #
  # Rates are per MILLION tokens, as published. Cached reads are a tenth of
  # fresh input, which is the whole reason caching was worth doing: see
  # Anthropic::Client.
  class Cost
    RATES = {
      "claude-opus-5"   => { input: 15.00, output: 75.00, cache_write: 18.75, cache_read: 1.50 },
      "claude-sonnet-5" => { input:  3.00, output: 15.00, cache_write:  3.75, cache_read: 0.30 },
      "claude-haiku-4-5-20251001" => { input: 1.00, output: 5.00, cache_write: 1.25, cache_read: 0.10 }
    }.freeze

    # A message with no model recorded is not an unknown: the model started
    # being stored at the same moment the admin moved to Opus, so anything
    # without one ran on Sonnet. Pricing those at Opus rates reported $101 for
    # a session that actually cost about $19.
    FALLBACK = RATES["claude-sonnet-5"]

    def self.of(usage)
      return 0.0 if usage.blank?

      u = usage.symbolize_keys
      rates = RATES.fetch(u[:model], FALLBACK)

      (u[:input].to_i       * rates[:input] +
       u[:output].to_i      * rates[:output] +
       u[:cache_write].to_i * rates[:cache_write] +
       u[:cache_read].to_i  * rates[:cache_read]) / 1_000_000.0
    end

    def self.of_revision(revision)
      revision.messages.filter_map(&:usage).sum { |u| of(u) }
    end

    # Pennies matter here: a single turn is often under a cent, and rounding it
    # to "$0.00" would make the meter useless for the thing it is for.
    def self.format(amount)
      return "$0.00" if amount.zero?
      return "<$0.01" if amount < 0.005

      "$#{'%.2f' % amount}"
    end

    # What it WOULD have cost without the cache, so the saving is a number
    # rather than a claim.
    def self.uncached(usage)
      return 0.0 if usage.blank?

      u = usage.symbolize_keys
      rates = RATES.fetch(u[:model], FALLBACK)
      fresh = u[:input].to_i + u[:cache_read].to_i + u[:cache_write].to_i

      (fresh * rates[:input] + u[:output].to_i * rates[:output]) / 1_000_000.0
    end
  end
end
