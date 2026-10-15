# Liquid renders an unknown property as an empty string and says nothing. A
# template asking for {{ event.date }} when the property is date_num produces a
# page with blank dates, no error, and nothing in any log -- the worst failure
# this system can have, because it looks like missing data rather than a bug.
#
# So: while editing a DRAFT, an unknown property raises and names what is
# actually available. On the published site it stays silent, because a live
# parish website must never 500 over a typo in a template.
class BaseDrop < Liquid::Drop
  def liquid_method_missing(name)
    return nil unless Current.revision&.editable?

    raise Liquid::UndefinedVariable,
          "#{self.class.name.sub('Drop', '').underscore} has no #{name.inspect}. " \
          "It has: #{available.join(', ')}"
  end

  def available
    (self.class.public_instance_methods(false) - [:initialize, :available])
      .reject { |m| m.to_s.end_with?("?") }.map(&:to_s).sort
  end
end
