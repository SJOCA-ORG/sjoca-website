# One entry in a revision's list of standing promises.
class RevisionPromise < ApplicationRecord
  belongs_to :revision
  belongs_to :promise
end
