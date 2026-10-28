require "rails_helper"

# Rails' uniqueness validator does not respect default_scope.
#
#   activerecord-8.1.4/lib/active_record/validations/uniqueness.rb:113
#     relation = klass.unscoped
#
# That is deliberate on Rails' part and quietly fatal here. Organization
# scoping in this app is a default_scope, so every `validates ... uniqueness:`
# on a scoped model runs across EVERY organization unless it names
# organization_id in its scope.
#
# Four did when this was written -- Photo#version, Photo#sha256, Tag#name and
# Lesson#body. The symptom is not a crash. It is a second organization being
# told its photograph name is already taken, which is wrong, and which answers
# a question about somebody else's data that nobody should be able to ask.
#
# So the audit is a spec rather than something somebody remembered to do once.
RSpec.describe "uniqueness validations are scoped to the organization" do
  before(:all) { Rails.application.eager_load! }

  def scoped_models
    ApplicationRecord.descendants
                     .reject(&:abstract_class?)
                     .select { |m| m.include?(BelongsToOrganization) }
  end

  it "has at least one organization-scoped model to check" do
    expect(scoped_models).not_to be_empty
  end

  it "names organization_id in every uniqueness scope on a scoped model" do
    offenders = scoped_models.flat_map do |model|
      model.validators
           .grep(ActiveRecord::Validations::UniquenessValidator)
           .reject { |v| Array(v.options[:scope]).include?(:organization_id) }
           .flat_map { |v| v.attributes.map { |a| "#{model.name}##{a}" } }
    end

    expect(offenders).to be_empty, <<~MSG
      These uniqueness validations run across every organization in the system:

        #{offenders.join("\n        ")}

      Add :organization_id to the scope. The default_scope will not do it for
      you -- Rails' uniqueness validator calls klass.unscoped.
    MSG
  end

  # The same thing from the outside, so the spec above cannot pass by accident
  # on a model whose validator options merely look right.
  it "lets two organizations hold the same photograph name" do
    # Both creates name their organization explicitly. They have to: the moment
    # a second organization exists, Current.organization stops guessing and the
    # scoped models answer nothing. That is the fail-closed rule working, and
    # it is why this spec cannot be written the lazy way.
    mine_org  = Organization.sole_tenant or raise "expected one organization to start from"
    other     = Organization.create!(name: "Other", slug: "other")

    bytes = "PNG-aaaaaaaa"
    mine = Organization.acting_as(mine_org) do
      Photo.create!(human_name: "shared-name", content_type: "image/png", data: bytes,
                    byte_size: bytes.bytesize, sha256: Photo.digest(bytes),
                    status: "published", version: 1)
    end

    theirs = Organization.acting_as(other) do
      Photo.create!(human_name: "shared-name", content_type: "image/png", data: bytes,
                    byte_size: bytes.bytesize, sha256: Photo.digest(bytes),
                    status: "published", version: 1)
    end

    expect(theirs).to be_persisted
    expect(theirs.organization_id).not_to eq(mine.organization_id)
    expect(theirs.version).to eq(mine.version)
  end
end
