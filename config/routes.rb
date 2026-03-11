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
  resources :projects

  root "projects#index"
end