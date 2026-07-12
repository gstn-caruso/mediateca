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

  resources :playlists, only: [ :show, :create, :update, :destroy ] do
    resources :entries, only: [ :create, :update, :destroy ], controller: "playlist_entries"
  end

  resources :artists, only: [ :index, :show ] do
    resource :portrait, only: [ :show ]
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
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check
end
