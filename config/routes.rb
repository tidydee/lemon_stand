Rails.application.routes.draw do
  post '/shopify', to: 'shopify#create'
  get '/shopify', to: 'shopify#show'
  root to: 'shopify#index'
end
