class PhotosController < ApplicationController
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
    # The version is part of the URL, so a replaced photograph never serves from
    # a cache under the old address.
    versioned = params[:version].present?

    # Metadata only -- calling .data on one of these raises, which is the
    # behaviour you want from a mistake. See Photo.metadata_version.
    asset = if versioned
              Photo.metadata_version(params[:human_name], params[:version])
            else
              Photo.metadata_newest(params[:human_name])
            end
    return head :not_found unless asset

    # Cache headers BEFORE stale?, so a 304 carries them too.
    #
    # A versioned address is immutable by construction: /media/home-hero/2 is
    # that exact set of bytes forever, because publishing a replacement makes
    # version 3. So it can be cached for a year and never revalidated. The
    # unversioned address is the opposite -- a pointer that moves when a
    # photograph is replaced, and five minutes is how long somebody should wait
    # to see a swap they just approved.
    if versioned
      expires_in 1.year, public: true, immutable: true
    else
      expires_in 5.minutes, public: true, must_revalidate: true
    end

    # stale? issues the 304 itself when it returns false. Do not also call
    # `head :not_modified` -- that renders twice and raises DoubleRenderError,
    # which surfaces as an image that loads once and then breaks on reload.
    return unless stale?(etag: asset.sha256, last_modified: asset.updated_at, public: true)

    bytes = Photo.bytes_for(asset.id)
    return head :not_found if bytes.nil?

    send_data bytes, type: asset.content_type, disposition: "inline"
  end
end
