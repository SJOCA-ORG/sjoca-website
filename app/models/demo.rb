# The demo switch.
#
# Showing this to a room is not the same as using it. Two things that are
# right in daily use are wrong in front of a meeting:
#
#   * the running cost, which is interesting to us and a distraction to them;
#   * the standing-promise checks, which drive a real browser over the site and
#     take long enough that everyone watches us wait.
#
# Promises are still LISTED in demo mode -- the point is to show that the site
# holds itself to them. They are simply not executed, and anything that would
# have reported a result says plainly that checking is paused, because a check
# that silently passes without running is a lie told to the person relying on it.
#
# A file rather than only an environment variable, so it can be turned on and
# off during a meeting without restarting the server:
#
#   touch tmp/demo_mode-development     # on
#   rm    tmp/demo_mode-development      # off
#
# Named for the environment, because it is a real file and the test suite
# shares the filesystem with the running server. A spec that turned the switch
# off at the end of an example turned it off for the person about to present.
module Demo
  def self.flag = Rails.root.join("tmp", "demo_mode-#{Rails.env}")

  def self.on?
    ENV["SJOCA_DEMO"] == "1" || flag.exist?
  end

  def self.on!  = FileUtils.touch(flag)
  def self.off! = FileUtils.rm_f(flag)
end
