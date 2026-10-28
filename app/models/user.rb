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

  # Two different questions, which are easy to confuse because both sound like
  # "how much power":
  #
  #   role              -- what you may do INSIDE an organization.
  #   application_admin -- WHICH organizations you may act in. Everyone's.
  #
  # So an organization's own top administrator is role "superadmin" and is not
  # an application admin; somebody running this app for other people is an
  # application admin and may hold no role anywhere.
  #
  # Deliberately NOT default-scoped to an organization, unlike every other
  # table. Signing in happens before a hostname has been resolved to anybody,
  # and an application admin belongs to no organization at all. Authorisation
  # does that work instead -- see may_act_in?.
  belongs_to :organization, optional: true

  # Optional in the model, and a check constraint in the database: a user has an
  # organization, or is an application admin, or is a row that can see nothing
  # and would be a puzzle to debug.
  #
  # Filled in from the request, so creating an editor from inside an
  # organization's admin does the obvious thing without the form carrying a
  # hidden field somebody could edit.
  before_validation :belong_where_this_was_created, on: :create

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

  # The one authorisation question that matters once there is more than one
  # organization: may this person act on THIS one's data?
  def may_act_in?(organization)
    return false if organization.nil?
    return true  if application_admin?

    organization_id == organization.id
  end

  private

  def belong_where_this_was_created
    return if application_admin?

    self.organization ||= Current.organization
  end

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
