# The site's Liquid templates. Seeded into a revision; thereafter the parish
# edits them through the admin and they version like any other content.
#
# Every one of these was ported from the ERB it replaces, and the rendered HTML
# is byte-identical -- see spec/services/site/renderer_spec.rb.
module DefaultTemplates
  TEMPLATES = {

"header" => <<~'LIQUID',
  <header class="site-header" data-controller="nav">
    <div class="site-header__inner">
      <a class="site-header__brand" href="/">SJTB</a>

      <button class="site-header__toggle" type="button"
              aria-label="Menu" aria-expanded="false" data-action="nav#toggle">
        <span></span><span></span><span></span>
      </button>

      <nav class="site-nav" data-nav-target="menu" aria-label="Main">
        <ul class="site-nav__list">
          {% for item in nav %}
            <li class="site-nav__item {% if item.has_children %}has-children{% endif %}">
              <a href="{{ item.path }}"
                 class="site-nav__link {% if item.current %}is-current{% endif %}"
                 {% if item.current %}aria-current="page"{% endif %}>
                {{ item.title }}
                {% if item.has_children %}
                  <span class="site-nav__caret" aria-hidden="true"
                        data-action="click->nav#expand"></span>
                {% endif %}
              </a>
              {% if item.has_children %}
                <ul class="site-nav__sub">
                  {% if item.self_title %}
                    <li>
                      <a href="{{ item.path }}"
                         class="{% if item.current %}is-current{% endif %}">{{ item.self_title }}</a>
                    </li>
                  {% endif %}
                  {% for kid in item.children %}
                    <li>
                      <a href="{{ kid.path }}"
                         class="{% if kid.current %}is-current{% endif %}">{{ kid.title }}</a>
                    </li>
                  {% endfor %}
                </ul>
              {% endif %}
            </li>
          {% endfor %}
        </ul>
      </nav>
    </div>
  </header>
LIQUID

"footer" => <<~'LIQUID',
  <footer class="site-footer">
    <div class="site-footer__inner">
      <p class="site-footer__name">{{ site.name }}</p>
      <div class="site-footer__contact">
        <p>Address: {{ site.address }}</p>
        <p>Email: <a href="mailto:{{ site.email }}">{{ site.email }}</a></p>
      </div>
    </div>
  </footer>
LIQUID

"page" => <<~'LIQUID',
  {% if page.has_hero %}
    <section class="hero {% if page.hero_tall %}hero--tall{% endif %}"
             {% if page.hero_photo %}style="background-image:url({{ page.hero_photo.url }})"{% endif %}>
      <div class="hero__inner">
        {% if page.hero_heading %}<h1 class="hero__title">{{ page.hero_heading }}</h1>{% endif %}
        {% if page.hero_subheading %}<p class="hero__subtitle">{{ page.hero_subheading }}</p>{% endif %}
        {% if page.hero_detail %}<p class="hero__detail">{{ page.hero_detail }}</p>{% endif %}
      </div>
    </section>
  {% endif %}

  {% for section in page.sections %}
    {% include 'section' %}
  {% endfor %}
LIQUID

"section" => <<~'LIQUID',
  <section class="band band--{{ section.style }}">
    <div class="band__inner">
      <div class="cols" style="--tracks: {{ section.grid_template }}">
        {% for column in section.columns %}
          <div class="col">
            {% for block in column %}{% include block.template %}{% endfor %}
          </div>
        {% endfor %}
      </div>
    </div>
  </section>
LIQUID

"block/heading"    => %(<h2 class="b b-heading b--{{ block.align }} {{ block.css_class }}">{{ block.content }}</h2>\n),
"block/subheading" => %(<p class="b b-subheading b--{{ block.align }} {{ block.css_class }}">{{ block.content }}</p>\n),
"block/text"       => %(<p class="b b-text b--{{ block.align }} {{ block.css_class }}">{{ block.content }}</p>\n),
"block/quote"      => %(<blockquote class="b b-quote b--{{ block.align }} {{ block.css_class }}">{{ block.content }}</blockquote>\n),

"block/button" => <<~'LIQUID',
  <p class="b b--{{ block.align }} {{ block.css_class }}">
    <a class="button" href="{{ block.url }}">{{ block.content }}</a>
  </p>
LIQUID

"block/list" => <<~'LIQUID',
  <ul class="b b-list b--{{ block.align }} {{ block.css_class }}">
    {% for item in block.items %}<li>{{ item }}</li>{% endfor %}
  </ul>
LIQUID

"block/image" => <<~'LIQUID',
  {% if block.photo %}
    <figure class="b b-image b--{{ block.align }} {{ block.css_class }}"
            {% if block.width %}style="max-width:{{ block.width }}px"{% endif %}>
      {% if block.url %}<a href="{{ block.url }}">{% endif %}
        <img src="{{ block.photo.url }}" alt="{{ block.photo.alt }}" loading="lazy">
      {% if block.url %}</a>{% endif %}
    </figure>
  {% endif %}
LIQUID

"block/embed" => <<~'LIQUID',
  <div class="b b-embed {% if block.is_map %}b-embed--map{% else %}b-embed--video{% endif %}"
       {% if block.is_map %}data-controller="embed" data-action="click->embed#activate"{% endif %}>
    <iframe src="{{ block.url }}"
            title="{% if block.is_map %}Map of the parish{% else %}Adult education class recordings{% endif %}"
            loading="lazy" referrerpolicy="no-referrer-when-downgrade"
            {% unless block.is_map %}allowfullscreen{% endunless %}></iframe>
  </div>
LIQUID





  }.freeze

  def self.install!(revision)
    TEMPLATES.each do |name, source|
      t = revision.templates.find_or_initialize_by(name: name)
      t.update!(source: source)
    end
    TEMPLATES.size
  end
end
