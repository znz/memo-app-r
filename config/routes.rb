Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", :as => :rails_health_check

  resources :memos
  devise_for :users
  get "pages/about", as: :about
  root to: "memos#index"
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

  get "stats/gc"
  get "stats/yjit"
end
