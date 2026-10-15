module Admin
  # Runs one turn of the editing conversation: hand the model the history and
  # the tools, let it call them until it has nothing left to do, persist what
  # was said and what was changed.
  #
  # The conversation is rebuilt from the database each turn, which is what makes
  # a session survive a reload, a logout, or coming back tomorrow.
  class Editor
    MAX_STEPS = 12

    SYSTEM = <<~PROMPT.freeze
      You maintain the website of St John the Baptist Orthodox Church in Rochester,
      New York — a parish of the Orthodox Church in America.

      You are talking to a parish volunteer, not a developer. Keep replies short and
      concrete: say what you changed, in their words, not in terms of ids or tables.
      Never mention blocks, sections, revisions or SQL unless they do first.

      You are working in a draft. Nothing you do is visible to the parish until a
      person previews it and publishes, so make the change rather than asking
      permission for ordinary things. Do ask when a request is genuinely ambiguous
      or would delete something substantial.

      How the site is built: a page holds horizontal bands (sections); each band
      holds columns; each column holds blocks. A block is one heading, paragraph,
      photo, list, button or widget. Widgets — calendar, upcoming, classes,
      lectionary — render live data and take no content of their own.

      Look before you edit, and look again after. get_page shows you real ids
      rather than guessing at them; view_page shows what actually rendered;
      check_page reads the markup for breakage. After changing a template or
      anything about how the site looks, call check_appearance — it opens the
      page in a real browser at phone and desktop width, which is the only way
      to see that something runs off the side or overlaps.

      Your changed pages are rendered and checked automatically before your reply
      is shown, so a mistake will come back to you. Checking yourself first is
      quicker than being told.

      Templates are Liquid, stored as rows. BEFORE writing or changing any Liquid,
      call liquid_guide — it lists every object and property a template can reach,
      and the rules of this dialect, generated from the code so it cannot be stale.
      Guessing at Liquid here wastes a turn: an empty string is truthy, {% render %}
      does not inherit variables, and nothing is escaped automatically.

      The person you are talking to knows nothing about blocks, templates or CSS.
      They describe how they want something to look; choosing the mechanism is
      your job, and the cheapest one that works is the right one. liquid_guide
      sets out how to choose — read it before styling anything, and do not invent
      a new block kind when a class and one CSS rule would do.

      The stylesheet is about 26KB — far too large to send back in one reply, so
      do NOT reach for get_styles and set_styles. Use add_styles to append new
      rules, find_styles to see what already exists, and edit_styles to change
      one part. These send only what changes.

      House style, worth preserving:
      - British-influenced parish usage, sentence case for headings.
      - Clergy are named in full with their titles.
      - Service times belong together and must stay accurate; they are the single
        most important thing on the site.
      - Photographs are referenced by name; use list_photos to see what exists.
        You cannot upload new ones yet.

      If something cannot be done with the tools you have, say so plainly and
      explain what would be needed. Do not pretend it worked.
    PROMPT

    Result = Struct.new(:reply, :tool_calls, :error, :problems, keyword_init: true)

    def initialize(revision, client: Anthropic::Client.new)
      @revision = revision
      @client   = client
      @tools    = Tools.new(revision)
    end

    def call(user_text)
      @revision.messages.create!(role: "user", content: user_text)

      conversation  = history
      performed     = []
      failures      = Hash.new(0)
      verified_once = false

      MAX_STEPS.times do
        response = @client.call(system: SYSTEM, messages: conversation,
                                tools: Tools.definitions)
        content = response["content"] || []
        conversation << { role: "assistant", content: content }

        uses = content.select { |c| c["type"] == "tool_use" }
        if uses.empty?
          text = content.select { |c| c["type"] == "text" }.map { |c| c["text"] }.join("\n").strip

          # Before telling anyone it is done, look at what it actually produced.
          # Relying on the prompt to remember this does not work -- the tools
          # existed for a day and nothing ever called them.
          problems = verify(performed)
          if problems.any? && !verified_once
            verified_once = true
            conversation << { role: "user", content: [{ type: "text", text:
              "Before you reply: I rendered the pages you changed and found these " \
              "problems. Fix them, or explain why they are not problems.\n\n" +
              problems.map { |p| "- #{p}" }.join("\n") }] }
            next
          end

          text = "#{text}\n\nStill not right: #{problems.join('; ')}" if problems.any?
          @revision.messages.create!(role: "assistant", content: text.presence || "(no reply)",
                                     tool_calls: performed)
          return Result.new(reply: text, tool_calls: performed, problems: problems)
        end

        results = uses.map do |use|
          outcome = run(use, performed)

          # It self-corrects well when an error says something actionable. It
          # cannot when the real cause is invisible to it -- a reply truncated at
          # max_tokens looks like an unexplained failure, and it will try the
          # same thing until the step budget runs out. Say so after the second
          # identical failure rather than letting it burn ten more.
          if outcome.is_a?(Hash) && outcome[:ok] == false
            failures[use["name"]] += 1
            if failures[use["name"]] >= 2
              outcome = outcome.merge(
                stop: "#{use['name']} has now failed #{failures[use['name']]} times. Do NOT try it " \
                      "again — something about this approach cannot work. If you were sending a " \
                      "large amount of text, your reply is being cut short: use add_styles or " \
                      "edit_styles, which send only what changes. Otherwise try a different tool, " \
                      "or tell the person plainly what you cannot do and why."
              )
            end
          end

          { type: "tool_result", tool_use_id: use["id"], content: outcome.to_json }
        end
        conversation << { role: "user", content: results }
      end

      # Say what actually happened rather than "I stopped after 12 steps", which
      # tells the person nothing about whether their change was made.
      failed = performed.select { |p| p["failed"] }
      done   = performed.reject { |p| p["failed"] || p["read"] }
      message = +"I ran out of steps before finishing."
      message << " I did manage: #{done.map { |p| p['summary'] }.join('; ')}." if done.any?
      message << " What kept failing: #{failed.map { |p| p['summary'] }.uniq.first(2).join('; ')}." if failed.any?
      message << " Have a look at what is there, and tell me what still needs doing."
      @revision.messages.create!(role: "assistant", content: message, tool_calls: performed)
      Result.new(reply: message, tool_calls: performed)
    rescue Anthropic::Client::Error, Tools::ToolError, ImageTools::ToolError => e
      @revision.messages.create!(role: "assistant", content: "Something went wrong: #{e.message}")
      Result.new(reply: nil, tool_calls: performed || [], error: e.message)
    end

    private

    # Render what was changed and look for breakage. This runs whether or not
    # the model thought to check, because a tool nobody calls is not a safeguard.
    def verify(performed)
      return [] unless performed.any? { |p| !p["read"] && !p["failed"] }
      return [] if @tools.touched.empty?

      @tools.touched.to_a.first(4).flat_map do |slug|
        result = @tools.call("check_page", { "slug" => slug })
        Array(result[:problems]).map { |p| "/#{slug}: #{p}" }
      rescue StandardError => e
        ["/#{slug}: could not be checked (#{e.class})"]
      end
    end

    # Every call is recorded, successes AND failures. Twelve steps once produced a
    # single line in the transcript because only successes with a summary were
    # kept -- which hid the fact that eleven attempts had failed identically.
    def run(use, performed)
      result = @tools.call(use["name"], use["input"] || {})
      performed << if result.is_a?(Hash) && result[:summary]
                     { "name" => use["name"], "summary" => result[:summary] }
                   else
                     { "name" => use["name"], "summary" => "looked at #{use['name'].tr('_', ' ')}", "read" => true }
                   end
      result
    rescue Tools::ToolError, ImageTools::ToolError => e
      # Hand the failure back to the model rather than aborting: it can usually
      # recover by looking the right id up.
      performed << { "name" => use["name"], "summary" => "FAILED: #{e.message}", "failed" => true }
      { ok: false, error: e.message }
    rescue StandardError => e
      # Anything else is a bug in a tool. The conversation should survive it --
      # and it must be in the log, not swallowed.
      Rails.logger.error("tool #{use['name']} raised #{e.class}: #{e.message}")
      performed << { "name" => use["name"], "summary" => "FAILED unexpectedly: #{e.class}", "failed" => true }
      { ok: false, error: "#{use['name']} failed unexpectedly (#{e.class}). Try another way." }
    end

    # The model sees only what a person said and what it replied -- not the
    # intermediate tool traffic, which would grow without bound.
    def history
      @revision.messages.order(:created_at).map do |m|
        { role: m.role, content: m.content.to_s }
      end
    end
  end
end
