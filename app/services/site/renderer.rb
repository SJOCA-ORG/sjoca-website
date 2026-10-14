module Site
  # Renders a page from templates stored in the database.
  #
  # Liquid cannot run Ruby, but it can loop itself into a hung request. The
  # resource limits turn that into a clean error rather than a stuck worker.
  class Renderer
    class Error < StandardError; end

    def initialize(revision) = @revision = revision

    def render(name, assigns = {})
      source = Template.source_for(@revision, name) or
        raise Error, "no template #{name.inspect} in revision #{@revision.id}"

      template = Liquid::Template.parse(source)
      out = template.render(assigns.stringify_keys,
                            registers: { file_system: TemplateStore.new(@revision) })

      raise Error, template.errors.map(&:message).uniq.join("; ") if template.errors.any?

      out.html_safe
    rescue Liquid::Error => e
      raise Error, e.message
    end
  end
end
