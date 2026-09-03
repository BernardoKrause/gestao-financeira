Rails.application.routes.draw do
  root "dashboard#index"

  devise_for :users, controllers: { registrations: "users/registrations" }
  resources :categories
  resources :transactions
  resources :recurring_entries
  post "quick_entries", to: "quick_entries#create", as: :quick_entries
  get "dashboard_confidence", to: "dashboard#update_view", as: :dashboard_confidence
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest_path
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
