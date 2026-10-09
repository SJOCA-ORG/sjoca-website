class LegacyAssetsController < ApplicationController
  # Serves the current version of an asset straight from the database.
  #
  # Cached on the asset's sha256, so a replacement photo busts the cache for
  # everyone the moment it is published, while an unchanged one is revalidated
  # cheaply rather than re-sent.
  def show
    asset = LegacyAsset.current(params[:human_name])
    return head :not_found unless asset

    return head :not_modified if stale?(etag: asset.sha256, last_modified: asset.updated_at,
                                        public: true) == false

    expires_in 1.hour, public: true
    send_data asset.data, type: asset.content_type, disposition: "inline"
  end
end
