module Admin
  # Photographs: the library, and taking new ones in.
  class PhotosController < BaseController
    def index
      @tags = Tag.in_menu.includes(:photos)
      @filter = params[:tag].presence
      @photos = @filter ? Photo.published.tagged(@filter) : Photo.published
      @photos = @photos.where("human_name ILIKE :q OR alt_text ILIKE :q", q: "%#{params[:q]}%") if params[:q].present?
      @photos = @photos.order(uploaded_at: :desc, human_name: :asc).limit(200)
      @recent = Photo.recently_uploaded(1.day.ago).limit(24)
    end

    def create
      results = PhotoIntake.call(params[:files], tags: tag_list)
      taken = results.select(&:ok?)
      taken.each { |r| DescribePhotoJob.perform_later(r.photo.id) }

      refused = results.reject(&:ok?)
      notice = "#{helpers.pluralize(taken.size, 'photograph')} added."
      notice += " #{refused.map { |r| "#{r.filename}: #{r.error}" }.join('; ')}" if refused.any?

      redirect_to admin_photos_path, notice: notice
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

      redirect_back fallback_location: admin_photos_path,
                    notice: "Updated #{photo.reload.human_name}."
    rescue ActiveRecord::RecordInvalid => e
      redirect_back fallback_location: admin_photos_path, alert: e.record.errors.full_messages.to_sentence
    end

    private

    def tag_list
      raw = params[:tags]
      list = raw.is_a?(Array) ? raw : raw.to_s.split(",")
      list.map(&:strip).compact_blank
    end

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
