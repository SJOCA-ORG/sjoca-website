# One editable state of the whole site.
#
# The live site renders the published revision; /preview/:id renders any other.
# Publishing is a pointer flip, not a deploy -- instant, and reversible in both
# directions, so any revision can be made live again.
class Revision < ApplicationRecord
  STATES = %w[draft published superseded discarded].freeze

  has_many :pages,    dependent: :destroy
  has_many :sections, dependent: :destroy
  has_many :blocks,   dependent: :destroy
  has_many :theme_assets, dependent: :destroy
  has_many :templates,    dependent: :destroy
  has_many :messages, -> { order(:created_at) },
           class_name: "RevisionMessage", dependent: :destroy, inverse_of: :revision

  belongs_to :based_on, class_name: "Revision", optional: true

  validates :state, inclusion: { in: STATES }

  scope :drafts, -> { where(state: "draft").order(created_at: :desc) }

  def self.live = find_by(state: "published")

  # A sandbox: a full copy of the live content, which the editor then changes.
  # Photographs are not copied -- blocks reference them by human_name, and
  # `photos` versions itself.
  def self.open_sandbox(title: nil, created_by: nil)
    source = live or raise "no published revision to branch from"

    transaction do
      draft = create!(state: "draft", title: title || "Draft #{Time.current.strftime('%-d %b, %H:%M')}",
                      created_by: created_by, based_on: source)

      # Templates first: a block's kind is only valid if block/<kind> exists in
      # the same revision, so copying content before templates fails validation.
      source.templates.find_each    { |t| t.dup.tap { |c| c.revision = draft }.save! }
      source.theme_assets.find_each { |a| a.dup.tap { |c| c.revision = draft }.save! }

      pages    = source.pages.index_with    { |p| p.dup.tap { |c| c.revision = draft }.tap(&:save!) }
      sections = source.sections.index_with { |s|
        s.dup.tap { |c| c.revision = draft; c.page = pages[s.page] }.tap(&:save!) }
      source.blocks.find_each do |b|
        b.dup.tap { |c| c.revision = draft; c.section = sections[b.section] }.save!
      end
      draft
    end
  end

  def live? = state == "published"
  def editable? = state == "draft"

  # The only atomic moment in the system.
  def publish!(by: nil)
    raise "already live" if live?

    self.class.transaction do
      self.class.where(state: "published").update_all(state: "superseded")
      update!(state: "published", published_at: Time.current,
              created_by: created_by || by)
    end
    self
  end

  def summary = "#{pages.count} pages, #{sections.count} sections, #{blocks.count} blocks"
end
