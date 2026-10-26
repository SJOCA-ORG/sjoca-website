require "io/console"

namespace :admin do
  desc "Create or reset an editor's password: bin/rails admin:user EMAIL=itmanager@sjoca.org"
  task user: :environment do
    email = ENV["EMAIL"].presence or abort("EMAIL is required, e.g. EMAIL=itmanager@sjoca.org")

    # From the environment on a server, typed by hand on a laptop. Never from a
    # command-line argument: those end up in shell history and in process lists
    # where anyone on the machine can read them.
    password = ENV["PASSWORD"].presence || begin
      print "Password (at least 12 characters, not shown): "
      first = $stdin.noecho(&:gets).to_s.chomp
      puts
      print "Again: "
      again = $stdin.noecho(&:gets).to_s.chomp
      puts
      abort("Those did not match.") unless first == again
      first
    end

    user = User.find_or_initialize_by(email: email.strip.downcase)
    existing = user.persisted?
    user.password = password
    user.role ||= "superadmin"

    if user.save
      puts existing ? "Password changed for #{user.email}." : "Created #{user.email} (#{user.role})."
    else
      abort("Could not save: #{user.errors.full_messages.to_sentence}")
    end
  end

  desc "List who can sign in"
  task users: :environment do
    if User.none?
      puts "Nobody yet. Create one with: bin/rails admin:user EMAIL=..."
    else
      User.order(:email).each do |u|
        last = u.last_signed_in_at ? u.last_signed_in_at.strftime("%-d %b %Y, %H:%M") : "never"
        puts format("  %-34s %-12s last signed in: %s", u.email, u.role, last)
      end
    end
  end
end
