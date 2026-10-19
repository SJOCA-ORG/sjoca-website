module Admin
  class MessagesController < BaseController
    def create
      revision = Revision.find(params[:revision_id])

      unless Anthropic::Client.configured?
        return redirect_to admin_revision_path(revision),
                           alert: "No Anthropic API key is configured."
      end

      unless revision.editable?
        return redirect_to admin_revision_path(revision),
                           alert: "That draft is closed, so it cannot be changed. " \
                                  "Start a new draft to make changes."
      end

      # Photographs attached to the message itself. "Replace Fr David's photo
      # with the one I am about to upload" only works if the upload and the
      # sentence arrive together -- otherwise the turn starts first and the
      # model is left guessing which photographs are the new ones.
      uploads = Admin::PhotoIntake.call(params[:files], tags: Array(params[:tags]).compact_blank)
      taken = uploads.select(&:ok?)
      taken.each { |r| DescribePhotoJob.perform_later(r.photo.id) }
      refused = uploads.reject(&:ok?)

      text = params[:content].to_s.strip
      if text.blank? && taken.any?
        # Uploading with nothing said is a request in itself: here are some
        # photographs, what now?
        text = "I have uploaded #{helpers.pluralize(taken.size, 'photograph')}."
      end

      # The model should know a picture came out of a video, because the person
      # will talk about it as a video and wonder why it does not play.
      stills = taken.select(&:from_video)
      if stills.any? && text.present?
        text += "\n\n(#{helpers.pluralize(stills.size, 'of these')} is a still frame taken " \
                "from a video — #{stills.map { |s| s.from_video[:filename] }.join(', ')}. " \
                "The video itself is not on the site.)"
      end
      if text.blank?
        alert = refused.map { |r| "#{r.filename}: #{r.error}" }.join("; ").presence
        return redirect_to admin_revision_path(revision), alert: alert
      end

      # Out of the request. A turn can take a minute, and a frozen page with no
      # sign of life is the difference between usable and not.
      revision.messages.create!(role: "user", content: text,
                                attachments: taken.map { |r|
                                  { "photo" => r.photo.human_name, "version" => r.photo.version,
                                    "filename" => r.filename }
                                })
      placeholder = revision.messages.create!(role: "assistant", state: "working",
                                              content: "", progress: [])

      EditingTurnJob.perform_later(revision.id, text, placeholder.id)
      redirect_to admin_revision_path(revision),
                  alert: refused.map { |r| "#{r.filename}: #{r.error}" }.join("; ").presence
    end
  end
end
