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
    before_action :load_block

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

    private

    def load_block
      @revision = Revision.find(params[:revision_id])
      @block = @revision.blocks.find(params[:id])
    end

    # Kinds whose content is words. An image or an embed has content that is
    # not prose, and a textarea over it would be a trap.
    TEXTUAL = %w[heading subheading text quote list button].freeze

    def editable? = @block.kind.in?(TEXTUAL)
  end
end
