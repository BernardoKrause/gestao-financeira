Rails.application.routes.draw do
  authenticate :user, ->(user) { (admin_email = Rails.application.credentials.admin_email).present? && user.email.casecmp?(admin_email) } do
    mount_avo do
      get "overview", to: "tools#overview", as: :overview
    end
  end

  root "hub#index"

  devise_for :users, controllers: { registrations: "users/registrations" }

  scope "/financas" do
    get "/", to: "dashboard#index", as: :dashboard
    get "dashboard_confidence", to: "dashboard#update_view", as: :dashboard_confidence
    resources :categories
    resources :transactions
    resources :recurring_entries
    post "quick_entries", to: "quick_entries#create", as: :quick_entries
  end

  scope "/treinos" do
    resources :exercises

    resources :workout_programs do
      member do
        post :activate
        post :duplicate
      end

      resources :program_days, only: %i[create destroy] do
        collection { patch :reorder }

        resources :program_exercises, only: %i[create update destroy] do
          collection { patch :reorder }
        end
      end
    end

    resource :workout_session, only: %i[new create show destroy] do
      patch :finish
      resources :set_logs, only: %i[create update destroy]
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest_path
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
