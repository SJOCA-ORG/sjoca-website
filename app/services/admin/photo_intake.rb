module Admin
  # Taking a photograph in from a person's computer.
  #
  # Everything here is about the two ways this goes wrong quietly.
  #
  # EXIF. A phone photograph carries where it was taken and when, often to
  # within a few metres. A parish uploading pictures of a coffee hour would be
  # publishing the coordinates of whoever's house it was in, and nobody would
  # ever decide to do that -- it would just happen. Stripped on arrival, before
  # the bytes are ever stored, so there is no window where the original sits in
  # the database waiting to be served.
  #
  # Naming. human_name is a slug that pages point at, and IMG_4821 is not one.
  # The upload gets a provisional name; the AI proposes a real one from what it
  # can see, and the editor corrects it in conversation.
  class PhotoIntake
    class Rejected < StandardError; end

    MAX_BYTES = 20.megabytes
    MAX_PIXELS = 50_000_000         # a 50MP cap: anything larger is a mistake
    TYPES = %w[image/jpeg image/png image/webp image/gif image/heic image/heif].freeze
    # Accepted, but never stored: a video is turned into one still frame.
    VIDEO_TYPES = VideoFrame::TYPES
    # Stored as PNG or JPEG whatever arrives: HEIC is an Apple format that
    # browsers do not reliably render, and a photograph nobody can see is worse
    # than one that took a moment to convert.
    CONVERT_TO = { "image/heic" => "image/jpeg", "image/heif" => "image/jpeg" }.freeze

    Result = Struct.new(:photo, :filename, :error, :from_video, keyword_init: true) do
      def ok? = photo.present?
    end

    def self.call(uploads, tags: [], uploaded_at: Time.current)
      Array(uploads).compact_blank.map { |u| new(u, tags: tags, uploaded_at: uploaded_at).call }
    end

    def initialize(upload, tags: [], uploaded_at: Time.current)
      @upload = upload
      @tags = Array(tags).compact_blank
      @uploaded_at = uploaded_at
    end

    def call
      filename = @upload.original_filename.to_s
      bytes = @upload.read
      type = declared_type

      # A video becomes a still. The clip itself is not stored -- putting video
      # on this site is a bad trade (see docs/TODO.md) -- but a frame from it is
      # an ordinary photograph, and a parish with phone videos of a picnic has
      # pictures of that picnic whether or not anyone realised it.
      if VideoFrame.video?(type)
        bytes, @from_video = frame_from(bytes, filename)
        type = "image/jpeg"
      end

      check!(bytes, type)
      clean, final_type = strip_metadata(bytes, type)

      photo = Photo.create!(
        human_name: provisional_name(filename),
        data: clean, content_type: final_type, byte_size: clean.bytesize,
        sha256: Digest::SHA256.hexdigest(clean),
        status: "published", uploaded_at: @uploaded_at,
        original_filename: filename,
        alt_text: nil                       # written by DescribePhotoJob, which can see it
      )
      photo.tag_with(@tags) if @tags.any?

      Result.new(photo: photo, filename: filename, from_video: @from_video)
    rescue Rejected, ActiveRecord::RecordInvalid, ImageTools::ToolError => e
      Result.new(filename: @upload.try(:original_filename).to_s, error: e.message)
    end

    private

    def frame_from(bytes, filename)
      frame, facts = VideoFrame.call(bytes, extension: File.extname(filename).delete("."))
      [frame, facts.merge(filename: filename)]
    rescue VideoFrame::Failed => e
      raise Rejected, e.message
    end

    def declared_type
      type = @upload.content_type.to_s.split(";").first.to_s.strip.downcase
      return type if TYPES.include?(type)

      # Browsers sometimes send nothing useful for HEIC.
      return type if VIDEO_TYPES.include?(type)

      by_extension = { "heic" => "image/heic", "heif" => "image/heif", "jpg" => "image/jpeg",
                       "jpeg" => "image/jpeg", "png" => "image/png", "webp" => "image/webp",
                       "gif" => "image/gif",
                       "mp4" => "video/mp4", "m4v" => "video/x-m4v", "mov" => "video/quicktime",
                       "mpeg" => "video/mpeg", "mpg" => "video/mpeg", "webm" => "video/webm",
                       "avi" => "video/x-msvideo", "3gp" => "video/3gpp" }
      by_extension[File.extname(@upload.original_filename.to_s).delete(".").downcase] || type
    end

    def check!(bytes, type)
      raise Rejected, "that file is empty" if bytes.blank?
      raise Rejected, "#{ActiveSupport::NumberHelper.number_to_human_size(bytes.bytesize)} is over " \
                      "the #{ActiveSupport::NumberHelper.number_to_human_size(MAX_BYTES)} limit" if bytes.bytesize > MAX_BYTES
      raise Rejected, "#{type.presence || 'that'} is not an image this site can use. " \
                      "JPEG, PNG, WEBP, GIF and HEIC are fine." unless TYPES.include?(type)
    end

    # The strip is the point; the identify is to be sure it IS an image and not
    # something renamed to look like one.
    def strip_metadata(bytes, type)
      target = CONVERT_TO.fetch(type, type)
      format = target.split("/").last.sub("jpeg", "jpg")

      info = ImageTools.identify(bytes)
      raise Rejected, "that file is not really an image" if info.blank?
      raise Rejected, "that image is #{info[:pixels]} pixels, which is implausibly large" if info[:pixels] > MAX_PIXELS

      [ImageTools.strip(bytes, format), target]
    end

    # Enough to be a valid slug and to tell two uploads apart. Not meant to
    # survive: the AI proposes a real name once it has looked at the picture.
    def provisional_name(filename)
      stem = File.basename(filename.to_s, ".*").downcase
                 .gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "")

      # "....jpg" has no extension as far as Ruby is concerned -- a leading dot
      # means a hidden file -- so the stem came out as "jpg", which is a valid
      # name and a useless one.
      stem = "upload" if stem.blank? || stem.length < 3 ||
                         %w[jpg jpeg png gif webp heic heif image photo img].include?(stem)
      candidate = "new-#{stem}".first(60)

      return candidate unless Photo.exists?(human_name: candidate)

      # A second upload of the same filename is a NEW photograph, not a new
      # version of the first: nothing says IMG_4821 twice means the same subject.
      suffix = 2
      suffix += 1 while Photo.exists?(human_name: "#{candidate}-#{suffix}")
      "#{candidate}-#{suffix}"
    end
  end
end
