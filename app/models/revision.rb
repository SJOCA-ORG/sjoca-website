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
  has_many :site_settings, dependent: :destroy
  has_many :revision_promises, dependent: :destroy
  has_many :data_sources, dependent: :destroy
  has_many :promises, through: :revision_promises
  has_many :messages, -> { order(:created_at) },
           class_name: "RevisionMessage", dependent: :destroy, inverse_of: :revision

  belongs_to :based_on, class_name: "Revision", optional: true

  validates :state, inclusion: { in: STATES }

  scope :drafts, -> { where(state: "draft").order(created_at: :desc) }

  def self.live = find_by(state: "published")

  # A signed, expiring link that shows this revision to someone who is not
  # logged in -- a headless browser running the visual checks, or an Approver
  # on their phone. Signed rather than a bare id, so a draft cannot be read by
  # guessing numbers.
  PREVIEW_PURPOSE = "revision_preview"

  def preview_token
    Rails.application.message_verifier(PREVIEW_PURPOSE).generate(id, expires_in: 7.days)
  end

  def self.from_preview_token(token)
    id = Rails.application.message_verifier(PREVIEW_PURPOSE).verified(token.to_s)
    id && find_by(id: id)
  end

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

      # The promise LIST is copied; the promises themselves are shared and
      # immutable, so there is nothing to duplicate.
      source.revision_promises.find_each do |rp|
        draft.revision_promises.create!(promise_id: rp.promise_id)
      end
      source.theme_assets.find_each { |a| a.dup.tap { |c| c.revision = draft }.save! }
      # The DEFINITION of a data source travels with the revision. The cached
      # response does not -- that is keyed by URL and shared (FetchedPage).
      source.data_sources.find_each { |d| d.dup.tap { |c| c.revision = draft }.save! }
      # The parish's own facts -- its name, its address -- travel with the
      # revision like everything else that makes up the site. Forgetting this
      # would give every new draft a site with no name.
      source.site_settings.find_each { |s| s.dup.tap { |c| c.revision = draft }.save! }

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

  # What this revision changed about the site's standing promises, for the
  # approval screen. Removals are reported in full -- they are the hardest
  # change for a reviewer to notice, because "removed a check that no longer
  # applies" reads as tidying.
  def promise_changes
    return { added: [], removed: [] } if based_on.nil?

    mine   = promise_ids.to_set
    before = based_on.promise_ids.to_set

    { added:   Promise.where(id: (mine - before).to_a).to_a,
      removed: Promise.where(id: (before - mine).to_a).to_a }
  end

  # Domains this revision fetches from that the live site does not. Decided in
  # docs/TODO.md: the list of allowed domains is left OPEN rather than
  # maintained by hand, and the first use of a new one is surfaced to whoever
  # approves the change instead. A new outbound connection should never be
  # invisible to the person saying yes to it.
  def new_domains
    mine = data_sources.flat_map(&:domains).uniq
    return mine if based_on.nil?

    mine - based_on.data_sources.flat_map(&:domains).uniq
  end

  def summary = "#{pages.count} pages, #{sections.count} sections, #{blocks.count} blocks"
end
