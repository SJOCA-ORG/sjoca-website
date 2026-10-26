# Where the site's mail goes out through.
#
# One parish's Google Workspace account, for now. That is a deliberate
# stopgap: a second parish is coming and will run as a separate instance, and
# at that point mail should move to a service that is nobody's mailbox --
# Resend or similar. Because every setting here comes from the environment or
# the credentials, that move is configuration and a DNS record, not code.
#
# ENV first, then credentials. Credentials work on this laptop and on Render
# (which holds RAILS_MASTER_KEY); ENV lets a password be rotated on the server
# without a deploy.
Rails.application.configure do
  smtp = Rails.application.credentials.smtp || {}

  user     = ENV["SMTP_USER_NAME"].presence || smtp[:user_name]
  password = ENV["SMTP_PASSWORD"].presence  || smtp[:password]

  site = ENV.fetch("SITE_URL", "http://localhost:3000")
  uri  = URI.parse(site)
  config.action_mailer.default_url_options = {
    host: uri.host, port: uri.port, protocol: uri.scheme
  }.compact

  # Mail that cannot be sent should say so loudly in development, and never
  # take down a web request in production.
  config.action_mailer.raise_delivery_errors = !Rails.env.production?
  config.action_mailer.perform_caching = false

  # Never in test, whatever the credentials say. The credentials file is the
  # same one on this laptop, so without this line the suite would quietly start
  # sending real mail to real people the first time anything delivered now
  # rather than later.
  if Rails.env.test?
    config.action_mailer.delivery_method = :test
  elsif user.present? && password.present?
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
      address:              ENV.fetch("SMTP_ADDRESS", "smtp.gmail.com"),
      port:                 ENV.fetch("SMTP_PORT", 587).to_i,
      domain:               ENV.fetch("SMTP_DOMAIN", "sjoca.org"),
      user_name:            user,
      password:             password,
      authentication:       :plain,
      enable_starttls_auto: true,
      open_timeout:         10,
      read_timeout:         10
    }
  else
    # No credentials: queue it nowhere rather than pretending it went.
    config.action_mailer.delivery_method = :test
  end
end
