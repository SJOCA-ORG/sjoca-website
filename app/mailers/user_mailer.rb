class UserMailer < ApplicationMailer
  # From the parish's own address, not a no-reply: the one message this system
  # sends is "here is how to get back in", and the person most likely to reply
  # is someone who is stuck.
  default from: %("Saint John the Baptist" <itmanager@sjoca.org>),
          reply_to: "itmanager@sjoca.org"

  def password_reset(user, token)
    @user = user
    @url = admin_edit_password_url(token: token)
    mail to: user.email, subject: "Setting a new password for the parish website"
  end
end
