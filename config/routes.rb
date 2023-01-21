Rails.application.routes.draw do
  # constraints host: 'shop.sellioly.com' do
  #   post 'api/store/create', action: 'create', controller: 'store'
  #   get '/', action: 'not_found', controller: 'shop'
  #   get '/*path', action: 'not_found', controller: 'shop'
  # end

    get '/screenshots/:shop_id/:template_id', action: 'preview', controller: 'store'
    get '/preview/:shop_id/:template_id', action: 'preview', controller: 'shop'
    get '/preview', action: 'page', controller: 'shop'

  # constraints lambda { |req| req.host != 'shop.sellioly.com' &&  req.host != 'preview.sellioly.com' } do
  #   get '/collections/:collection', action: 'collection', controller: 'shop'
  #   get '/products/:product', action: 'product', controller: 'shop'
  #   get '/files/1/assets/:filename', to: 'shop#file_assets', constraints: { filename: /[^\/]+/ }
  #   # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  #
  #   # Defines the root path route ("/")
  #   # root "articles#index"
  #   get '/', action: 'index', controller: 'shop'
  #   get '/*path', action: 'page', controller: 'shop'
  # end

  # end
end
