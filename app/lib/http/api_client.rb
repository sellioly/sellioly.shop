# frozen_string_literal: true
#
# Unified HTTP client for api.sellioly.com
# - Preserves legacy Ruby endpoints (form-encoded) used by storefronts
# - Adds new Cart JSON endpoints with idempotency support
# - Per-request timeouts, retries, and persistent connection
# - Small typed Result object with status + parsed JSON (or raw body fallback)
#
# Dependencies: gem 'http' (https://github.com/httprb/http)

require 'http'
require 'json'

module Http
  class ApiClient
    Result = Struct.new(:ok?, :status, :json, :error, keyword_init: true)

    DEFAULT_OPEN_TIMEOUT = (ENV['HTTP_OPEN_TIMEOUT'] || 2).to_f # seconds
    DEFAULT_READ_TIMEOUT = (ENV['HTTP_READ_TIMEOUT'] || 3).to_f # seconds
    DEFAULT_RETRIES      = (ENV['HTTP_RETRIES'] || 1).to_i

    def initialize(base_url: ENV.fetch('API_BASE_URL', 'https://api.sellioly.com'))
      @base_url = base_url.chomp('/')
    end

    # ----------------------------------------------------------------------
    # Legacy (form-encoded) endpoints — kept 100% compatible
    # ----------------------------------------------------------------------
    def product_by_handle(handle:, shop_id:, domain:)
      post_form('/ruby/product/get-by-handle', handle: handle, shop_id: shop_id, app_domain: domain)
    end

    def collection_by_handle(handle:, shop_id:, domain:)
      post_form('/ruby/collection/get-by-handle', handle: handle, shop_id: shop_id, app_domain: domain)
    end

    def products_by_collection(handle:, shop_id:, domain:, filters: {})
      payload = { handle: handle, user_id: shop_id, app_domain: domain }.merge(filters || {})
      post_form('/ruby/product/get-by-collection', payload)
    end

    def menu_by_handle(handle:, shop_id:, domain:)
      post_form('/ruby/menu/get-by-handle', handle: handle, shop_id: shop_id, app_domain: domain)
    end

    def shop_info(shop_id:)
      post_form('/ruby/store/infos', shop_id: shop_id)
    end

    def metadata(shop_id:, domain:)
      post_form('/ruby/metadata/store/list', shop_id: shop_id, app_domain: domain)
    end

    def similar_products_by_handle(handle:, shop_id:, domain:)
      post_form('/ruby/product/get-similar-by-handle', handle: handle, user_id: shop_id, app_domain: domain)
    end

    def verify_domain(domain:, app_domain:)
      post_form('/ruby/domain/verify', domain: domain, app_domain: app_domain)
    end

    # ----------------------------------------------------------------------
    # New Cart JSON endpoints
    # ----------------------------------------------------------------------
    def cart_show(cart_id:, currency: nil)
      request_json(method: :get, path: '/ruby/cart', params: { cart_id: cart_id, currency: currency }.compact)
    end

    # idempotency_key is optional but recommended for safe retries
    def cart_add_line(cart_id:, currency:, variant_id:, quantity:, properties: {}, idempotency_key: nil)
      headers = {}
      headers['X-Idempotency-Key'] = idempotency_key if idempotency_key
      body = { cart_id: cart_id, currency: currency, variant_id: variant_id, quantity: quantity, properties: properties }
      request_json(method: :post, path: '/ruby/cart/lines', json: body, headers: headers)
    end

    def cart_update_line(cart_id:, line_id:, quantity:)
      request_json(method: :patch, path: "/ruby/cart/lines/#{line_id}", params: { cart_id: cart_id }, json: { quantity: quantity })
    end

    def cart_remove_line(cart_id:, line_id:)
      request_json(method: :delete, path: "/ruby/cart/lines/#{line_id}", params: { cart_id: cart_id })
    end

    # ----------------------------------------------------------------------
    # Internals
    # ----------------------------------------------------------------------
    private

    def default_headers
      {
        'User-Agent' => 'Sellioly-RubyShop/1 ApiClient',
        'Accept' => 'application/json'
      }
    end

    # Persistent client bound to base_url. Per-call headers are merged via .headers.
    def http(extra_headers = {})
      (@http ||= HTTP.use(:auto_inflate)
                     .timeout(connect: DEFAULT_OPEN_TIMEOUT, read: DEFAULT_READ_TIMEOUT)
                     .headers(default_headers)
                     .persistent(@base_url))
        .headers(extra_headers)
    end

    def url_for(path)
      path.start_with?('/') ? (@base_url + path) : ("#{@base_url}/#{path}")
    end

    # Public wrapper kept for legacy code paths requiring form-encoded POSTs
    def post_form(path, form = nil, **kw)
      form = (form || {}).merge(kw)
      request_json(method: :post, path: path, form: form)
    end

    # Unified request handler for JSON + form bodies with retries and safe parsing
    def request_json(method:, path:, params: {}, json: nil, form: nil, headers: {})
      attempts = 0
      begin
        attempts += 1
        response = if form
          http(headers).public_send(method, url_for(path), params: compact(params), form: form)
        else
          # JSON request (Content-Type set by http.rb automatically)
          http(headers).public_send(method, url_for(path), params: compact(params), json: json)
        end
        build_result(response)
      rescue HTTP::TimeoutError, HTTP::ConnectionError => e
        retry if attempts <= DEFAULT_RETRIES
        Result.new(ok?: false, status: 599, json: nil, error: e.message)
      rescue StandardError => e
        Result.new(ok?: false, status: 599, json: nil, error: e.message)
      end
    end

    def compact(h)
      (h || {}).reject { |_k, v| v.nil? }
    end

    def safe_parse(response)
      response.parse
    rescue StandardError
      begin
        JSON.parse(response.body.to_s)
      rescue StandardError
        { 'raw' => response.body.to_s }
      end
    end

    def build_result(response)
      body = safe_parse(response)
      ok   = response.status.success?
      Result.new(ok?: ok, status: response.status.to_i, json: (ok ? body : nil), error: (ok ? nil : body))
    end
  end
end
