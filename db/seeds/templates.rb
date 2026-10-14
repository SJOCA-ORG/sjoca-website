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

"block/heading"    => %(<h2 class="b b-heading b--{{ block.align }}">{{ block.content }}</h2>\n),
"block/subheading" => %(<p class="b b-subheading b--{{ block.align }}">{{ block.content }}</p>\n),
"block/text"       => %(<p class="b b-text b--{{ block.align }}">{{ block.content }}</p>\n),
"block/quote"      => %(<blockquote class="b b-quote b--{{ block.align }}">{{ block.content }}</blockquote>\n),

"block/button" => <<~'LIQUID',
  <p class="b b--{{ block.align }}">
    <a class="button" href="{{ block.url }}">{{ block.content }}</a>
  </p>
LIQUID

"block/list" => <<~'LIQUID',
  <ul class="b b-list b--{{ block.align }}">
    {% for item in block.items %}<li>{{ item }}</li>{% endfor %}
  </ul>
LIQUID

"block/image" => <<~'LIQUID',
  {% if block.photo %}
    <figure class="b b-image b--{{ block.align }}"
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

"block/upcoming" => <<~'LIQUID',
  {% if site.upcoming.any %}
    <div class="b b-upcoming"><div class="upcoming">
      <h2 class="upcoming__head">This coming week</h2>
      <ul class="upcoming__list">
        {% for event in site.upcoming.events %}
          <li class="upcoming__item {% if event.cancelled %}is-cancelled{% endif %}">
            <span class="upcoming__when">{{ event.day }}{% if event.time_text %}, {{ event.time_text }}{% endif %}</span>
            <span class="upcoming__title">{{ event.title }}</span>
            {% if event.notes %}<span class="upcoming__note">{{ event.notes }}</span>{% endif %}
          </li>
        {% endfor %}
      </ul>
    </div></div>
  {% endif %}
LIQUID

"block/calendar" => <<~'LIQUID',
  <div class="b b-calendar"><div class="calendar">
    {% unless site.calendar.any %}
      <p class="calendar__empty">
        The calendar is being updated. Please
        <a href="mailto:{{ site.email }}">contact the parish</a> for service times.
      </p>
    {% else %}
      {% for week in site.calendar.weeks %}
        <section class="calendar__week">
          <h3 class="calendar__weekhead">{{ week.heading }}</h3>
          <ol class="calendar__list">
            {% for event in week.events %}
              <li class="calendar__item {% if event.today %}is-today{% endif %} {% if event.noteworthy %}is-special{% endif %} {% if event.cancelled %}is-cancelled{% endif %}">
                <div class="calendar__when">
                  <span class="calendar__day">{{ event.day_short }}</span>
                  <span class="calendar__date">{{ event.date_num }}</span>
                </div>
                <div class="calendar__what">
                  <span class="calendar__title">{{ event.title }}</span>
                  {% if event.time_text %}<span class="calendar__time">{{ event.time_text }}</span>{% endif %}
                  {% if event.elsewhere %}<span class="calendar__place">{{ event.elsewhere }}</span>{% endif %}
                  {% if event.notes %}<span class="calendar__note">{{ event.notes }}</span>{% endif %}
                </div>
              </li>
            {% endfor %}
          </ol>
        </section>
      {% endfor %}
    {% endunless %}
  </div></div>
LIQUID

"block/classes" => <<~'LIQUID',
  {% if site.classes.any %}
    <div class="b b-classes"><div class="classes">
      <ul class="classes__list">
        {% for rec in site.classes.recordings %}
          <li class="classes__item">
            <a class="classes__link" href="{{ rec.watch_url }}" rel="noopener">
              <span class="classes__thumb">
                <img src="{{ rec.thumbnail }}" alt="" loading="lazy">
                <span class="classes__play" aria-hidden="true"></span>
              </span>
              <span class="classes__meta">
                {% if rec.number %}<span class="classes__number">Class {{ rec.number }}</span>{% endif %}
                <span class="classes__title">{{ rec.title }}</span>
                {% if rec.date_text %}<span class="classes__date">{{ rec.date_text }}</span>{% endif %}
              </span>
            </a>
          </li>
        {% endfor %}
      </ul>
      <p class="classes__all">
        <a class="button" href="{{ site.classes.playlist_url }}" rel="noopener">All classes on YouTube</a>
      </p>
    </div></div>
  {% endif %}
LIQUID

"block/lectionary" => <<~'LIQUID',
  <div class="b b-lectionary">
  {% unless site.lectionary.today %}
    <p class="lectionary__empty">
      The readings are being updated. They are always available at
      <a href="https://www.oca.org/readings" rel="noopener">oca.org</a>.
    </p>
  {% else %}
    <div class="lectionary" data-controller="lectionary">
      {% if site.lectionary.icon %}
        <figure class="lectionary__icon">
          <img src="{{ site.lectionary.icon.url }}" alt="{{ site.lectionary.icon.alt }}" loading="lazy">
        </figure>
      {% endif %}

      <header class="lectionary__today">
        <p class="lectionary__date">{{ site.lectionary.today.date_text }}</p>
        {% if site.lectionary.today.commemorations %}
          <p class="lectionary__saints">{{ site.lectionary.today.commemorations }}</p>
        {% endif %}
      </header>

      <div class="lectionary__controls">
        <button type="button" class="verse-toggle" data-action="lectionary#toggle"
                data-lectionary-target="button" aria-pressed="false">
          Show verse numbers
        </button>
      </div>

      {% for reading in site.lectionary.today.appointed %}
        <section class="reading">
          <h2 class="reading__head">
            {% if reading.kind %}<span class="reading__kind">{{ reading.kind }}</span>{% endif %}
            <span class="reading__citation">{{ reading.citation }}</span>
          </h2>
          {% if reading.has_body %}
            <div class="reading__body">
              <div class="reading__numbered">
                {% for v in reading.verses %}
                  <p class="verse"><span class="verse__n">{{ v.number }}</span>{{ v.text }}</p>
                {% endfor %}
              </div>
              <div class="reading__prose">
                {% for para in reading.paragraphs %}<p>{{ para }}</p>{% endfor %}
              </div>
            </div>
          {% endif %}
        </section>
      {% endfor %}

      {% if site.lectionary.has_ahead %}
        <section class="lectionary__ahead">
          <h2 class="lectionary__aheadhead">The week ahead</h2>
          <ol class="lectionary__list">
            {% for day in site.lectionary.ahead %}
              <li>
                <span class="lectionary__day">{{ day.day_name }}</span>
                <span class="lectionary__refs">{{ day.citations }}</span>
              </li>
            {% endfor %}
          </ol>
        </section>
      {% endif %}

    <p class="lectionary__source">
      Readings from the <a href="https://www.oca.org/readings" rel="noopener">Orthodox
      Church in America</a>.
    </p>
    </div>
  {% endunless %}
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
