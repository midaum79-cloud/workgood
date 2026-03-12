Rails.application.routes.draw do
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