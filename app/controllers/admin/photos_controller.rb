module Admin
  # Photographs: the library, and taking new ones in.
  class PhotosController < BaseController
    def index
      # No includes(:photos): the view only wants a count per tag, and preloading
      # the association fetches every photograph's bytes to produce a number.
      @tags = Tag.in_menu
      @filter = params[:tag].presence
      @photos = @filter ? Photo.published.tagged(@filter) : Photo.published
      @photos = @photos.where("human_name ILIKE :q OR alt_text ILIKE :q", q: "%#{params[:q]}%") if params[:q].present?
      # The ORDER is chosen, and stays chosen. It used to be fixed, and because
      # saving a name reloaded the page, the row you had just renamed jumped
      # somewhere else while you were still typing its tags.
      @order = %w[newest name].include?(params[:order]) ? params[:order] : "newest"
      @photos = case @order
                when "name" then @photos.listing.order(human_name: :asc)
                else             @photos.listing.order(uploaded_at: :desc, human_name: :asc)
                end.limit(200)
      @recent = Photo.recently_uploaded(1.day.ago).listing.limit(24)
    end

    def create
      results = PhotoIntake.call(params[:files], tags: tag_list)
      taken = results.select(&:ok?)

      # A photograph already in the library needs no second description, and
      # queueing one for every repeat is how a double-submitted form turned
      # into hundreds of jobs.
      fresh = taken.reject(&:already_here)
      fresh.each { |r| DescribePhotoJob.perform_later(r.photo.id) }
      again = taken.select(&:already_here)

      refused = results.reject(&:ok?)
      notice = "#{helpers.pluralize(fresh.size, 'photograph')} added."
      if again.any?
        notice += " #{helpers.pluralize(again.size, 'was')} already in the library " \
                  "and #{again.size == 1 ? 'was' : 'were'} not added twice."
      end

      # A video quietly turning into a picture would be baffling. Say so.
      from_video = fresh.select(&:from_video)
      if from_video.any?
        notice += " #{helpers.pluralize(from_video.size, 'video')} became a still picture — " \
                  "the clip itself is not kept. To show the video, put it on the parish " \
                  "YouTube channel and ask me to add it."
      end

      notice += " #{refused.map { |r| "#{r.filename}: #{r.error}" }.join('; ')}" if refused.any?

      # Back where you were. Adding photographs from the editing pane should
      # not take you out of the conversation you are having.
      redirect_to(params[:return_to].presence || admin_photos_path, notice: notice)
    end

    # Renaming, tagging and untagging -- the things an editor does to a
    # photograph without changing the picture.
    def update
      photo = Photo.find(params[:id])
      photo.tag_with(tag_list) if tag_list.any?
      photo.untag(params[:untag]) if params[:untag].present?

      if params[:human_name].present? && params[:human_name] != photo.human_name
        rename(photo, params[:human_name])
      end

      photo.reload

      # Asked for by a script, answer the script: the page must NOT reload, or
      # the row being edited is re-sorted out from under the person editing it.
      respond_to do |format|
        format.json { render json: { ok: true, name: photo.human_name,
                                     tags: photo.tag_labels,
                                     provisional: photo.provisional_name? } }
        format.html { redirect_back fallback_location: admin_photos_path,
                                    notice: "Updated #{photo.human_name}." }
      end
    rescue ActiveRecord::RecordInvalid => e
      message = e.record.errors.full_messages.to_sentence
      respond_to do |format|
        format.json { render json: { ok: false, error: message }, status: :unprocessable_content }
        format.html { redirect_back fallback_location: admin_photos_path, alert: message }
      end
    end

    # A description can fail -- the model has a bad minute, or thinks for so
    # long it runs out of room to answer. Asking again should not mean
    # uploading the photograph a second time.
    def describe
      photo = Photo.find(params[:id])
      photo.update_columns(alt_text: nil)
      DescribePhotoJob.perform_later(photo.id)
      redirect_back fallback_location: admin_photos_path,
                    notice: "Writing a description for #{photo.human_name}…"
    end

    private

    # "clergy, Pascha 2026" is one field holding two tags, and the checkbox menu
    # sends an array. Both arrive here, and a typed entry inside that array can
    # itself hold commas -- so split every element, never just the string case.
    def tag_list = Admin::PhotoIntake.tags_from(params[:tags])

    # A rename has to carry the references with it, or the page it was on goes
    # blank. Every version of the name moves together: they are the same subject.
    def rename(photo, to)
      slug = Tag.canonical(to)
      raise ActiveRecord::RecordInvalid, photo if slug.blank?

      Photo.transaction do
        Block.where(asset_name: photo.human_name).update_all(asset_name: slug)
        Page.where(hero_asset_name: photo.human_name).update_all(hero_asset_name: slug)
        Photo.where(human_name: photo.human_name).update_all(human_name: slug)
      end
    end
  end
end
