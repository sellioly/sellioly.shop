# frozen_string_literal: true

require 'http'
require 'json'

module Http
  class ApiClient
    Result = Struct.new(:ok?, :status, :json, :error, :headers, keyword_init: true)

    DEFAULT_OPEN_TIMEOUT = (ENV['HTTP_OPEN_TIMEOUT'] || 2).to_f
    DEFAULT_READ_TIMEOUT = (ENV['HTTP_READ_TIMEOUT'] || 3).to_f
    DEFAULT_RETRIES      = (ENV['HTTP_RETRIES'] || 1).to_i
    DEFAULT_BASE_URL     = ENV.fetch('API_BASE_URL', 'https://api.sellioly.com')

    RETRYABLE_ERRORS = [HTTP::TimeoutError, HTTP::ConnectionError].freeze
    EMPTY_HASH = {}.freeze

    def initialize(base_url: DEFAULT_BASE_URL)
      @base_url = base_url.chomp('/')
      @default_headers = {
        'User-Agent' => 'Sellioly-RubyShop/1 ApiClient',
        'Accept'     => 'application/json',
        "X-Shop-Id"  => StoreContext.store_id.to_s
      }.freeze
    end

    # ----------------------------------------------------------------------
    # Legacy (form-encoded) endpoints — preserved 100% compatible
    # ----------------------------------------------------------------------
    def product_by_handle(handle:, shop_id:, domain:)
      request(verb: :post, path: '/ruby/product/get-by-handle',
              body: { handle:, shop_id:, app_domain: domain }, content: :form)
    end

    def collection_by_handle(handle:, shop_id:, domain:)
      request(verb: :post, path: '/ruby/collection/get-by-handle',
              body: { handle:, shop_id:, app_domain: domain }, content: :form)
    end

    def products_by_collection(handle:, shop_id:, domain:, filters: {})
      payload = { handle:, user_id: shop_id, app_domain: domain }.merge(filters || {})
      request(verb: :post, path: '/ruby/product/get-by-collection',
              body: payload, content: :form)
    end

    def menu_by_handle(handle:, shop_id:, domain:)
      request(verb: :post, path: '/ruby/menu/get-by-handle',
              body: { handle:, shop_id:, app_domain: domain }, content: :form)
    end

    def shop_info(shop_id:)
      request(verb: :post, path: '/ruby/store/infos',
              body: { shop_id: }, content: :form)
    end

    def metadata(shop_id:, domain:)
      request(verb: :post, path: '/ruby/metadata/store/list',
              body: { shop_id:, app_domain: domain }, content: :form)
    end

    def similar_products_by_handle(handle:, shop_id:, domain:)
      request(verb: :post, path: '/ruby/product/get-similar-by-handle',
              body: { handle:, user_id: shop_id, app_domain: domain }, content: :form)
    end

    def verify_domain(domain:, app_domain:)
      request(verb: :post, path: '/ruby/domain/verify',
              body: { domain:, app_domain: }, content: :form)
    end

    # ----------------------------------------------------------------------
    # Cart (JSON)
    # ----------------------------------------------------------------------
    def cart_show(cart_id:, currency: nil)
      request(verb: :get, path: '/ruby/cart',
              params: { cart_id:, currency: }.compact)
    end

    def cart_add_line(cart_id:, currency:, variant_id:, quantity:, properties: {}, idempotency_key: nil)
      headers = {}
      # Keep legacy header while also supporting the bare header name.
      headers['X-Idempotency-Key'] = idempotency_key if idempotency_key
      headers['Idempotency-Key']   = idempotency_key if idempotency_key
      request(verb: :post, path: '/ruby/cart/lines',
              params: nil,
              body: { cart_id:, currency:, variant_id:, quantity:, properties: properties || {} },
              headers:)
    end

    def cart_update_line(cart_id:, line_id:, quantity:)
      request(verb: :patch, path: "/ruby/cart/lines/#{line_id}",
              params: { cart_id: }, body: { quantity: })
    end

    def cart_remove_line(cart_id:, line_id:)
      request(verb: :delete, path: "/ruby/cart/lines/#{line_id}",
              params: { cart_id: })
    end

    # ----------------------------------------------------------------------
    # Orders (JSON)
    # ----------------------------------------------------------------------
    def get_order(order_id:)
      request(verb: :get, path: "/ruby/orders/#{order_id}")
    end

    def cancel_order(order_id:, idempotency_key: nil)
      headers = {}
      headers['X-Idempotency-Key'] = idempotency_key if idempotency_key
      headers['Idempotency-Key']   = idempotency_key if idempotency_key
      request(verb: :post, path: "/ruby/orders/#{order_id}/cancel", body: nil, headers:)
    end

    # ----------------------------------------------------------------------
    # Checkout Sessions (JSON)
    # ----------------------------------------------------------------------
    def create_checkout_session(payload:, idempotency_key: nil)
      headers = {}
      headers['X-Idempotency-Key'] = idempotency_key if idempotency_key
      headers['Idempotency-Key']   = idempotency_key if idempotency_key
      request(verb: :post, path: '/ruby/checkout/sessions', body: payload, headers:)
    end

    def show_checkout_session(id:)
      request(verb: :get, path: "/ruby/checkout/sessions/#{id}")
    end

    def update_checkout_session(id:, payload:)
      request(verb: :patch, path: "/ruby/checkout/sessions/#{id}", body: payload)
    end

    def lock_checkout_session(id:, idempotency_key: nil)
      headers = {}
      headers['X-Idempotency-Key'] = idempotency_key if idempotency_key
      headers['Idempotency-Key']   = idempotency_key if idempotency_key
      request(verb: :post, path: "/ruby/checkout/sessions/#{id}/lock", body: nil, headers:)
    end

    def place_checkout_session(id:, idempotency_key: nil)
      headers = {}
      headers['X-Idempotency-Key'] = idempotency_key if idempotency_key
      headers['Idempotency-Key']   = idempotency_key if idempotency_key
      request(verb: :post, path: "/ruby/checkout/sessions/#{id}/place", body: nil, headers:)
    end

    # Read-only Orders API (v1)
    def show_order(id:)
      request(verb: :get, path: "/ruby/orders/#{id}")
    end

    # ----------------------------------------------------------------------
    # Internals
    # ----------------------------------------------------------------------
    private

    def http(extra_headers = EMPTY_HASH)
      base = (@http ||= HTTP
        .use(:auto_inflate)
        .timeout(connect: DEFAULT_OPEN_TIMEOUT, read: DEFAULT_READ_TIMEOUT)
        .headers(@default_headers)
        .persistent(@base_url))
      return base if extra_headers.nil? || extra_headers.empty?
      base.headers(extra_headers)
    end

    def request(verb:, path:, params: nil, body: nil, content: :json, headers: EMPTY_HASH)
      attempts = 0
      begin
        attempts += 1
        response =
          case content
          when :form
            http(headers).public_send(verb, url_for(path), params: compact(params), form: (body || EMPTY_HASH))
          else # :json (default)
            if body.nil?
              http(headers).public_send(verb, url_for(path), params: compact(params))
            else
              http(headers).public_send(verb, url_for(path), params: compact(params), json: body)
            end
          end
        build_result(response)
      rescue *RETRYABLE_ERRORS => e
        if attempts <= DEFAULT_RETRIES
          backoff_sleep(attempts)
          retry
        end
        Result.new(ok?: false, status: 599, json: nil, error: e.message, headers: {})
      rescue StandardError => e
        Result.new(ok?: false, status: 599, json: nil, error: e.message, headers: {})
      end
    end

    def url_for(path)
      path.start_with?('/') ? (@base_url + path) : "#{@base_url}/#{path}"
    end

    def compact(h)
      return EMPTY_HASH if h.nil? || h.empty?
      h.reject { |_k, v| v.nil? }
    end

    def safe_parse(response)
      response.parse
    rescue StandardError
      JSON.parse(response.body.to_s)
    rescue StandardError
      { 'raw' => response.body.to_s }
    end

    def build_result(response)
      body = safe_parse(response)
      ok   = response.status.success?
      Result.new(
        ok?: ok,
        status: response.status.to_i,
        json: (ok ? body : nil),
        error: (ok ? nil : body),
        headers: stringify_headers(response.headers)
      )
    end

    def stringify_headers(headers)
      return {} unless headers
      headers.to_h.transform_keys!(&:to_s).transform_values!(&:to_s)
    rescue StandardError
      {}
    end

    # Exponential backoff with full jitter; max ~1.6s
    def backoff_sleep(attempt)
      base = 0.1 * (2**(attempt - 1))
      sleep(rand(0.0..[base, 1.6].min))
    end
  end
end
