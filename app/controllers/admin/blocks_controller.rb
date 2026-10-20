module Admin
  # Editing one block, by clicking it on the page.
  #
  # Mitch had to reword a long paragraph and did it by copying the text into a
  # document, editing it there, and pasting it back. The text was on screen the
  # whole time. This is the shortest path from "that paragraph is wrong" to
  # "that paragraph is right", and it deliberately does NOT go through the AI:
  # a person who knows the words they want should not have to describe them to
  # somebody else first.
  class BlocksController < BaseController
    before_action :load_block, except: %i[rewrite]
    before_action :load_revision, only: %i[rewrite]

    def show
      render json: {
        id: @block.id,
        kind: @block.kind,
        content: @block.content.to_s,
        editable: editable?,
        page: @block.section.page.slug,
        photo: @block.asset_name,
        version: @block.asset_version
      }
    end

    def update
      unless editable?
        return render json: { error: "A #{@block.kind} block has no text to edit." },
                      status: :unprocessable_entity
      end

      @block.update!(content: params[:content].to_s)
      render json: { ok: true, content: @block.content }
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.record.errors.full_messages.to_sentence },
             status: :unprocessable_entity
    end

    # Several blocks at once, as one piece of prose.
    #
    # Mitch's correction, and a better shape than clicking one block at a time:
    # a thought a person wants to reword is rarely one paragraph. You select
    # across whatever it covers, edit it as prose, and hand it back.
    #
    # What comes back is a different number of paragraphs than went out, as
    # often as not -- which is why this does NOT simply write the text into the
    # blocks it came from. Deciding where the paragraphs fall, and which line
    # is a heading, is judgement, and judgement is what the conversation is
    # for.
    def rewrite
      ids = Array(params[:block_ids]).map(&:to_i)
      blocks = @revision.blocks.where(id: ids).to_a
      return render json: { error: "nothing selected" }, status: :unprocessable_entity if blocks.empty?

      text = params[:content].to_s
      page = blocks.first.section.page

      # One block of prose in, one block out: no judgement needed, so no turn.
      if blocks.one? && blocks.first.kind.in?(TEXTUAL)
        blocks.first.update!(content: text)
        return render json: { ok: true, handled: "directly" }
      end

      render json: { ok: true, handled: "conversation", message: hand_to_conversation(blocks, page, text) }
    end

    private

    # Written as the editor speaking, because that is what happened: they
    # rewrote it. The old text goes along so the model can see what changed
    # rather than guessing.
    def hand_to_conversation(blocks, page, text)
      was = blocks.map { |b| "#{b.kind}: #{b.content.to_s}" }.join("\n")

      said = <<~ASK
        I have rewritten a section of /#{page.slug} myself. Replace what is there now with
        this, breaking it into paragraphs and headings as the sense requires — it need not
        be the same number of blocks as before.

        What is there now (#{blocks.size} blocks, ids #{blocks.map(&:id).join(', ')}):
        #{was}

        What it should say:
        #{text}
      ASK

      @revision.messages.create!(role: "user", content: said)
      placeholder = @revision.messages.create!(role: "assistant", state: "working",
                                               content: "", progress: [])
      EditingTurnJob.perform_later(@revision.id, said, placeholder.id)
      "handed to the conversation"
    end

    def load_revision = @revision = Revision.find(params[:revision_id])

    def load_block
      load_revision
      @block = @revision.blocks.find(params[:id])
    end

    # Kinds whose content is words. An image or an embed has content that is
    # not prose, and a textarea over it would be a trap.
    TEXTUAL = %w[heading subheading text quote list button].freeze

    def editable? = @block.kind.in?(TEXTUAL)
  end
end
