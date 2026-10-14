module Site
  # Liquid's hook for resolving {% render 'name' %}. Normally it reads files off
  # disk; this reads rows, which is what lets templates be edited and versioned
  # like any other content.
  class TemplateStore
    # Must subclass Liquid::FileSystemError, or Liquid swallows the exception
    # and reports "Liquid error: internal" -- which tells an editor who has just
    # broken a template precisely nothing.
    class MissingTemplate < Liquid::FileSystemError; end

    def initialize(revision) = @revision = revision

    def read_template_file(name)
      Template.source_for(@revision, name.to_s) ||
        raise(MissingTemplate, "there is no template called #{name.inspect}")
    end
  end
end
