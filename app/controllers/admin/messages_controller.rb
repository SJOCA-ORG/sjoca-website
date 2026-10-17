module Admin
  class MessagesController < BaseController
    def create
      revision = Revision.find(params[:revision_id])

      unless Anthropic::Client.configured?
        return redirect_to admin_revision_path(revision),
                           alert: "No Anthropic API key is configured."
      end

      text = params[:content].to_s.strip
      return redirect_to admin_revision_path(revision) if text.blank?

      # Out of the request. A turn can take a minute, and a frozen page with no
      # sign of life is the difference between usable and not.
      EditingTurnJob.perform_later(revision.id, text)
      redirect_to admin_revision_path(revision)
    end
  end
end
