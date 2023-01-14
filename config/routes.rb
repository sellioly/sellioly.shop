Rails.application.routes.draw do
  get '/collections/:collection', action: 'collection', controller: 'shop'
  get '/products/:product', action: 'product', controller: 'shop'
  get '/files/1/assets/:filename', action: 'file_assets', controller: 'shop'
  post 'api/store/create', action: 'create', controller: 'store'
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  # root "articles#index"
  get '/', action: 'index', controller: 'shop'
  get '/*path', action: 'page', controller: 'shop'
end
