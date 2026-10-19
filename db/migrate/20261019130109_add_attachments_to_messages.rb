# Photographs attached to what somebody said.
#
# "Replace Fr David's photo with the one I am about to upload" only works if
# the upload and the sentence arrive together. Keeping the names on the message
# means the model reads them as part of the request, rather than having to go
# and guess which photographs are the new ones.
class AddAttachmentsToMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :revision_messages, :attachments, :json
  end
end
