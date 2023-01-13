Rails.application.routes.draw do
  get '/:any', action: 'index', controller: 'shop', constraint: { any: /(.*)?/ }
  post 'api/store/create', action: 'create', controller: 'store'
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  # root "articles#index"
end
