module Admin
  class RevisionsController < BaseController
    before_action :load_revision, only: %i[show publish preview destroy status stop]

    def index
      @live   = Revision.live
      @drafts = Revision.drafts
      @history = Revision.where(state: "superseded").order(published_at: :desc).limit(10)
    end

    # The chat.
    def show
      @messages = @revision.messages
      @working  = @messages.find { |m| m.state == "working" }
    end

    # Polled by the chat page while a turn is in flight. A meta refresh in the
    # body is not reliably honoured, which left the page looking dead for the
    # eighty seconds a turn can take.
    def status
      working = @revision.messages.where(state: %w[working stopping]).first

      # A turn with no steps after a minute is not thinking, it is waiting --
      # usually behind another turn, occasionally behind a lock whose holder
      # has gone. Either way the page should say so rather than animating.
      stalled = working.present? && Array(working.progress).empty? &&
                working.created_at < 60.seconds.ago

      render json: {
        working: working.present?,
        stopping: working&.stopping? || false,
        stalled: stalled,
        queued_behind: stalled ? @revision.messages.where(state: "working").where("id < ?", working.id).count : 0,
        since: working&.created_at&.to_i,
        steps: Array(working&.progress).map { |t|
          if t["say"]
            { text: t["say"], kind: "say" }
          else
            { text: t["summary"].presence || t["name"],
              kind: t["failed"] ? "failed" : (t["read"] ? "read" : "change") }
          end
        },
        usage: working&.usage
      }
    end

    # Stop. Two halves, because a turn can be running OR waiting.
    #
    # The one in flight is asked to stop and does so at its next step: killing
    # it mid-tool-call would leave the draft half-changed with nothing written
    # down about it. Anything merely queued never starts at all.
    def stop
      running = @revision.messages.where(state: "working")
      running.update_all(state: "stopping")

      # A queued turn has a placeholder of its own; discard the job and close
      # the placeholder, or the page waits for something that will never run.
      #
      # discard, not destroy. Destroying the row leaves SolidQueue's semaphore
      # held -- the concurrency limit is a counter released when a job FINISHES,
      # and a row deleted underneath it never finishes. The next request then
      # sits blocked behind a lock nothing holds, for the twenty minutes until
      # it expires, showing "Working..." the whole time. That is exactly what
      # happened: 256 seconds of silence waiting on a semaphore at value 0.
      SolidQueue::Job.where(finished_at: nil, class_name: "EditingTurnJob")
                     .select { |j| Array(j.arguments&.dig("arguments")).first == @revision.id }
                     .each { |j| j.discard rescue j.destroy }

      # Whatever is left holding the lock for this revision is stale by
      # definition: everything running or queued for it has just been stopped.
      release_concurrency_lock

      redirect_to admin_revision_path(@revision),
                  notice: running.any? ? "Stopping — it will finish the step it is on." :
                                         "Nothing was running."
    end

    def create
      revision = Revision.open_sandbox(created_by: "Dn Mitch")
      redirect_to admin_revision_path(revision)
    end

    def publish
      @revision.publish!
      session.delete(:preview_revision_id)
      redirect_to admin_revisions_path, notice: "Published. The site is live on this revision."
    end

    # Browse the real site, rendered from this revision.
    def preview
      session[:preview_revision_id] = @revision.id
      redirect_to root_path
    end

    def exit_preview
      session.delete(:preview_revision_id)
      redirect_to admin_revisions_path
    end

    def destroy
      @revision.destroy!
      session.delete(:preview_revision_id)
      redirect_to admin_revisions_path, notice: "Draft discarded."
    end

    private

    # Belt and braces. A lock whose holder was stopped, killed or restarted out
    # of existence must not keep the next request waiting.
    def release_concurrency_lock
      SolidQueue::Semaphore.where(key: "EditingTurnJob/editing-revision-#{@revision.id}").destroy_all
    rescue StandardError => e
      Rails.logger.warn("could not release the editing lock: #{e.message}")
    end

    def load_revision = @revision = Revision.find(params[:id])
  end
end
