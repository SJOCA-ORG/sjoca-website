# Someone allowed to edit the site.
#
# One account today -- Mitch -- but a model rather than a password in an
# environment variable, because the point of this project is that parish members
# eventually edit the site themselves, and a shared secret is something we would
# have to throw away to get there.
#
# The password is never stored. bcrypt keeps a one-way digest, so a copy of this
# database -- a backup, a dump pulled down for local work -- does not hand anyone
# the ability to sign in.
class User < ApplicationRecord
  has_secure_password

  ROLES = %w[superadmin].freeze

  normalizes :email, with: ->(e) { e.to_s.strip.downcase }

  validates :email, presence: true, format: { with: /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/,
                                              message: "does not look like an address" }
  validates :role, inclusion: { in: ROLES }

  # Long rather than complicated. A passphrase someone can actually remember
  # beats eight characters of punctuation they write on a sticky note.
  validates :password, length: { minimum: 12 },
                       if: -> { password.present? }

  def self.authenticate(email, password)
    # find_by on the normalised column, so "ItManager@SJOCA.org" works.
    user = find_by(email: email.to_s.strip.downcase)

    # Run the hash even when there is no such user, so a wrong address and a
    # wrong password take the same time to answer. Otherwise the difference
    # tells an attacker which addresses exist.
    return BCrypt::Password.create("absent").is_password?("timing") && nil if user.nil?

    user.authenticate(password) || nil
  end

  def superadmin? = role == "superadmin"
  def display_name = name.presence || email
end
