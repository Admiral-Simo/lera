Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Passport routes
  resources :passports, only: [:new, :create, :update, :show] do
    member do
      get :police_report # 🚀 Creates path helper: police_report_passport_path(id)
    end
  end

  # OmniAuth routes
  get "/auth/:provider/callback", to: "oauth_callbacks#create"
  post "/auth/:provider/callback", to: "oauth_callbacks#create"
  get "/auth/failure", to: "oauth_callbacks#failure"

  # Root path
  root "passports#new"
end
