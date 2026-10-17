module Admin
  # What the site's stylesheet already DOES, read off the stylesheet itself.
  #
  # Written because the AI's CSS worked but drifted: hyphenated class names in a
  # file that uses BEM double underscores, a max-width media query in a file
  # that is mobile-first, and one rule appended to patch another it had written
  # four steps earlier. None of that is a mistake in isolation; together, over a
  # season, it is the mess that makes a stylesheet unmaintainable.
  #
  # It drifted because it had never seen the file. The instructions told it not
  # to call get_styles -- a rule meant to stop it REWRITING 17KB that also
  # stopped it READING 17KB, which costs about 4,900 tokens and is affordable.
  #
  # Measured rather than written down, so it describes the file as it is today
  # and cannot be left behind by it.
  class CssConventions
    def self.call(revision)
      css = ThemeAsset.css_for(revision)
      return { note: "there is no stylesheet yet" } if css.blank?

      new(css).to_h
    end

    def initialize(css)
      @css = css
      # Comments are prose about CSS, not CSS. Scraping them produced a custom
      # property called --map whose value was the opening of a sentence.
      @code = css.gsub(%r{/\*.*?\*/}m, " ")
    end

    def to_h
      { size: "#{(@css.bytesize / 1024.0).round(1)}KB — small enough to read whole with " \
              "get_styles, which you should do before writing CSS. Never send it BACK whole.",
        naming: naming,
        breakpoints: breakpoints,
        units: units,
        colours_and_fonts: variables,
        bands: "Blocks sit inside bands: .band--plain, .band--light, .band--maroon. " \
               "Text on maroon is white. If a thing can appear in more than one band, " \
               "give it a rule for the maroon case, as the existing rules do." }
    end

    private

    def naming
      bem   = @code.scan(/\.[a-z][\w-]*__[\w-]+/).uniq
      plain = @code.scan(/\.[a-z][\w-]*-[\w-]+(?![\w-]*__)/).uniq
      return "no clear convention in the file yet" if bem.empty?

      "#{bem.size} class names use BEM double underscore (block__element): " \
        "#{bem.first(6).join(', ')}. Follow it. Write .calendar__day, not " \
        ".calendar-day. Modifiers use a double hyphen, as in .band--maroon. " \
        "(#{plain.size} single-hyphen names exist, mostly older ones.)"
    end

    def breakpoints
      # Only inside @media. An element with min-width: 190px is a layout rule,
      # not a breakpoint, and reporting it as one sent the AI looking for a
      # 190px phone.
      queries = @code.scan(/@media[^{]+/).join(" ")
      mins = queries.scan(/min-width:\s*([\d.]+)px/).flatten.map(&:to_i).tally.sort_by { |_, c| -c }
      maxes = queries.scan(/max-width:\s*([\d.]+)px/).flatten.map(&:to_i).uniq
      return "no media queries in the file" if mins.empty? && maxes.empty?

      text = +"This stylesheet is MOBILE FIRST: the plain rule is the phone, and " \
              "min-width queries add to it. Use the widths already in the file: " \
              "#{mins.map { |w, c| "#{w}px (#{c} uses)" }.join(', ')}."
      text << " Avoid max-width queries — there #{maxes.size == 1 ? 'is' : 'are'} " \
              "only #{maxes.size} in the whole file and they fight the mobile-first ones." if maxes.any?
      text
    end

    def units
      pt  = @code.scan(/[\d.]+pt\b/).size
      rem = @code.scan(/[\d.]+rem\b/).size
      "Type is sized in pt (#{pt} uses), spacing in rem (#{rem} uses). " \
        "That is unusual but it is what the whole file does — match it."
    end

    # The parish's actual palette, which is the thing most worth not inventing.
    def variables
      root = @code[/:root\s*\{(.*?)\}/m, 1].to_s
      names = root.scan(/(--[a-z][\w-]*)\s*:\s*([^;]+);/).to_h
      return "no custom properties found" if names.empty?

      "Use these, never a literal colour or font stack: " +
        names.map { |n, v| "var(#{n}) = #{v.strip.truncate(40)}" }.join("; ")
    end
  end
end
