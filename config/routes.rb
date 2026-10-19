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
    root "revisions#index"
    get "exit-preview" => "revisions#exit_preview", as: :exit_preview
    resources :photos, only: %i[index create update]
    resources :tags, only: %i[create destroy]
    resources :revisions, only: %i[index show create destroy] do
      member do
        post "publish"
        get  "preview"
        get  "status"
      end
      resources :messages, only: :create
    end
  end

  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Page paths mirror the old site exactly ("/about-us/our-story"), so links
  # already out in the world keep working after cutover.
  get "*path", to: "pages#show", as: :page,
      constraints: { path: %r{[a-z0-9\-/]+} }
end
