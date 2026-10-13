require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"

abort("The Rails environment is running in production mode!") if Rails.env.production?

require "rspec/rails"
require "webmock/rspec"

Dir[Rails.root.join("spec/support/**/*.rb")].sort.each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
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
  end
end
