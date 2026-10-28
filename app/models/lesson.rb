# Something the admin AI worked out, kept so it does not have to work it out
# again. See db/migrate/.../create_lessons.rb for why these live in the database
# while the reviewed rules live in code.
class Lesson < ApplicationRecord
  include BelongsToOrganization
  # Subjects were a closed list in Ruby, which meant the AI could not keep a
  # lesson about anything nobody had thought of -- a bulletin, say, or whatever
  # a different parish turns out to care about. The point of this table is
  # knowledge nobody anticipated.
  #
  # These are suggestions, offered so that lessons cluster rather than sprawl.
  SUGGESTED = %w[liquid styles photos content house-style].freeze

  validates :subject, presence: true, format: {
    with: /\A[a-z][a-z0-9-]{0,30}\z/,
    message: "is lower case letters, numbers and hyphens"
  }
  validates :body, presence: true, length: { minimum: 10, maximum: 2000 }
  # organization_id is in the scope deliberately: Rails' uniqueness validator
  # calls klass.unscoped and never sees the default_scope. Without it, one
  # organization recording a lesson would be refused because another had
  # already written the same sentence.
  validates :body, uniqueness: { scope: %i[organization_id subject], case_sensitive: false }

  scope :active, -> { where(active: true).order(:subject, :created_at) }

  def self.for_guide = active.map { |l| { subject: l.subject, lesson: l.body } }
end
