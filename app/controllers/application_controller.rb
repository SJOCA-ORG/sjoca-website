class ApplicationController < ActionController::Base
  # There is deliberately no allow_browser here.
  #
  # Rails 8 scaffolds `allow_browser versions: :modern`, which is
  # { safari: 17.2, chrome: 120, firefox: 121, opera: 106 } and answers anything
  # older with 406 and "Your browser is not supported". It shipped with this app
  # in October 2026 and nobody had chosen it.
  #
  # Safari 17.2 is December 2023. An iPhone 8 or X cannot run iOS 17 AT ALL, so
  # for those parishioners the website was not slow or ugly, it was unreachable.
  # Found on 9 November 2026, hours after cutover, and only because a headless
  # browser taking a phone screenshot identified itself as Safari 17.0.
  #
  # Nothing here needs it. Photographs are served as JPEG, not webp. There is no
  # web push and no badges. Import maps are used, and Safari has had them since
  # 16.4. The theme CSS uses :has() once, supported since 15.4. The true floor is
  # somewhere around Safari 15, and the page degrades rather than breaking.
  #
  # A version number would have been the tidier fix and the wrong one: any number
  # is a guess that goes stale silently. Nobody reports a site that told them to
  # upgrade their phone -- they just do not come back.

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes
end
