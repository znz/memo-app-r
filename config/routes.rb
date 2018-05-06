# frozen_string_literal: true

Rails.application.routes.draw do
  devise_for :users
  get 'static_pages/about', as: :about
  root to: 'static_pages#home'
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
