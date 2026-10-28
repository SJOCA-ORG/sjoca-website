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

  # The FALLBACK host for links in email. The real one is decided per message,
  # from the organization the request is for -- see ApplicationMailer#url_options.
  # This is what gets used when there is no request: a rake task, a job, a
  # console session.
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
  elsif Rails.env.development? && ENV["SMTP_FOR_REAL"].blank?
    # Development writes mail to tmp/mails instead of sending it.
    #
    # The credentials on this laptop are the parish's real Google Workspace
    # account, and development used them: creating an organization in the
    # operator console sends an invitation, and an invitation goes to whatever
    # address was typed into the form. Trying the thing out would have put real
    # mail, from the parish, in a stranger's inbox.
    #
    # Written to a file rather than swallowed, because an invitation is only
    # worth anything if somebody can follow the link in it -- open the newest
    # file in tmp/mails and the link is there, which is how to walk through
    # being invited without involving a mail server at all.
    #
    # SMTP_FOR_REAL=1 restores sending, for the day somebody genuinely needs to
    # test delivery.
    config.action_mailer.delivery_method = :file
    config.action_mailer.file_settings = { location: Rails.root.join("tmp/mails") }
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
