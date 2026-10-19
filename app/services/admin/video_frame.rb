module Admin
  # One still frame out of a video, so a short clip can at least become a
  # picture.
  #
  # Mitch's idea, and a good one: the parish has phone videos of events, and
  # putting video ON this site is a bad trade -- see docs/TODO.md -- but a
  # frame from one is an ordinary photograph with all the usual properties.
  # Google Photos shows a decent still for every clip; there is no reason this
  # cannot.
  #
  # The video itself is NEVER stored. It is read once, in a temporary file,
  # and the frame is what survives.
  #
  # ffmpeg, not ImageMagick: ImageMagick would shell out to a delegate for
  # video, and config/imagemagick/policy.xml forbids delegates outright. That
  # was a deliberate hardening and it stands.
  class VideoFrame
    class Failed < StandardError; end

    BINARY   = "ffmpeg".freeze
    PROBE    = "ffprobe".freeze
    TIMEOUT  = 60
    MAX_BYTES = 300.megabytes

    TYPES = %w[video/mp4 video/mpeg video/quicktime video/x-m4v video/webm
               video/x-msvideo video/3gpp].freeze

    def self.video?(content_type) = TYPES.include?(content_type.to_s.downcase)

    def self.available?
      @available = system(BINARY, "-version", out: File::NULL, err: File::NULL) if @available.nil?
      @available
    end

    def self.call(bytes, extension: "mp4") = new(bytes, extension).call

    def initialize(bytes, extension)
      @bytes = bytes
      @extension = extension.to_s.gsub(/[^a-z0-9]/i, "").presence || "mp4"
    end

    # Returns [jpeg bytes, {duration:, width:, height:}].
    def call
      raise Failed, "video cannot be read on this server — ffmpeg is not installed" unless self.class.available?
      raise Failed, "that video is too large to read" if @bytes.bytesize > MAX_BYTES

      Tempfile.create(["upload", ".#{@extension}"], binmode: true) do |file|
        file.write(@bytes)
        file.flush

        facts = probe(file.path)
        raise Failed, "that file does not contain a video track" if facts[:width].to_i.zero?

        [frame(file.path), facts]
      end
    end

    private

    # ffmpeg's own thumbnail filter, which looks at a batch of frames and picks
    # the most representative. The first frame of a phone video is very often
    # black, or a blurred hand -- which is the whole reason this is not simply
    # "take frame zero".
    def frame(path)
      bytes = run(BINARY, [
        "-nostdin", "-loglevel", "error",
        "-i", path,
        "-vf", "thumbnail=n=120",
        "-frames:v", "1",
        "-f", "image2", "-c:v", "mjpeg", "-q:v", "3",
        "-"
      ])
      return bytes if bytes.present?

      # Some clips are shorter than the window the filter wants. Fall back to a
      # second in, which is past the shaky start of most phone videos.
      run(BINARY, ["-nostdin", "-loglevel", "error", "-ss", "1", "-i", path,
                   "-frames:v", "1", "-f", "image2", "-c:v", "mjpeg", "-q:v", "3", "-"])
        .presence || raise(Failed, "no frame could be read from that video")
    end

    def probe(path)
      out = run(PROBE, ["-v", "error", "-select_streams", "v:0",
                        "-show_entries", "stream=width,height:format=duration",
                        "-of", "default=noprint_wrappers=1", path], raw: false)
      values = out.to_s.scan(/^(\w+)=(.+)$/).to_h
      { width: values["width"].to_i, height: values["height"].to_i,
        duration: values["duration"].to_f.round(1) }
    rescue Failed
      { width: 0, height: 0, duration: 0.0 }
    end

    # No shell, a hard timeout, and no network: ffmpeg parsing a file somebody
    # uploaded is a real attack surface, and it has had its share of CVEs.
    def run(command, args, raw: true)
      out = err = status = nil
      Timeout.timeout(TIMEOUT) do
        out, err, status = Open3.capture3(command, *args, binmode: raw)
      end
      raise Failed, "#{command} could not read that video: #{err.to_s.lines.first&.strip}" unless status&.success?

      out
    rescue Timeout::Error
      raise Failed, "that video took longer than #{TIMEOUT} seconds to read and was stopped"
    rescue Errno::ENOENT
      raise Failed, "video cannot be read on this server — #{command} is not installed"
    end
  end
end
