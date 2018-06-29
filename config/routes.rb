# frozen_string_literal: true

Rails.application.routes.draw do
  resources :memos
  devise_for :users
  get 'pages/about', as: :about
  root to: 'memos#index'
  mount LetterOpenerWeb::Engine, at: '/letter_opener' if Rails.env.development?
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
