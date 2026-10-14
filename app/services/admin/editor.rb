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

      Look before you edit. Call get_page to see real ids rather than guessing.

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

    Result = Struct.new(:reply, :tool_calls, :error, keyword_init: true)

    def initialize(revision, client: Anthropic::Client.new)
      @revision = revision
      @client   = client
      @tools    = Tools.new(revision)
    end

    def call(user_text)
      @revision.messages.create!(role: "user", content: user_text)

      conversation = history
      performed    = []

      MAX_STEPS.times do
        response = @client.call(system: SYSTEM, messages: conversation,
                                tools: Tools.definitions)
        content = response["content"] || []
        conversation << { role: "assistant", content: content }

        uses = content.select { |c| c["type"] == "tool_use" }
        if uses.empty?
          text = content.select { |c| c["type"] == "text" }.map { |c| c["text"] }.join("\n").strip
          @revision.messages.create!(role: "assistant", content: text.presence || "(no reply)",
                                     tool_calls: performed)
          return Result.new(reply: text, tool_calls: performed)
        end

        results = uses.map do |use|
          outcome = run(use, performed)
          { type: "tool_result", tool_use_id: use["id"], content: outcome.to_json }
        end
        conversation << { role: "user", content: results }
      end

      message = "I made several changes but stopped after #{MAX_STEPS} steps. Have a look, then tell me what still needs doing."
      @revision.messages.create!(role: "assistant", content: message, tool_calls: performed)
      Result.new(reply: message, tool_calls: performed)
    rescue Anthropic::Client::Error, Tools::ToolError, ImageTools::ToolError => e
      @revision.messages.create!(role: "assistant", content: "Something went wrong: #{e.message}")
      Result.new(reply: nil, tool_calls: performed || [], error: e.message)
    end

    private

    def run(use, performed)
      result = @tools.call(use["name"], use["input"] || {})
      performed << { "name" => use["name"], "summary" => result[:summary] } if result.is_a?(Hash) && result[:summary]
      result
    rescue Tools::ToolError, ImageTools::ToolError => e
      # Hand the failure back to the model rather than aborting: it can usually
      # recover by looking the right id up.
      { ok: false, error: e.message }
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
