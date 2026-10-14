module Admin
  class RevisionsController < BaseController
    before_action :load_revision, only: %i[show publish preview destroy]

    def index
      @live   = Revision.live
      @drafts = Revision.drafts
      @history = Revision.where(state: "superseded").order(published_at: :desc).limit(10)
    end

    # The chat.
    def show
      @messages = @revision.messages
    end

    def create
      revision = Revision.open_sandbox(created_by: "Dn Mitch")
      redirect_to admin_revision_path(revision)
    end

    def publish
      @revision.publish!
      session.delete(:preview_revision_id)
      redirect_to admin_revisions_path, notice: "Published. The site is live on this revision."
    end

    # Browse the real site, rendered from this revision.
    def preview
      session[:preview_revision_id] = @revision.id
      redirect_to root_path
    end

    def exit_preview
      session.delete(:preview_revision_id)
      redirect_to admin_revisions_path
    end

    def destroy
      @revision.destroy!
      session.delete(:preview_revision_id)
      redirect_to admin_revisions_path, notice: "Draft discarded."
    end

    private

    def load_revision = @revision = Revision.find(params[:id])
  end
end
