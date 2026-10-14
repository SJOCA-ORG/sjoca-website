# Every request renders exactly one revision.
#
# Preview is a session flag rather than a URL prefix, so an editor browses the
# site normally -- every link, every nav item, the real thing -- and simply sees
# the draft. A banner makes the state obvious, because a preview you forget you
# are in is worse than no preview at all.
module RevisionScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_revision
    helper_method :previewing?, :preview_revision
  end

  private

  def set_revision
    Current.revision = preview_revision || Revision.live
  end

  def preview_revision
    return nil if session[:preview_revision_id].blank?

    @preview_revision ||= Revision.find_by(id: session[:preview_revision_id])
  end

  def previewing? = preview_revision.present?
end
