class LectionaryReading < ApplicationRecord
  belongs_to :lectionary_day, class_name: "LectionaryDay"

  validates :citation, :position, presence: true

  def label = [kind.presence, citation].compact.join(" — ")

  # [[verse_number, text], ...]
  def verses
    body.to_s.split("\n").filter_map { |line|
      num, text = line.split(" ", 2)
      [num, text] if text
    }
  end

  # The reading broken into paragraphs.
  #
  # The source gives verses and nothing else: oca.org publishes a numbered list
  # with no paragraph information, and scripture paragraphing is editorial
  # anyway — translations disagree about where breaks belong. So this is a
  # presentation choice, not an authority, and it is deliberately conservative:
  #
  #   * never break mid-sentence — a paragraph ends only where a verse does
  #   * aim for three to four verses, cap at six so nothing becomes a wall
  #   * break ahead of a change of speaker, which is where English bibles
  #     usually break in narrative
  #
  # If the parish ever wants the breaks to be right rather than merely
  # readable, someone has to mark them by hand, or the text has to come from a
  # source that carries them.
  TERMINAL = /[.!?][”"’\')\]]*\s*\z/
  NEW_SPEAKER = /\A(?:And|But|Then|Now|So)\s+(?:[A-Z]\w+|He|She|they|He)\b.{0,24}\b(?:said|answered|replied|asked|spoke)\b/i

  TARGET = 3
  MAX    = 6

  def paragraphs
    out = []
    current = []
    verses.each do |_num, text|
      starts_new = current.size >= TARGET && NEW_SPEAKER.match?(text)
      if starts_new && TERMINAL.match?(current.last.to_s)
        out << current.join(" ")
        current = []
      end
      current << text
      if current.size >= MAX && TERMINAL.match?(text)
        out << current.join(" ")
        current = []
      elsif current.size >= TARGET + 1 && TERMINAL.match?(text) && out.size.zero?
        # Let the opening paragraph close a little sooner; a long first block
        # is the one most likely to put a reader off.
        out << current.join(" ")
        current = []
      end
    end
    out << current.join(" ") if current.any?
    out
  end
end
