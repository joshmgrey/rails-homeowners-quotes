Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  resources :quotes, only: %i[create show] do
    post :bind, on: :member
  end

  resources :policies, only: %i[index show] do
    post :cancel, on: :member
  end
end
