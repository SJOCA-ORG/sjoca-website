module Admin
  class MessagesController < BaseController
    def create
      revision = Revision.find(params[:revision_id])

      unless Anthropic::Client.configured?
        return redirect_to admin_revision_path(revision),
                           alert: "No Anthropic API key is configured. Set ANTHROPIC_API_KEY."
      end

      text = params[:content].to_s.strip
      return redirect_to admin_revision_path(revision) if text.blank?

      Editor.new(revision).call(text)
      redirect_to admin_revision_path(revision)
    end
  end
end
