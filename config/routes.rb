Rails.application.routes.draw do
  # Images carried over from the old site, served from the database.
  # Looked up by human_name, so swapping a photo never changes a URL.
  get "media/:human_name(/:version)", to: "photos#show", as: :photo,
      constraints: { human_name: %r{[a-z0-9\-]+}, version: /\d+/ }

  # The site's own CSS and JS, served from the revision being rendered. The
  # digest in the path means these can be cached for a year and still change the
  # instant a revision is published.
  # format: false matters. Without it Rails reads the ".js" as a request format
  # and refuses the response with InvalidCrossOriginRequest -- its guard against
  # leaking data through a <script> tag. These are public assets, not data, but
  # the cleaner fix is not to claim a JS format in the first place.
  get "theme-:digest.css" => "theme#stylesheet", as: :theme_stylesheet,
      constraints: { digest: /[a-f0-9]+/ }, format: false
  get "theme-:digest.js"  => "theme#javascript", as: :theme_javascript,
      constraints: { digest: /[a-f0-9]+/ }, format: false

  get "up" => "rails/health#show", as: :rails_health_check

  root "pages#show", defaults: { path: "home" }

  # Must come before the catch-all below: "*path" matches "manifest" and
  # "service-worker" too, which is why these had never resolved.
  namespace :admin do
    # Signing in is the only part of the admin a stranger may reach.
    get  "login",  to: "sessions#new",     as: :login
    post "login",  to: "sessions#create"
    delete "logout", to: "sessions#destroy", as: :logout

    # Your own account, and the one thing anyone does on it.
    get   "account", to: "account#show",   as: :account
    patch "account", to: "account#update"

    # Getting back in. Open by necessity -- someone locked out cannot sign in
    # first -- so the controller answers the same way to everyone.
    get  "password/new",  to: "passwords#new",    as: :new_password
    post "password",      to: "passwords#create", as: :passwords
    get  "password/edit", to: "passwords#edit",   as: :edit_password
    patch "password",     to: "passwords#update"

    root "revisions#index"
    get "exit-preview" => "revisions#exit_preview", as: :exit_preview
    # Every bulletin, whichever revision it is in, with its PDF and its email.
    resources :bulletins, only: :index

    resources :photos, only: %i[index create update] do
      member { post "describe" }
    end
    resources :tags, only: %i[create destroy]
    resources :revisions, only: %i[index show create destroy] do
      member do
        post "publish"
        post "stop"
        get  "preview"
        get  "status"
      end
      resources :messages, only: :create

      # Editing one block by clicking it in the preview.
      resources :blocks, only: %i[show update] do
        # Several blocks at once, as one piece of prose.
        # One path to the server for anything conversational: the dialog puts
        # its request in the ordinary chat box. This is only the direct save.
        collection { post "rewrite" }
      end

      # Getting a bulletin out: a PDF for the printer, HTML for the mailing
      # list. Both from the same page and the same blocks.
      get "bulletin/pdf",   to: "bulletins#pdf",   as: :bulletin_pdf
      get "bulletin/email", to: "bulletins#email", as: :bulletin_email
    end
  end

  # Generated from the published revision, not kept as a file: a file nobody
  # maintains goes stale, and a sitemap naming pages that no longer exist is
  # worse than none.
  get "sitemap.xml" => "sitemap#show", as: :sitemap, defaults: { format: "xml" }
  get "robots.txt"  => "sitemap#robots", as: :robots

  # Ours, not rails/pwa: that one inherits from ActionController::Base and so
  # never resolves which organization the request is for. See PwaController.
  # The operator console. Guarded twice in Operator::BaseController -- an
  # application admin, on the product organization's own hostname.
  namespace :operator do
    root to: "organizations#index"
    resources :organizations, only: %i[new create] do
      member do
        post :enter
        post :suspend
        post :resume
      end
    end
  end

  get "manifest" => "pwa#manifest", as: :pwa_manifest
  get "service-worker" => "pwa#service_worker", as: :pwa_service_worker

  # Page paths mirror the old site exactly ("/about-us/our-story"), so links
  # already out in the world keep working after cutover.
  get "*path", to: "pages#show", as: :page,
      constraints: { path: %r{[a-z0-9\-/]+} }
end
