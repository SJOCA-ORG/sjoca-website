# Something the admin AI worked out, kept so it does not have to work it out
# again. See db/migrate/.../create_lessons.rb for why these live in the database
# while the reviewed rules live in code.
class Lesson < ApplicationRecord
  SUBJECTS = %w[liquid styles photos content house-style].freeze

  validates :subject, presence: true, inclusion: { in: SUBJECTS }
  validates :body, presence: true, length: { minimum: 10, maximum: 2000 }
  validates :body, uniqueness: { scope: :subject, case_sensitive: false }

  scope :active, -> { where(active: true).order(:subject, :created_at) }

  def self.for_guide = active.map { |l| { subject: l.subject, lesson: l.body } }
end
