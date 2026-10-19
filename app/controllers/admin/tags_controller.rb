module Admin
  # Tags exist so they can be picked from a menu. Creating one is typing it.
  class TagsController < BaseController
    def create
      tag = Tag.for(params[:label])
      redirect_back fallback_location: admin_photos_path,
                    notice: tag ? "Tag \"#{tag.label}\" is ready to use." : "That is not a usable tag name."
    end

    # Removing a tag unties it from its photographs; it never removes a
    # photograph. Nothing in this admin destroys an image.
    def destroy
      tag = Tag.find(params[:id])
      count = tag.photos.count
      tag.destroy
      redirect_back fallback_location: admin_photos_path,
                    notice: "Removed the tag \"#{tag.label}\" from #{helpers.pluralize(count, 'photograph')}. " \
                            "The photographs themselves are untouched."
    end
  end
end
