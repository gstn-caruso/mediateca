Rails.application.routes.draw do
  root "artists#index"

  # Picking a profile off the grid starts a session; switching profiles ends it.
  resources :profiles, only: [ :index, :create ]
  resource  :session,  only: [ :create, :destroy ]

  resource :search, only: [ :show ]

  # The liked-songs page is a collection; a like itself is a singular resource
  # of whatever was liked, so it is named by its owner, not by an id nobody has.
  resources :likes, only: [ :index ]

  resources :plays, only: [ :create ]

  # What is on right now. A play is written down once the song has been listened
  # to; this is told the moment it starts, because it is what puts the song on a
  # listener's Last.fm page while it is still playing.
  resource :now_playing, only: [ :create ]

  # A listener's Last.fm. Connecting it is a journey out to Last.fm and back, and
  # both legs are GETs: the way back is Last.fm's own redirect, not a form anybody
  # posted. Singular, because nobody scrobbles to two accounts at once.
  resource :scrobbler, only: [ :destroy ] do
    get :connect
    get :callback
  end

  resources :playlists, only: [ :show, :create, :update, :destroy ] do
    resources :entries, only: [ :create, :update, :destroy ], controller: "playlist_entries"
  end

  resources :artists, only: [ :index, :show ] do
    resource :portrait, only: [ :show ]
    # Where the listener stands on them: out of sight, or out in front. Singular,
    # because nobody holds two opinions of the same artist at once.
    resource :standing, only: [ :create, :destroy ]
  end

  resources :albums, only: [ :show ] do
    resource :cover, only: [ :show ]
    resource :like,  only: [ :create, :destroy ]
  end

  resources :tracks, only: [] do
    resource :stream, only: [ :show ]
    resource :like,   only: [ :create, :destroy ]
    # What to play when this one is the last thing in the queue.
    resource :suggestions, only: [ :show ]
    # The words, and when each one is sung.
    resource :lyrics, only: [ :show ]
  end

  # Which build is answering, for a tab coming back from a deploy.
  get "build" => "builds#show"

  # Where a tab becomes an app. The worker is served from the root on purpose: a
  # worker only speaks for the pages beneath the path it came from, and this one
  # has to speak for all of them.
  get "manifest.json"     => "pwa#manifest",       as: :pwa_manifest
  get "service-worker.js" => "pwa#service_worker", as: :pwa_service_worker

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check
end
