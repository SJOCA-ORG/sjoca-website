class UserMailer < ApplicationMailer
  # Not a no-reply: the one message this system sends is "here is how to get
  # back in", and the person most likely to reply is someone who is stuck.
  #
  # The organization is an ARGUMENT, and that is the whole point of this method's
  # shape. It used to read Current.organization, which is set from the request's
  # hostname -- and this mail is sent with deliver_later, so it is rendered in a
  # worker process where there is no request and nothing is current. With one
  # organization that went unnoticed, because Current.organization finds the only
  # one by itself. With two, every reset email said "This site" and linked to
  # whatever SITE_URL was, which is to say the link did not work.
  #
  # So the mailer sets the organization itself, for the duration of rendering.
  # mail() renders the templates, so the block has to contain it.
  def password_reset(user, token, organization: nil)
    org = organization || user.organization || Organization.the_product

    Organization.acting_as(org) do
      @user = user
      @site = SiteDrop.new(Revision.live)
      @url = admin_edit_password_url(token: token)

      sender = ENV["SMTP_FROM"].presence ||
               Rails.application.credentials.dig(:smtp, :user_name).presence ||
               "no-reply@localhost"

      # The website's public address first -- it is the one a member recognises.
      # Then the ACCOUNT contact, who is a person who can act. Only then the
      # envelope sender, which may be a mailbox nobody reads.
      reply_to = @site.email.presence || org&.contact_email.presence || sender
      reply_name = @site.email.presence ? @site.name : (org&.contact_name.presence || @site.name)

      mail to: user.email,
           from: %("#{@site.name}" <#{sender}>),
           reply_to: %("#{reply_name}" <#{reply_to}>),
           subject: "Setting a new password for #{@site.name}"
    end
  end
end
