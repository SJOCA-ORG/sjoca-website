module Admin
  # Runs one turn of the editing conversation: hand the model the history and
  # the tools, let it call them until it has nothing left to do, persist what
  # was said and what was changed.
  #
  # The conversation is rebuilt from the database each turn, which is what makes
  # a session survive a reload, a logout, or coming back tomorrow.
  class Editor
    MAX_STEPS = 30

    SYSTEM = <<~PROMPT.freeze
      You maintain the website of St John the Baptist Orthodox Church in Rochester,
      New York — a parish of the Orthodox Church in America.

      The site keeps STANDING PROMISES: things that must remain true after any
      change. If something you do breaks one, say so and ask what they want —
      the site put back, or the promise updated. Never decide that on your own,
      and never remove a promise without them agreeing to it. When a change
      establishes a new requirement, offer to promise it.

      You are talking to a parish volunteer, not a developer. Keep replies short and
      concrete: say what you changed, in their words, not in terms of ids or tables.
      Never mention blocks, sections, revisions or SQL unless they do first.

      You are working in a draft. Nothing you do is visible to the parish until a
      person previews it and publishes, so make the change rather than asking
      permission for ordinary things. Do ask when a request is genuinely ambiguous
      or would delete something substantial.

      How the site is built: a page holds horizontal bands (sections); each band
      holds columns; each column holds blocks. A block is one heading, paragraph,
      photo, list or button.

      Anything that lives somewhere else — the calendar, class recordings, the
      daily readings — comes in through add_data_source: the server fetches the
      address and hands the page the data as JSON, and YOUR JavaScript decides
      what to show and how. There is no built-in calendar and nothing that knows
      what "upcoming" ought to mean; that judgement is yours to write down, where
      the next person can read it. peek_data shows you the shape of a feed before
      you write anything against it.

      Say what you are doing as you go. A line before you look something up or
      make a change — "let me see what is on that page", "that photograph is the
      wrong one, finding a better" — appears on screen while you work, so the
      person is not watching a blank page for a minute. Keep it to a sentence,
      and in their language, not yours.

      Look before you edit, and look again after. get_page shows you real ids
      rather than guessing at them; view_page shows what actually rendered;
      check_page reads the markup for breakage. After changing a template or
      anything about how the site looks, call check_appearance — it opens the
      page in a real browser at phone and desktop width and SENDS YOU THE
      SCREENSHOTS, so you can see the result rather than infer it.

      CHECK YOUR WORK TWO WAYS, and do not confuse them.

      A picture tells you whether something LOOKS right. It will not tell you
      whether it IS right, and it invites you to see what you expected: asked to
      put a paragraph between two photographs, this loop once added it, looked at
      the screenshot, and reported it sat between them. It did not — it shared a
      position number with one of the photographs and rendered after both.

      So check the facts as well as the picture. get_page gives you the real
      order: column and position for every block. If something was asked to go
      BETWEEN two things, it must be numbered between them in the same column.
      Two things on one number means the order between them is undefined, and
      the layout is wrong however it happens to look.

      When placing a block, say which block it goes after or before rather than
      working out a number — add_block and move_block take after_block and
      before_block, and shift everything else to make room.

      Look at those pictures and judge them as a person would. The findings list
      only reports what is measurably broken; it cannot tell you that something
      is in the wrong place, badly spaced, or stranded at the bottom of a page
      when it belongs beside the text. That judgement is yours, and it is the
      main reason to call this tool. If a layout looks wrong to you, fix it and
      look again.

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

      BEFORE writing any CSS, READ THE STYLESHEET with get_styles. It is about
      17KB, which is nothing to read, and reading it is the only way to write
      CSS that looks like it belongs in this file rather than beside it.
      liquid_guide reports the conventions it actually follows — the naming, the
      breakpoints, the colour and font variables — measured from the file.

      Writing is the other way round. NEVER send the stylesheet back whole: a
      reply is capped and set_styles will be silently cut short. Use add_styles
      for new rules and edit_styles to change an existing one.

      When you need to adjust something you wrote earlier in this same
      conversation, EDIT THAT RULE. Do not append a second rule to correct the
      first. Two rules for one thing is how a stylesheet becomes unmaintainable,
      and it is the single most common way this goes wrong.

      PHOTOGRAPHS UPLOADED IN THE CONVERSATION. When someone attaches
      photographs they arrive in the library straight away under provisional
      names taken from their filenames (new-img-4821 and the like), and alt text
      is written for them automatically a moment later.

      Three things follow.

      LOOK AT THEM. describe_photo sends you the picture. Do that before you say
      anything about a photograph you have not seen.

      SAY "A PERSON". When you talk about someone in a photograph -- to the
      editor, or in alt text -- say "a person", "someone", "a parishioner", "a
      server". Do not say "a man" or "a woman", and do not guess at age, unless
      you are VERY sure. Clergy are the exception: a deacon, priest or bishop
      serving in vestments can be named by his office, because that is what is
      visible and what the picture is about. This is a small parish. The person
      in the picture is in the room, reads this website, and has a name everyone
      knows. Getting it wrong out loud is a small public unkindness and it costs
      you nothing to avoid: describe what they are DOING, not what you think
      they are.

      PROPOSE A REAL NAME. new-img-4821 is not a name a page should point at.
      Suggest one from what you can see — fr-david-2026, picnic-pavilion — and
      say what you are renaming it to, so it can be corrected.

      REPLACING A PHOTOGRAPH MEANS A NEW VERSION OF THE SAME NAME, not a new
      name. "Replace Fr David's photo with this" becomes a new version of
      leadership-fr-david, and the page goes on pointing at that name. That is
      what makes "can we get back the old picture of Father David?" possible,
      and the person asking will never say the word version: they will say
      replace, or put the old one back. photo_versions shows what exists,
      describe_photo shows you each one, repoint_photo chooses.

      If photographs are uploaded with nothing asked of them, say briefly what
      they are and ask whether anything should be done with them now, or whether
      they are for later. Either answer is fine; do not start rearranging pages
      because some pictures arrived.

      A PAGE CAN HAVE ITS OWN TEMPLATE. Most pages use the ordinary one. Pass
      layout: to add_page and the page is rendered by the TEMPLATE OF THAT NAME
      instead — so a page can be a printed sheet, a newsletter, an order of
      service, anything somebody describes. Write the template with
      add_template, make the page with layout: pointing at it. There is no list
      of allowed kinds and you do not need anybody to add one. dated_on says
      which day the page is FOR, which is what anything dated on it should be
      computed from.

      If somebody describes a thing this site has never had — a quarterly
      newsletter for friends abroad, say — BUILD IT THAT WAY. Do not force it
      into being a bulletin because a bulletin is what exists. Ask what it
      should look like, write a template, and use their word for it.

      THE WEEKLY BULLETIN is one such page, and the one this parish already
      has. Its difference is that it is paper: four sheets of 5.5 x 8.5, each
      section one sheet, and content that does not fit does not scroll — it
      prints onto a fifth sheet nobody wanted. check_appearance measures every
      sheet and says how much room is left or how far over it runs. Never say
      anything printed is finished without having checked that it fits. That
      applies to any page meant for paper, not only to a bulletin.

      add_bulletin is a SHORTCUT for the common case, not a special kind of
      thing: it makes the page, points it at the bulletin template, and copies
      the previous week so the only thing anybody composes is what is new. Your
      job after it is to recompute what is dated — the day's commemoration, the
      readings, that week's services — and to leave alone what is not: the
      masthead, the address, the giving line, the standing reminders. For
      anything that is not a bulletin, add_template and add_page do the same
      job in two steps.

      YOU CANNOT HAND ANYBODY A FILE. The PDF for the printer and the HTML for
      the mailing list are downloaded by the person, from the Bulletins page in
      this admin, which lists every page with a template of its own, or from the
      two buttons beside the preview. Both work for ANY page, not only a
      bulletin. When you finish something printed, say that it fits and that
      both are waiting there. Do not say
      you have sent, printed or emailed anything: you have not, and cannot.

      Every block template's outermost element carries class="b ..." and
      data-block="{{ block.id }}". The first is what the stylesheet hangs on;
      the second is how somebody clicking that block in the preview gets to
      edit it. Leave both on anything you write or change.

      House style, worth preserving:
      - British-influenced parish usage, sentence case for headings.
      - Clergy are named in full with their titles.
      - Service times belong together and must stay accurate; they are the single
        most important thing on the site.
      - Photographs are referenced by name; use list_photos to see what exists.
        You cannot upload new ones yet.

      ANSWER WHAT WAS ASKED, FIRST AND IN THEIR WORDS. Asked to correct two
      names, open with the two names corrected. The checks you ran to be sure
      are yours; a reply that opens "Both checks hold — nine bands, each a
      photograph alone in the left column at position 0" has buried the answer
      under an audit nobody asked for.

      IF YOU FIND SOMETHING ELSE WRONG, SAY SO — DO NOT GO AND FIX IT. You will
      notice things while working: a blank photograph, a heading in the wrong
      case, a page nobody has updated. Finish what was asked, then mention what
      you saw and offer. Spending twenty steps on a fault nobody reported, in a
      turn that was meant to change two words, is not thoroughness.

      The exception is something that BLOCKS the request. If the thing you were
      asked to change cannot be seen because of a fault, fixing that fault is
      part of the job — say that is what you did and why.

      BE ESPECIALLY CAREFUL WITH A CHANGE THAT AFFECTS THE WHOLE SITE. Editing
      a template or the stylesheet changes every page at once. If that is what
      the request needs, do it and say plainly that it affects everything. If
      it is something you noticed in passing, describe it and ask first — the
      person asked you to change two names, not to alter how every photograph
      on the site is loaded.

      If something cannot be done with the tools you have, say so plainly and
      explain what would be needed. Do not pretend it worked.
    PROMPT

    # `unfinished` is how the job knows to pick this up in another turn rather
    # than leaving a person to read "I ran out of steps" and type "carry on".
    Result = Struct.new(:reply, :tool_calls, :error, :problems, :unfinished, keyword_init: true)

    # The message this turn is filling in. The job needs it to know which
    # message is its own when cleaning up -- sweeping every "working" message on
    # the revision also swept the placeholder belonging to a QUEUED request.
    attr_reader :working

    def initialize(revision, client: Anthropic::Client.new)
      @revision = revision
      @client   = client
      @tools    = Tools.new(revision)
    end

    def call(user_text, placeholder_id: nil, round: 1)
      # The caller usually creates both rows before enqueueing, so the page has
      # something to poll the instant it loads. Create them here only when
      # something calls this directly, such as a test.
      @round = round

      if placeholder_id
        @working = @revision.messages.find(placeholder_id)
      else
        # A continuation is the SAME request being carried on, so it does not
        # repeat what the person said -- that is already in the conversation,
        # and echoing it would read as though they had asked twice.
        @revision.messages.create!(role: "user", content: user_text) if round == 1
        @working = @revision.messages.create!(role: "assistant", state: "working",
                                              content: "", progress: [])
      end

      conversation = history

      # The API requires the conversation to end with something the person
      # said. Every ordinary path satisfies that -- the controller writes the
      # user's message before enqueueing, and a continuation appends its own
      # instruction below -- but a history that ends on a reply would lose the
      # whole turn to "does not support assistant message prefill", which names
      # the symptom and not the cause.
      if conversation.last && conversation.last[:role] != "user"
        conversation << { role: "user", content: [{ type: "text", text: user_text.presence ||
          "Carry on." }] }
      end

      if round > 1
        conversation << { role: "user", content: [{ type: "text", text:
          "Carry on with the request above from where the last round stopped. What was " \
          "already done is written in your own previous message — do not repeat it. Look " \
          "at the current state before assuming anything is still as you left it, finish " \
          "what remains, and when it is finished say what changed overall rather than " \
          "narrating the steps." }] }
      end
      performed     = []
      failures      = Hash.new(0)
      verified_once   = false
      promises_raised = false
      looked_once     = false
      truncated       = 0
      assumed_once    = false
      spent           = { input: 0, output: 0, cache_read: 0, cache_write: 0, calls: 0,
                          model: Anthropic::Client.model }

      MAX_STEPS.times do
        # Asked to stop. Between steps, not mid-step: a turn killed in the
        # middle of a tool call would leave the draft half-changed with nothing
        # written down about what had happened to it.
        if stop_requested?
          return stopped(performed, spent)
        end

        response = @client.call(system: system_prompt, messages: conversation,
                                tools: Tools.definitions)
        content = response["content"] || []
        conversation << { role: "assistant", content: content }

        # The model narrates as it works -- "let me look at the home page" --
        # in the same response as the tool call. That was being thrown away,
        # which is why the page showed mechanical step names and nothing of what
        # it was thinking.
        said = content.select { |c| c["type"] == "text" }
                      .map { |c| c["text"].to_s.strip }.reject(&:blank?)
        said.each { |line| performed << { "say" => line } }

        # Cached reads are counted separately so the saving is visible rather
        # than asserted. cache_read is charged at a tenth of input.
        usage = response["usage"] || {}
        spent[:input]      += usage["input_tokens"].to_i
        spent[:output]     += usage["output_tokens"].to_i
        spent[:cache_read] += usage["cache_read_input_tokens"].to_i
        spent[:cache_write] += usage["cache_creation_input_tokens"].to_i
        spent[:calls]      += 1
        @working&.update_columns(progress: performed, usage: spent)

        # A reply that hits max_tokens stops MID-SENTENCE. What comes back can
        # have no complete tool call and no text in it, and the loop then fell
        # straight through to "(no reply)" -- a turn that silently did nothing
        # and explained nothing. The code already knew this failure existed
        # (see the repeated-failure message below) and only handled it there.
        if response["stop_reason"] == "max_tokens"
          truncated += 1
          if truncated <= 2
            conversation << { role: "user", content: [{ type: "text", text:
              "Your last reply was cut off: it hit the length limit. Nothing in it was " \
              "acted on. Do LESS in one go — take the next single step, keep what you " \
              "write short, and do not list or restate things you have already seen. " \
              "If the request is large, do the first part and say what remains." }] }
            next
          end

          # Three in a row means it cannot say what it wants to say in the space
          # available. Stop, and say so in a way that can be acted on.
          message = "I could not finish this one. My replies kept running over the " \
                    "length limit, which usually means the request is too big to do in " \
                    "one go. Try splitting it — one page, or one person, at a time."
          @working.update!(state: "done", content: message, tool_calls: performed,
                           usage: spent, touched: (@tools.edited.presence || @tools.sampled).to_a)
          return Result.new(reply: message, tool_calls: performed)
        end

        uses = content.select { |c| c["type"] == "tool_use" }
        if uses.empty?
          text = said.join("\n").strip

          # A reply with NO tool calls behind it at all.
          #
          # Asked to put a title across a hero, it answered "Done -- the hero
          # now has that title written across it" after one API call, 46 tokens,
          # and nothing else. The title HAD been set a turn earlier, so it
          # believed the job was done and answered from memory. Something else
          # on the page was overriding it, which it would have seen had it
          # looked.
          #
          # Every other safeguard here is gated on having done something, so a
          # turn that does nothing is the one turn that gets no checking at all.
          # Answering a question from what is already on screen is fine;
          # claiming a change without looking is not.
          # `performed` also holds what the model SAID as it worked, so checking
          # it for emptiness would have let narration count as evidence of
          # having looked. Only an actual tool call counts.
          if performed.none? { |p| p["name"] } && !assumed_once
            assumed_once = true
            conversation << { role: "user", content: [{ type: "text", text:
              "Before you reply: you have not looked at anything this turn. If you are " \
              "about to say something is done, CHECK IT FIRST -- get_page for what is " \
              "there, view_page for what actually renders. Earlier conversation is not " \
              "evidence: a change can be made and then overridden by something else on " \
              "the page. If you are only answering a question, and the answer does not " \
              "depend on the current state of the site, reply as you were going to." }] }
            next
          end

          # Before telling anyone it is done, look at what it actually produced.
          # Relying on the prompt to remember this does not work -- the tools
          # existed for a day and nothing ever called them.
          broken = broken_promises
          if broken.any? && !promises_raised
            promises_raised = true
            conversation << { role: "user", content: [{ type: "text", text:
              "Before you reply: your changes have broken #{broken.size} of the site's " \
              "standing promises.\n\n" +
              broken.map { |b| "- \"#{b[:summary]}\" on /#{b[:page]}: #{b[:why]}" }.join("\n") +
              "\n\nDo NOT quietly fix this and do NOT quietly change the promise. Tell the " \
              "person what happened, in their words, and ASK which they want: the site put " \
              "back as it was, or the promise updated to match what they have asked for. " \
              "Use list_promises to see what each one was for." }] }
            next
          end

          # Before the mechanical checks: let it see the thing it just made.
          shot = looked_once ? nil : look_at_it(performed)
          if shot.is_a?(Hash) && shot[:screenshots].present?
            looked_once = true
            blocks = Tools.screenshot_blocks(shot[:screenshots])
            if blocks.any?
              # The picture AND the structure. Checking by eye alone, it
              # reported that a new paragraph sat between two photographs when
              # the paragraph and one photograph shared a position and it
              # actually rendered after both. A screenshot invites you to
              # confirm what you expected; an ordered list does not.
              layout = @tools.structure_of(shot[:slug])

              conversation << { role: "user", content: [{ type: "text", text:
                "Before you reply, check your work TWO ways.\n\n" \
                "First, the order of what is actually on the page — this is the fact, not " \
                "an impression:\n\n#{layout}\n\n" \
                "Read that against what was asked for. If something was meant to go between " \
                "two things, it must be numbered between them in the same column. If two " \
                "entries share a number, the order between them is undefined and the layout " \
                "is wrong however it happens to look.\n\n" \
                "Second, the page as it now looks at phone and desktop width. Judge it as " \
                "the person asking would: anything in the wrong place, badly spaced, or " \
                "stranded where it does not belong?\n\n" \
                "Fix what is wrong. If both check out, say what you changed and stop.\n\n" \
                "THIS CHECK IS FOR YOU, NOT FOR THEM. Do not report it. Asked to correct two " \
                "names, they want to read that the two names are corrected — not an audit of " \
                "which band sits at which number. Answer the request that was made, in their " \
                "words, and leave the verification out of it." }] + blocks }
              next
            end
          end

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
          if broken.any?
            text = "#{text}\n\nStanding promises still broken: " \
                   "#{broken.map { |b| b[:summary] }.join('; ')}."
          end
          # Never "(no reply)". If it genuinely said nothing, say what it DID,
          # because a blank message reads as the system being broken.
          if text.blank?
            did = performed.reject { |p| p["failed"] || p["read"] || p["say"] }
                           .filter_map { |p| p["summary"] }
            text = did.any? ? "I made these changes: #{did.join('; ')}." : nil
            text ||= "I looked into this but did not end up changing anything, and did " \
                     "not say why — which is a fault at my end. Ask me again and I will " \
                     "explain what I found."
          end

          Rails.logger.info(
            "editing turn: revision #{@revision.id} · #{spent[:calls]} calls · " \
            "#{spent[:input]} in, #{spent[:output]} out, #{spent[:cache_read]} cached · " \
            "#{Cost.format(Cost.of(spent))} (uncached would be #{Cost.format(Cost.uncached(spent))}) · " \
            "#{spent[:model]}"
          )

          @working.update!(state: "done", content: text,
                           tool_calls: performed, usage: spent,
                           # The pages a person would want to look at: the ones
                           # that were changed, not every page a stylesheet
                           # edit could in principle have affected.
                           touched: (@tools.edited.presence || @tools.sampled).to_a)
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

          # A tool result is normally JSON text. check_appearance also hands back
          # screenshot paths, and those become real images here -- the only way
          # the model can judge where something sits on a page rather than
          # trusting a list of measurements.
          shots = outcome.is_a?(Hash) ? Tools.screenshot_blocks(outcome[:screenshots]) : []
          content = [{ type: "text", text: outcome.to_json }] + shots

          { type: "tool_result", tool_use_id: use["id"], content: content }
        end
        conversation << { role: "user", content: results }
      end

      # Out of steps for THIS round. Three requests in a row ended here -- each
      # one a photograph to rotate, crop and place -- and every time the person
      # read "I ran out of steps" and typed some version of "carry on". That is
      # a question with one answer, so stop asking it: write down what was done
      # and pick it up in another turn.
      failed = performed.select { |p| p["failed"] }
      done   = performed.reject { |p| p["failed"] || p["read"] || p["say"] }
      summary = done.map { |p| p["summary"] }.compact_blank.join("; ")

      more = @round < EditingTurnJob::MAX_ROUNDS
      message = +""
      message << "Still going. So far: #{summary}." if done.any?
      message << " Nothing yet." if done.none?
      message << " What kept failing: #{failed.map { |p| p['summary'] }.compact_blank.uniq.first(2).join('; ')}." if failed.any?
      message << (more ? " Carrying on." : " That is as far as I can take this in one go — " \
                                           "have a look at what is there and tell me what still needs doing.")

      @working.update!(state: "done", content: message.strip, tool_calls: performed,
                       usage: spent, touched: (@tools.edited.presence || @tools.sampled).to_a)
      Result.new(reply: message.strip, tool_calls: performed, unfinished: more)
    rescue Anthropic::Client::Error, Tools::ToolError, ImageTools::ToolError => e
      @working&.update!(state: "done", content: "Something went wrong: #{e.message}")
      Result.new(reply: nil, tool_calls: performed || [], error: e.message)
    end

    private

    # Checked between steps. The state is set by the controller, so this is a
    # read of what somebody just clicked.
    def stop_requested? = @working&.reload&.state == "stopping"

    def stopped(performed, spent)
      done = performed.reject { |p| p["failed"] || p["read"] || p["say"] }
                      .filter_map { |p| p["summary"] }
      text = +"Stopped."
      text << (done.any? ? " I had already done: #{done.join('; ')}. Those changes are still " \
                           "there — tell me if you want them undone." : " Nothing was changed.")

      @working.update!(state: "done", content: text, tool_calls: performed, usage: spent,
                       touched: (@tools.edited.presence || @tools.sampled).to_a)
      Result.new(reply: text, tool_calls: performed)
    end

    # The house CSS conventions belong in the SYSTEM PROMPT, not in liquid_guide
    # where they started. Putting them there assumed it would call liquid_guide
    # before writing CSS; the instruction to call liquid_guide is about writing
    # LIQUID, so a pure styling request skipped it and the conventions went
    # unread. It then wrote a max-width breakpoint into a mobile-first file,
    # which is exactly what they were written to prevent.
    #
    # Measured from this revision's stylesheet every turn, so they cannot drift
    # from the file they describe.
    def system_prompt
      conventions = CssConventions.call(@revision)
      return SYSTEM if conventions[:note].present?

      <<~PROMPT
        #{SYSTEM}

        HOW THIS SITE'S CSS IS WRITTEN — read this before writing any.
        Measured from the stylesheet itself, so it is what the file actually does.

        #{conventions.map { |k, v| "- #{k.to_s.tr('_', ' ').upcase}: #{v}" }.join("\n\n")}

        Match all of it. CSS that works but does not look like the rest of the
        file is how a stylesheet becomes unmaintainable, and the parish has no
        developer to tidy it afterwards.
      PROMPT
    end

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

    # Show it the page before it says it is finished.
    #
    # It has had eyes since this morning and, over a four-request session that
    # changed two templates, 2KB of CSS and 7KB of JavaScript, it called
    # check_appearance exactly ZERO times. It reached for view_page and
    # check_page instead -- both of which read markup, neither of which can see
    # that something is in the wrong place.
    #
    # Same lesson as `verify` above, which carries the same comment: a tool
    # nobody calls is not a safeguard. So this is not optional either. Only for
    # changes that could alter how a page LOOKS, since it costs a browser launch
    # and about 2,460 tokens a page.
    LOOKS_CHANGED = %w[add_styles edit_styles set_styles add_template set_template
                       add_script edit_script set_scripts add_block update_block
                       move_block delete_block add_section update_section
                       move_section delete_section].freeze

    # Returns the check_appearance result, or NIL when there is nothing to look
    # at. Not [] -- this returned an empty ARRAY from its guards, copied from
    # `verify` just above, which returns a list of problems. An empty array is
    # truthy in Ruby, so the caller's `if (shot = look_at_it(...))` passed and
    # then asked an Array for [:screenshots]. Every turn that changed something
    # the guards declined to photograph died with "no implicit conversion of
    # Symbol into Integer", which names neither the cause nor the place.
    def look_at_it(performed)
      names = performed.filter_map { |p| p["name"] unless p["failed"] }
      return nil if (names & LOOKS_CHANGED).empty?
      return nil if @tools.touched.empty?

      # One page, and it must be a page the change LANDED on. Taking
      # touched.first photographed whichever page the global sample happened to
      # list first, so a change to the home page was checked by looking at
      # /about-us/our-story.
      slug = (@tools.edited.presence || @tools.sampled).to_a.first
      @tools.call("check_appearance", { "slug" => slug })
    rescue StandardError => e
      Rails.logger.warn("automatic appearance check failed: #{e.message}")
      nil
    end

    # A broken promise is NOT a problem for the AI to fix quietly. It is a
    # question for the person editing, asked while they are still here.
    def broken_promises
      return [] if Demo.on? || @tools.touched.empty? || @revision.promises.empty?

      # Array(), because a paused check returns no :broken key at all and a bare
      # nil here would blow up the turn rather than the check.
      Array(@tools.call("check_promises", { "slug" => nil })[:broken])
    rescue StandardError => e
      Rails.logger.warn("could not check promises: #{e.message}")
      []
    end

    # Every call is recorded, successes AND failures. Twelve steps once produced a
    # single line in the transcript because only successes with a summary were
    # kept -- which hid the fact that eleven attempts had failed identically.
    def run(use, performed)
      result = @tools.call(use["name"], use["input"] || {})
      note = nil
      performed << if result.is_a?(Hash) && result[:summary]
                     { "name" => use["name"], "summary" => result[:summary] }
                   else
                     { "name" => use["name"], "summary" => "looked at #{use['name'].tr('_', ' ')}", "read" => true }
                   end
      @working&.update_columns(progress: performed)
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
    # The conversation, with any photographs attached to a message named
    # alongside what was said. Without this, "replace Fr David's photo with the
    # one I am about to upload" reaches the model as a sentence about a
    # photograph it has no way to identify.
    def history
      # Not the placeholder this turn is about to fill in. It is an assistant
      # message with no content yet: nothing for the model to read, and the API
      # refuses a cache breakpoint on an empty text block, which is how it
      # surfaced -- "cache_control cannot be set for empty text blocks".
      #
      # Any other empty message is the remains of a turn that was interrupted
      # before it could say anything, and is equally not worth sending.
      @revision.messages.order(:created_at).reject { |m| m.content.to_s.strip.empty? }.map do |m|
        text = m.content.to_s
        attached = Array(m.attachments)
        if attached.any?
          named = attached.map { |a|
            "#{a['photo']} (version #{a['version']}, from #{a['filename']})"
          }
          text = [text, "", "Attached to this message, now in the photo library: " \
                           "#{named.join('; ')}. These names are provisional — they " \
                           "came from the filenames."].join("\n")
        end
        { role: m.role, content: text }
      end
    end
  end
end
