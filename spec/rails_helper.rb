require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"

abort("The Rails environment is running in production mode!") if Rails.env.production?

require "rspec/rails"
require "webmock/rspec"

require Rails.root.join("db/seeds/templates")
Dir[Rails.root.join("spec/support/**/*.rb")].sort.each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  # Time travel, for anything that expires, and a way to run jobs that were
  # queued rather than performed.
  config.include ActiveSupport::Testing::TimeHelpers
  config.include ActiveJob::TestHelper

  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  # Importers talk to ChurchTrac, oca.org and YouTube. None of those are ours,
  # none are reliable, and hammering them from a test run would be rude. Every
  # outbound request must be stubbed; an unstubbed one fails loudly.
  WebMock.disable_net_connect!(allow_localhost: true)

  # `db:prepare` seeds a freshly created database, so a developer's test DB may
  # arrive full of real parish content. Specs must not depend on whether that
  # happened. Start every run from empty.
  config.before(:suite) do
    tables = ActiveRecord::Base.connection.tables -
             %w[schema_migrations ar_internal_metadata]
    ActiveRecord::Base.connection.execute(
      "TRUNCATE #{tables.map { |t| %("#{t}") }.join(', ')} RESTART IDENTITY CASCADE"
    )

    # One organization for the whole run, created after the truncate and
    # committed, so it survives each example's transaction rolling back.
    #
    # Every model but User is scoped to an organization and answers NOTHING when
    # there is none -- so without this, the suite would not fail with a
    # permissions error, it would fail with four hundred empty results, which
    # takes much longer to understand.
    #
    # Current.organization finds it by itself while it is the only one. A spec
    # that needs two must set Current.organization explicitly; see
    # spec/requests/organization_isolation_spec.rb.
    Organization.create!(name: "Spec Organization", slug: "spec")
  end

  # The enqueued-job list and the deliveries array are process-wide and are NOT
  # rolled back with the transaction. Left alone, perform_enqueued_jobs in one
  # example runs whatever earlier examples enqueued -- against records that have
  # since been rolled back -- and ActionMailer::Base.deliveries.last is somebody
  # else's mail.
  #
  # That cost an hour: the operator console's invitation spec passed alone,
  # passed with its neighbour, and failed in the full suite, because it was
  # reading a token from a previous example's invitation to a user that no
  # longer existed.
  config.before(:each) do
    ActiveJob::Base.queue_adapter.enqueued_jobs.clear if ActiveJob::Base.queue_adapter.respond_to?(:enqueued_jobs)
    ActiveJob::Base.queue_adapter.performed_jobs.clear if ActiveJob::Base.queue_adapter.respond_to?(:performed_jobs)
    ActionMailer::Base.deliveries.clear
  end
end
