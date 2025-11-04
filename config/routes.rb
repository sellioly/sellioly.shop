Rails.application.routes.draw do
  # Always-200 lightweight health endpoint for containers/load balancers
  get "/health", to: proc { [200, { "Content-Type" => "text/plain" }, ["OK"]] }
  
  mount LetsEncrypt::Engine => '/.well-known'
  constraints host: 'shop.sellioly.com' do
    get 'api/ssl/publish', action: 'generate_ssl', controller: 'ssl'
    get 'api/ssl/renew', action: 'renew_ssl', controller: 'ssl'
    get 'api/ssl/verify', action: 'verify_ssl', controller: 'ssl' 

    post 'api/store/create', action: 'create', controller: 'store'

    post 'api/theme/verify', action: 'verify_theme', controller: 'template'
    post 'api/template/import', action: 'import_template', controller: 'template'
    post 'api/template/publish', action: 'publish_template', controller: 'template'
    post 'api/template/:page', action: 'request_template_page', controller: 'template'
    get 'api/template/download', action: 'request_template', controller: 'template'
    get 'api/assets', action: 'request_asset_content', controller: 'template'
    put 'api/assets', action: 'update_asset_content', controller: 'template'
    post 'api/assets', action: 'request_assets_template', controller: 'template'

    post 'api/events', to: 'events#create'

    get '/', action: 'not_found', controller: 'shop'
    get '/*path', action: 'not_found', controller: 'shop'
  end

  constraints host: 'preview.sellioly.com' do
    # CORS preflight for the editor
    match '/preview/:shop_id/:template_id',               to: 'preview#preflight', via: :options
    match '/preview/:shop_id/:template_id/builder',       to: 'preview#preflight', via: :options
    match '/preview/:shop_id/:template_id/screenshot',    to: 'preview#preflight', via: :options

    # Generic and builder preview
    get   '/preview/:shop_id/:template_id',               to: 'preview#show'
    get   '/preview/:shop_id/:template_id/builder',       to: 'preview#builder'
    get   '/preview/:shop_id/:template_id/screenshot',    to: 'preview#screenshot'

    # Legacy editor aliases (no shop host constraint section)
    # If you prefer to keep them under non-preview hosts, add them in that block as well.
    get '/product-preview',    to: 'preview#legacy_builder_product'
    get '/collection-preview', to: 'preview#legacy_builder_collection'
    get '/cart-preview',       to: 'preview#legacy_builder_cart'
    get '/checkout-preview',   to: 'preview#legacy_builder_checkout'

    # Static assets remain as-is (served from ShopController)
    get '/files/1/:shop_id/:template_id/assets/*filepath', to: 'assets#show', format: false
  end

  constraints lambda { |req| req.host != 'shop.sellioly.com' &&  req.host != 'preview.sellioly.com' } do
    
    # ----------------------- Cart 
    get    '/api/cart',           to: 'carts#show'
    post   '/api/cart/lines',     to: 'carts#add_line'
    patch  '/api/cart/lines/:id', to: 'carts#update_line'
    delete '/api/cart/lines/:id', to: 'carts#remove_line'

    # ----------------------- Orders
    get    '/api/orders/:id',        to: 'orders#show'
    # post   '/api/orders/:id/cancel', to: 'orders#cancel'
    
    # ----------------------- Checkout session 
    post   '/api/checkout_sessions',           to: 'checkout_sessions#create'
    get    '/api/checkout_sessions/:id',       to: 'checkout_sessions#show'
    patch  '/api/checkout_sessions/:id',       to: 'checkout_sessions#update'
    post   '/api/checkout_sessions/:id/lock',  to: 'checkout_sessions#lock'
    post   '/api/checkout_sessions/:id/place', to: 'checkout_sessions#place'

    # ----------------------- Shop pages
    get '/collections/:collection', action: 'collection', controller: 'shop'
    get '/products/:product', action: 'product', controller: 'shop'
    get '/checkout', action: 'checkout', controller: 'shop'
    get '/cart', action: 'cart', controller: 'shop'
    get '/product-preview', action: 'productPreview', controller: 'shop'
    get '/collection-preview', action: 'collectionPreview', controller: 'shop'
    get '/cart-preview', action: 'cartPreview', controller: 'shop'
    get '/checkout-preview', action: 'checkoutPreview', controller: 'shop'
    get '/our-store', action: 'our_store', controller: 'shop'
    get '/about-us', action: 'about_us', controller: 'shop'
    get '/order-completed/:order', action: 'order_completed', controller: 'shop'
    get '/404', action: 'not_found', controller: 'shop'

    get '/files/1/:shop_id/:template_id/assets/*filepath', to: 'assets#show', format: false
    # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

    # Defines the root path route ("/")
    # root "articles#index"
    get '/', action: 'index', controller: 'shop'
    # get '/*path', action: 'page', controller: 'shop'
  end
end
