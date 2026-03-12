Rails.application.routes.draw do
  # Auth
  get  "login",  to: "sessions#new",          as: :login
  post "login",  to: "sessions#create"
  delete "logout", to: "sessions#destroy",    as: :logout
  get  "signup", to: "registrations#new",     as: :signup
  post "signup", to: "registrations#create"

  # Subscription
  resource :subscription, only: [:index, :update]

  # Widget Settings
  get "widget_settings", to: "widget_settings#index", as: :widget_settings

  # Notifications
  resources :notifications do
    member do
      post :read
    end
  end

  resources :work_days do
    collection do
      post :toggle
    end
  end

  resources :work_processes
  resources :vendors
  resources :process_templates, only: [:index, :create, :destroy] do
    member do
      post :move_up
      post :move_down
    end
  end
  resources :projects do
    collection do
      get :calendar
      get :manage
    end
  end

  root "projects#index"
end