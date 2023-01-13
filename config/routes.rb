Rails.application.routes.draw do
  get '/files/1/assets/:filename', action: 'file_assets', controller: 'shop', constraint: { filename: /.*$/ }
  post 'api/store/create', action: 'create', controller: 'store'
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  # root "articles#index"
  get '/', action: 'index', controller: 'shop'
  get '/*path', action: 'index', controller: 'shop'
end
