Rails.application.routes.draw do
  root "artists#index"

  # Picking a profile off the grid starts a session; switching profiles ends it.
  resources :profiles, only: [ :index, :create ]
  resource  :session,  only: [ :create, :destroy ]

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
