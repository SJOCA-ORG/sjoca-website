Rails.application.routes.draw do
  # Images carried over from the old site, served from the database.
  # Looked up by human_name, so swapping a photo never changes a URL.
  get "media/:human_name", to: "legacy_assets#show", as: :legacy_asset,
      constraints: { human_name: %r{[a-z0-9\-]+} }

  get "up" => "rails/health#show", as: :rails_health_check

  root "pages#show", defaults: { path: "home" }

  # Page paths mirror the old site exactly ("/about-us/our-story"), so links
  # already out in the world keep working after cutover.
  get "*path", to: "pages#show", as: :page,
      constraints: { path: %r{[a-z0-9\-/]+} }
end
