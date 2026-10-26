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

  # At least eight, with an upper case letter, a lower case letter, and a number
  # or a symbol. Mitch's call, 26 October 2026.
  MIN_LENGTH = 8

  validates :password, length: { minimum: MIN_LENGTH }, if: -> { password.present? }
  validate :password_has_a_mix, if: -> { password.present? }

  # A reset link that expires, that only works once, and that needs no table of
  # its own. The token is signed and carries the password digest, so changing
  # the password invalidates every link already sent -- including the one the
  # person just used, and any a thief is sitting on.
  generates_token_for :password_reset, expires_in: 2.hours do
    password_salt&.last(10)
  end

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

  private

  def password_has_a_mix
    missing = []
    missing << "an upper case letter" unless password.match?(/[A-Z]/)
    missing << "a lower case letter"  unless password.match?(/[a-z]/)
    missing << "a number or a symbol" unless password.match?(/[\d\W_]/)
    return if missing.empty?

    errors.add(:password, "still needs #{missing.to_sentence}")
  end

  public
  def display_name = name.presence || email
end
