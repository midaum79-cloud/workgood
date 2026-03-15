Rails.application.routes.draw do
  get "pages/guide"
  get "announcements", to: "announcements#index", as: :announcements
  get "my_account",    to: "my_account#show",     as: :my_account
  # Auth
  get  "login",  to: "sessions#new",          as: :login
  post "login",  to: "sessions#create"
  delete "logout", to: "sessions#destroy",    as: :logout
  get  "signup", to: "registrations#new",     as: :signup
  post "signup", to: "registrations#create"

  # Password reset
  get  "password_resets/new",        to: "password_resets#new",    as: :new_password_reset
  post "password_resets",            to: "password_resets#create", as: :password_resets
  get  "password_resets/:token/edit", to: "password_resets#edit",  as: :edit_password_reset
  patch "password_resets/:token",    to: "password_resets#update", as: :password_reset

  # OmniAuth (Google)
  get  "/auth/google_oauth2/callback", to: "omniauth_callbacks#google_oauth2"
  post "/auth/google_oauth2/callback", to: "omniauth_callbacks#google_oauth2"
  get  "/auth/failure",                to: "omniauth_callbacks#failure"


  # App Settings
  get  "app_settings",                        to: "app_settings#index",               as: :app_settings
  patch "app_settings/profile",               to: "app_settings#update_profile",      as: :update_profile_app_settings
  patch "app_settings/password",              to: "app_settings#update_password",     as: :update_password_app_settings
  patch "app_settings/notifications",         to: "app_settings#update_notifications",as: :update_notifications_app_settings

  # Subscription
  get   "subscription",        to: "subscriptions#index",  as: :subscription
  patch "subscription",        to: "subscriptions#update"
  get   "subscription/verify", to: "subscriptions#verify", as: :verify_subscription
  delete "subscription",       to: "subscriptions#cancel", as: :cancel_subscription

  # Widget Settings
  get "widget_settings", to: "widget_settings#index", as: :widget_settings

  # Legal
  get "terms",   to: "legal#terms",   as: :terms
  get "privacy", to: "legal#privacy", as: :privacy

  # Notifications
  resources :notifications do
    member do
      post :read
    end
  end

  resources :work_days do
    collection do
      post :toggle
      post :move
    end
  end

  resources :web_push_subscriptions, only: [:create] do
    collection do
      delete :destroy # Use endpoint as param
    end
  end

  resources :work_processes do
    collection do
      post :quick_create
    end
  end
  resources :vendors
  resources :process_templates, only: [:index, :create, :destroy] do
    member do
      post :move_up
      post :move_down
    end
  end
  resources :projects do
    member do
      get :project_calendar, path: 'calendar'
    end
    collection do
      get :calendar
      get :manage
      get :archive
    end
    resources :ai_imports, only: [] do
      collection do
        post :analyze
        post :commit
      end
    end
  end

  resources :ai_imports, only: [] do
    collection do
      post :analyze
    end
  end

  root "projects#index"
end