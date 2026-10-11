class LegacyAssetsController < ApplicationController
  # Serves the current version of an asset straight from the database.
  #
  # The URL is stable (/media/home-icon-st-john) while the content behind it can
  # change, so correctness rests on the ETag rather than the path. The ETag is
  # the asset's sha256: publish a new version and every cache revalidates.
  #
  # Cache window is deliberately short. An hour would mean a parishioner
  # approving a photo swap and then not seeing it, which reads as a broken
  # workflow. Five minutes plus revalidation is cheap and behaves predictably.
  def show
    asset = LegacyAsset.current(params[:human_name])
    return head :not_found unless asset

    # stale? issues the 304 itself when it returns false. Do not also call
    # `head :not_modified` -- that renders twice and raises DoubleRenderError,
    # which surfaces as an image that loads once and then breaks on reload.
    return unless stale?(etag: asset.sha256, last_modified: asset.updated_at, public: true)

    expires_in 5.minutes, public: true, must_revalidate: true
    send_data asset.data, type: asset.content_type, disposition: "inline"
  end
end
