namespace :photos do
  desc "Describe photographs that have no description, by looking at them"
  task describe: :environment do
    # Two things at once. A description makes the library searchable -- without
    # it the AI sees "about-us-leadership-01" and cannot tell you who is in it --
    # and it is the alt text screen readers need, which check_page has been
    # reporting as missing on forty images.
    client = Anthropic::Client.new
    abort "no ANTHROPIC_API_KEY" unless Anthropic::Client.configured?

    SYSTEM = <<~PROMPT
      You are describing photographs for the website of an Orthodox parish, so
      they can be found later by what is in them, and so screen-reader users know
      what they show.

      One or two plain sentences. Say who or what is shown, what is happening,
      and where. Name vestment colours, which are liturgically meaningful.

      Do not guess at names of people you cannot identify -- say "a priest",
      "a server", "members of the congregation". Do not begin with "An image of"
      or "A photograph of". Do not editorialise.
    PROMPT

    todo = Photo.published.where(alt_text: [nil, ""]).order(:human_name)
    puts "#{todo.count} photographs without a description"

    todo.find_each.with_index do |photo, i|
      next unless photo.content_type.to_s.start_with?("image/")

      begin
        response = client.call(
          system: SYSTEM, max_tokens: 300,
          messages: [{ role: "user", content: [
            Anthropic::Client.image_block(photo.data, photo.content_type),
            { type: "text", text: "Describe this photograph. Its file is named " \
                                  "#{photo.human_name.inspect}, which may hint at the subject." }
          ] }]
        )
        text = Array(response["content"]).select { |c| c["type"] == "text" }
                                         .map { |c| c["text"] }.join(" ").strip
        photo.update_column(:alt_text, text) if text.present?
        puts "  #{photo.human_name}: #{text[0, 86]}"
      rescue StandardError => e
        warn "  #{photo.human_name}: FAILED (#{e.class}: #{e.message[0, 80]})"
      end

      sleep 0.3 if (i % 10).zero?   # be a polite client
    end
  end
end
