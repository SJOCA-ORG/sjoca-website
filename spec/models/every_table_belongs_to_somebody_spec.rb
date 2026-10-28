require "rails_helper"

# The guard that makes multi-organization hosting reviewable.
#
# Scoping thirty tables is a job you can finish. Keeping them scoped, as models
# are added over the next two years by somebody who was not here for this
# conversation, is not -- unless forgetting is what fails the build.
#
# So this spec does not check a list of models that exist today. It insists that
# EVERY model reach an organization by one of four stated routes, and it fails
# on anything new until somebody says which route it takes and why. Adding a
# table without an owner is possible; doing it quietly is not.
RSpec.describe "every table belongs to somebody" do
  before(:all) { Rails.application.eager_load! }

  # Scoped directly: carries organization_id and a default_scope.
  SCOPED = %w[Revision Photo Tag Promise Lesson FetchedPage].freeze

  # Scoped through their revision, which is itself scoped. Checked, not trusted
  # -- each must really have the association.
  THROUGH_REVISION = %w[
    Page Section Block Template ThemeAsset SiteSetting
    DataSource RevisionPromise RevisionMessage
  ].freeze

  # Reached only through rows that are themselves scoped.
  THROUGH_OWNER = { "PhotoTag" => :photo }.freeze

  # Genuinely global, each for a reason that has to be written down.
  GLOBAL = {
    "Organization"     => "is the thing being scoped TO",
    "OrganizationHost" => "maps a hostname to an organization, before any scope exists",
    "User"             => "sign-in happens before a hostname is resolved, and an " \
                          "application admin belongs to no organization. " \
                          "Authorisation does this work instead -- User#may_act_in?"
  }.freeze

  def models
    ApplicationRecord.descendants.reject(&:abstract_class?).reject do |m|
      m.name.nil? || m.name.start_with?("SolidQueue", "ActiveRecord")
    end
  end

  it "accounts for every single model" do
    named = SCOPED + THROUGH_REVISION + THROUGH_OWNER.keys + GLOBAL.keys
    unaccounted = models.map(&:name) - named

    expect(unaccounted).to be_empty, <<~MSG
      These models reach no organization by any route this spec knows about:

        #{unaccounted.join("\n        ")}

      Pick one and say so in spec/models/every_table_belongs_to_somebody_spec.rb:

        SCOPED           include BelongsToOrganization, and add organization_id
        THROUGH_REVISION belongs_to :revision
        THROUGH_OWNER    reached only through something already scoped
        GLOBAL           shared by every organization -- and write down why

      A model in none of them is readable by anyone who guesses an id.
    MSG
  end

  describe "the scoped ones" do
    SCOPED.each do |name|
      it "#{name} filters on the organization, and returns nothing without one" do
        model = name.constantize
        expect(model.include?(BelongsToOrganization)).to be(true)
        expect(model.column_names).to include("organization_id")

        # The fail-closed promise, which is the half people assume rather than
        # check. With no organization these tables are empty, not permissive.
        Current.organization = nil
        allow(Organization).to receive(:sole_tenant).and_return(nil)
        expect(model.all.to_sql).to include("IS NULL").or include("= NULL")
      end
    end
  end

  describe "the ones that inherit it" do
    THROUGH_REVISION.each do |name|
      it "#{name} really does belong to a revision" do
        expect(name.constantize.reflect_on_association(:revision)).to be_present
      end
    end

    THROUGH_OWNER.each do |name, owner|
      it "#{name} really does belong to a #{owner}" do
        expect(name.constantize.reflect_on_association(owner)).to be_present
      end
    end
  end

  describe "the global ones" do
    GLOBAL.each_key do |name|
      it "#{name} is global on purpose and not by omission" do
        expect(GLOBAL[name]).to be_present
        expect(name.constantize.include?(BelongsToOrganization)).to be(false)
      end
    end
  end
end
