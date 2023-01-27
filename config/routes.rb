Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html

  resources :memos
  devise_for :users
  get "pages/about", as: :about
  root to: "memos#index"
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?
end
