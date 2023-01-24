Rails.application.routes.draw do
  constraints host: 'shop.sellioly.com' do
    post 'api/store/create', action: 'create', controller: 'store'
    post 'api/template/import', action: 'import_template', controller: 'store'
    post 'api/template/publish', action: 'publish_template', controller: 'store'
    get '/', action: 'not_found', controller: 'shop'
    get '/*path', action: 'not_found', controller: 'shop'
  end

  constraints host: 'preview.sellioly.com' do
    get '/preview/:shop_id/:template_id', action: 'preview', controller: 'shop'
    get '/files/1/:shop_id/:template_id/assets/:filename', to: 'shop#file_assets', constraints: { filename: /[^\/]+/ }
  end

  constraints lambda { |req| req.host != 'shop.sellioly.com' &&  req.host != 'preview.sellioly.com' } do
    get '/collections/:collection', action: 'collection', controller: 'shop'
    get '/products/:product', action: 'product', controller: 'shop'
    get '/files/1/:shop_id/:template_id/assets/:filename', to: 'shop#file_assets', constraints: { filename: /[^\/]+/ }
    # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

    # Defines the root path route ("/")
    # root "articles#index"
    get '/', action: 'index', controller: 'shop'
    get '/*path', action: 'page', controller: 'shop'
  end

  # end
end
