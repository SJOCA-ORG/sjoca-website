# Every request renders exactly one revision.
#
# Preview is normally a session flag, so an editor browses the site normally --
# every link, every nav item, the real thing -- and simply sees the draft.
#
# A SIGNED link is the other way in: ?preview=<token>. It is how the visual
# checks let a headless browser see a draft, and it is what makes a preview
# shareable with someone who is not logged in -- an Approver on their phone, say.
# Signed rather than a bare id, so a draft cannot be read by guessing numbers.
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
    return @preview_revision if defined?(@preview_revision)

    @preview_revision = revision_from_token || revision_from_session
  end

  def revision_from_token
    params[:preview].present? && Revision.from_preview_token(params[:preview])
  end

  def revision_from_session
    return nil if session[:preview_revision_id].blank?

    Revision.find_by(id: session[:preview_revision_id])
  end

  def previewing? = preview_revision.present?
end
