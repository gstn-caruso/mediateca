Rails.application.routes.draw do
  root "artists#index"

  # Picking a profile off the grid starts a session; switching profiles ends it.
  resources :profiles, only: [ :index, :create ]
  resource  :session,  only: [ :create, :destroy ]

  get "search", to: "searches#show", as: :search

  # A like is removed by naming what was liked, not by an id nobody has.
  resources :likes, only: [ :index, :create ]
  delete "likes", to: "likes#destroy"

  resources :plays, only: [ :create ]

  resources :playlists, only: [ :show, :create, :update, :destroy ] do
    resources :entries, only: [ :create, :update, :destroy ], controller: "playlist_entries"
  end

  resources :artists, only: [ :index, :show ]

  resources :albums, only: [ :show ] do
    get :cover, on: :member
  end

  resources :tracks, only: [] do
    get :stream, on: :member
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check
end
