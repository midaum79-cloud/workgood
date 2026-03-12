Rails.application.routes.draw do
  # Auth
  get  "login",  to: "sessions#new",          as: :login
  post "login",  to: "sessions#create"
  delete "logout", to: "sessions#destroy",    as: :logout
  get  "signup", to: "registrations#new",     as: :signup
  post "signup", to: "registrations#create"

  # App Settings
  get  "app_settings",                        to: "app_settings#index",               as: :app_settings
  patch "app_settings/profile",               to: "app_settings#update_profile",      as: :update_profile_app_settings
  patch "app_settings/password",              to: "app_settings#update_password",     as: :update_password_app_settings
  patch "app_settings/notifications",         to: "app_settings#update_notifications",as: :update_notifications_app_settings

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