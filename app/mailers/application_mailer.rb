class ApplicationMailer < ActionMailer::Base
  default from: "from@example.com"
  layout "mailer"

  # Which hostname the links in an email point at.
  #
  # config/initializers/mail.rb sets this once at boot, from SITE_URL, which was
  # right while one organization ran per deployment. It is not right now: a
  # password reset for one organization would carry another's address, and a
  # link to the wrong host is a link that does not work -- or worse, one that
  # does, and shows somebody else's sign-in page.
  #
  # So the host is decided per message, from the organization the request is
  # for. The boot-time setting stays as the fallback, for mail sent from a rake
  # task or a job where no request resolved an organization.
  def url_options
    uri = URI.parse(Organization.current_url)
    { host: uri.host, port: uri.port, protocol: uri.scheme }.compact
  end
end
