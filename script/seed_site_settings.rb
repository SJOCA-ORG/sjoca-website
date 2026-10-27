# Move the parish's own facts out of Ruby and into each revision.
VALUES = {
  "name" => "Saint John the Baptist Orthodox Church",
  "short_name" => "St John the Baptist Orthodox Church",
  "address" => "855 S. Goodman St. Rochester, NY 14620",
  "email" => "fr.david@sjoca.org",
  "city" => "Rochester",
  "region" => "NY"
}.freeze

Revision.where.not(state: "discarded").find_each do |rev|
  added = VALUES.count { |k, v| rev.site_settings.find_or_create_by!(key: k) { |s| s.value = v }.previously_new_record? }
  puts "  revision #{rev.id} (#{rev.state}): #{added} settings" if added.positive?
end
puts "done"
