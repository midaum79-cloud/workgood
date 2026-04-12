Rails.application.routes.draw do
  get "pages/guide"
  get  "daily_memos",        to: "daily_memos#index",  as: :daily_memos_list
  get  "daily_memos/panel",  to: "daily_memos#panel",  as: :daily_memos_panel
  get  "daily_memos/show",   to: "daily_memos#show",   as: :daily_memo
  post "daily_memos/update", to: "daily_memos#update",  as: :update_daily_memo
  get "announcements", to: "announcements#index", as: :announcements
  get "my_account",    to: "my_account#show",     as: :my_account
  get "my_account/documents", to: "my_account#documents", as: :my_account_documents
  patch "my_account/documents", to: "my_account#update_documents", as: :update_my_account_documents
  delete "my_account/documents/:type", to: "my_account#delete_document", as: :delete_my_account_document
  get "/d/:token", to: "shared_documents#show", as: :shared_document

  # 프리미엄: 세금 관리
  get  "tax_report",          to: "tax_reports#index",  as: :tax_report
  get  "tax_report/download", to: "tax_reports#download", as: :download_tax_report
  get  "tax_report/daily_worker_tax", to: "tax_reports#daily_worker_tax", as: :daily_worker_tax
  post "tax_report/send_payment_request", to: "tax_reports#send_payment_request", as: :send_payment_request
  # Auth
  get  "login",  to: "sessions#new",          as: :login
  post "login",  to: "sessions#create"
  delete "logout", to: "sessions#destroy",    as: :logout
  get  "signup", to: "registrations#new",     as: :signup
  post "signup", to: "registrations#create"
  delete "account", to: "registrations#destroy", as: :delete_account

  # Password reset
  get  "password_resets/new",        to: "password_resets#new",    as: :new_password_reset
  post "password_resets",            to: "password_resets#create", as: :password_resets
  get  "password_resets/:token/edit", to: "password_resets#edit",  as: :edit_password_reset
  patch "password_resets/:token",    to: "password_resets#update", as: :password_reset
  get  "password_resets/phone",       to: "password_resets#phone",  as: :phone_password_reset
  post "password_resets/phone_reset", to: "password_resets#phone_reset", as: :phone_password_reset_action

  # OmniAuth (Google)
  get  "/auth/google_oauth2/callback", to: "omniauth_callbacks#google_oauth2"
  post "/auth/google_oauth2/callback", to: "omniauth_callbacks#google_oauth2"
  # Apple Auth - custom direct implementation (NOT under /auth/ to avoid OmniAuth middleware interception)
  get  "/apple_auth",          to: "apple_auth#redirect"
  post "/apple_auth/callback", to: "apple_auth#callback"
  get  "/apple_auth/callback", to: "apple_auth#callback"
  get  "/auth/failure",                to: "omniauth_callbacks#failure"
  get  "/auth/token_login",            to: "omniauth_callbacks#token_login"
  get  "/auth/check_login",            to: "omniauth_callbacks#check_login"
  # Native Apple Sign-In (iOS 앱 네이티브 모달)
  post "/auth/native_apple",           to: "native_apple_auth#create"


  # App Settings
  get  "app_settings",                        to: "app_settings#index",               as: :app_settings
  patch "app_settings/profile",               to: "app_settings#update_profile",      as: :update_profile_app_settings
  patch "app_settings/password",              to: "app_settings#update_password",     as: :update_password_app_settings
  patch "app_settings/notifications",         to: "app_settings#update_notifications", as: :update_notifications_app_settings

  # Subscription
  get   "subscription",        to: "subscriptions#index",  as: :subscription
  patch "subscription",        to: "subscriptions#update"
  get   "subscription/verify_mobile", to: "subscriptions#verify_mobile", as: :verify_mobile_subscription
  delete "subscription",       to: "subscriptions#cancel", as: :cancel_subscription

  resources :receipts, only: [:index, :new, :create, :destroy] do
    collection do
      post :analyze
    end
  end
  # Widget Settings
  get "widget_settings", to: "widget_settings#index", as: :widget_settings

  # Legal
  get "terms",   to: "legal#terms",   as: :terms
  get "privacy", to: "legal#privacy", as: :privacy
  get "guide",   to: "legal#guide",   as: :guide

  # Notifications
  resources :notifications do
    collection do
      patch :update_settings
    end
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

  resources :web_push_subscriptions, only: [ :create ] do
    collection do
      delete :destroy # Use endpoint as param
    end
  end

  resources :work_processes
  resources :vendors do
    collection do
      get :search
    end
  end
  resources :process_templates, only: [ :index, :create, :destroy ] do
    member do
      post :move_up
      post :move_down
    end
  end
  resources :projects do
    member do
      get :project_calendar, path: "calendar"
      get :project_calendar_panel, path: "calendar_panel"
      delete :purge_photo
      patch :update_payment
      post :add_photos
    end
    collection do
      get :calendar
      get :calendar_panel
      get :manage
      get :archive
      get :monthly_payments
      post :move_schedule
      post :toggle_schedule
      post :quick_create
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

  # Widget API
  namespace :api do
    post "widget/token", to: "widget#token"
    get "widget/schedule", to: "widget#schedule"
    get "widget/calendar", to: "widget#calendar"
  end

  root "projects#calendar"
end
