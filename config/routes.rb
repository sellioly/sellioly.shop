Rails.application.routes.draw do
  mount LetsEncrypt::Engine => '/.well-known'
  constraints host: 'shop.sellioly.com' do
    get 'api/ssl/publish', action: 'generate_ssl', controller: 'store'
    get 'api/ssl/renew', action: 'renew_ssl', controller: 'store'
    get 'api/ssl/verify', action: 'verify_ssl', controller: 'store'
    post 'api/store/create', action: 'create', controller: 'store'
    post 'api/template/import', action: 'import_template', controller: 'store'
    post 'api/template/publish', action: 'publish_template', controller: 'store'
    post 'api/template/:page', action: 'request_template_page', controller: 'store'
    post 'api/cart/add', action: 'add', controller: 'cart'
    get 'api/cart/get', action: 'get', controller: 'cart'
    get '/', action: 'not_found', controller: 'shop'
    get '/*path', action: 'not_found', controller: 'shop'
  end

  constraints host: 'preview.sellioly.com' do
    get '/preview/:shop_id/:template_id', action: 'preview', controller: 'shop'
    get '/files/1/:shop_id/:template_id/assets/:filename', to: 'shop#file_assets', constraints: { filename: /[^\/]+/ }
    get '/files/1/:shop_id/:template_id/assets/fonts/:filename', to: 'shop#file_font_assets', constraints: { filename: /[^\/]+/ }
  end

  constraints lambda { |req| req.host != 'shop.sellioly.com' &&  req.host != 'preview.sellioly.com' } do
    get '/collections/:collection', action: 'collection', controller: 'shop'
    get '/products/:product', action: 'product', controller: 'shop'
    # get '/products/:checkout', action: 'checkout', controller: 'shop'
    get '/files/1/:shop_id/:template_id/assets/:filename', to: 'shop#file_assets', constraints: { filename: /[^\/]+/ }
    get '/files/1/:shop_id/:template_id/assets/fonts/:filename', to: 'shop#file_font_assets', constraints: { filename: /[^\/]+/ }
    # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

    # Defines the root path route ("/")
    # root "articles#index"
    get '/', action: 'index', controller: 'shop'
    get '/*path', action: 'page', controller: 'shop'
  end
end
