Rails.application.routes.draw do
  constraints host: 'shop.sellioly.com' do
    post 'api/store/create', action: 'create', controller: 'store'
    get '/', action: 'not_found', controller: 'shop'
    get '/*path', action: 'not_found', controller: 'shop'
  end

  constraints lambda { |req| req.host != 'shop.sellioly.com' } do
    get '/collections/:collection', action: 'collection', controller: 'shop'
    get '/products/:product', action: 'product', controller: 'shop'
    get '/files/1/assets/:filename', action: 'file_assets', controller: 'shop', constraint: { filename: /.*/ }
    # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

    # Defines the root path route ("/")
    # root "articles#index"
    get '/', action: 'index', controller: 'shop'
    get '/*path', action: 'page', controller: 'shop'
  end

  # end
end
