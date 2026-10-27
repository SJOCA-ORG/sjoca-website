class UserMailer < ApplicationMailer
  # Not a no-reply: the one message this system sends is "here is how to get
  # back in", and the person most likely to reply is someone who is stuck.
  #
  # The name and the reply address come from the site's own settings, so a
  # second parish does not send mail signed with this one's name. SMTP_FROM
  # overrides the envelope sender for a host that insists on its own.
  def password_reset(user, token)
    @user = user
    @site = SiteDrop.new(Revision.live)
    @url = admin_edit_password_url(token: token)

    sender = ENV["SMTP_FROM"].presence ||
             Rails.application.credentials.dig(:smtp, :user_name).presence ||
             "no-reply@localhost"

    mail to: user.email,
         from: %("#{@site.name}" <#{sender}>),
         reply_to: @site.email.presence || sender,
         subject: "Setting a new password for #{@site.name}"
  end
end
