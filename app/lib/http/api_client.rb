# frozen_string_literal: true

require 'http'
require 'json'

# A small, resilient HTTP API client for Sellioly Ruby storefronts.
# Key improvements vs. original:
# - Dynamic headers on each request (e.g., current X-Store-Id) instead of freezing at init
# - Clear separation of request building, retries, parsing and result mapping
# - Optional structured logging hooks
# - Consistent idempotency header helper
# - Safer JSON parsing fallback and header normalization
# - Preserves all existing public method signatures/paths

module Http
  class ApiClient
    Result = Struct.new(:ok?, :status, :json, :error, :headers, keyword_init: true)

    # ------------------------------------------------------------------
    # Configuration
    # ------------------------------------------------------------------
    DEFAULT_OPEN_TIMEOUT = (ENV['HTTP_OPEN_TIMEOUT'] || 2).to_f
    DEFAULT_READ_TIMEOUT = (ENV['HTTP_READ_TIMEOUT'] || 3).to_f
    DEFAULT_RETRIES      = (ENV['HTTP_RETRIES'] || 1).to_i
    DEFAULT_BASE_URL     = ENV.fetch('API_BASE_URL', 'https://api.sellioly.com')

    RETRYABLE_ERRORS = [HTTP::TimeoutError, HTTP::ConnectionError].freeze
    EMPTY_HASH = {}.freeze

    # ------------------------------------------------------------------
    # Lifecycle
    # ------------------------------------------------------------------
    def initialize(
      base_url: DEFAULT_BASE_URL,
      open_timeout: DEFAULT_OPEN_TIMEOUT,
      read_timeout: DEFAULT_READ_TIMEOUT,
      retries: DEFAULT_RETRIES,
      logger: nil
    )
      @base_url     = base_url.chomp('/')
      @open_timeout = open_timeout
      @read_timeout = read_timeout
      @retries      = retries
      @logger       = logger

      # memoized base HTTP connection without headers; headers are layered per call
      @http_base = HTTP
        .use(:auto_inflate)
        .timeout(connect: @open_timeout, read: @read_timeout)
        .persistent(@base_url)
    end

    # ------------------------------------------------------------------
    # Legacy (form-encoded) endpoints — preserved 100% compatible
    # ------------------------------------------------------------------
    def product_by_handle(handle:, shop_id:, domain:)
      request(
        verb: :post, path: '/ruby/product/get-by-handle',
        body: { handle: handle, shop_id: shop_id, app_domain: domain },
        content: :form
      )
    end

    def collection_by_handle(handle:, shop_id:, domain:)
      request(
        verb: :post, path: '/ruby/collection/get-by-handle',
        body: { handle: handle, shop_id: shop_id, app_domain: domain },
        content: :form
      )
    end

    def products_by_collection(handle:, shop_id:, domain:, filters: {})
      payload = { handle: handle, user_id: shop_id, app_domain: domain }.merge(filters || {})
      request(
        verb: :post, path: '/ruby/product/get-by-collection',
        body: payload, content: :form
      )
    end

    def menu_by_handle(handle:, shop_id:, domain:)
      request(
        verb: :post, path: '/ruby/menu/get-by-handle',
        body: { handle: handle, shop_id: shop_id, app_domain: domain },
        content: :form
      )
    end

    def shop_info(shop_id:)
      request(
        verb: :post, path: '/ruby/store/infos',
        body: { shop_id: shop_id }, content: :form
      )
    end

    def metadata(shop_id:, domain:)
      request(
        verb: :post, path: '/ruby/metadata/store/list',
        body: { shop_id: shop_id, app_domain: domain }, content: :form
      )
    end

    def similar_products_by_handle(handle:, shop_id:, domain:)
      request(
        verb: :post, path: '/ruby/product/get-similar-by-handle',
        body: { handle: handle, user_id: shop_id, app_domain: domain }, content: :form
      )
    end

    def verify_domain(domain:, app_domain:)
      request(
        verb: :post, path: '/ruby/domain/verify',
        body: { domain: domain, app_domain: app_domain }, content: :form
      )
    end

    # ------------------------------------------------------------------
    # Cart (JSON)
    # ------------------------------------------------------------------
    def cart_show(cart_id:, currency: nil)
      request(
        verb: :get, path: '/ruby/cart',
        params: { cart_id: cart_id, currency: currency }.compact
      )
    end

    def cart_add_line(cart_id:, currency:, variant_id:, quantity:, properties: {}, idempotency_key: nil)
      request(
        verb: :post, path: '/ruby/cart/lines',
        body: {
          cart_id: cart_id,
          currency: currency,
          variant_id: variant_id,
          quantity: quantity,
          properties: (properties || {})
        },
        headers: idempotency_headers(idempotency_key)
      )
    end

    def cart_update_line(cart_id:, line_id:, quantity:)
      request(
        verb: :patch, path: "/ruby/cart/lines/#{line_id}",
        params: { cart_id: cart_id },
        body: { quantity: quantity }
      )
    end

    def cart_remove_line(cart_id:, line_id:)
      request(
        verb: :delete, path: "/ruby/cart/lines/#{line_id}",
        params: { cart_id: cart_id }
      )
    end

    # ------------------------------------------------------------------
    # Orders (JSON)
    # ------------------------------------------------------------------
    def get_order(order_id:)
      request(verb: :get, path: "/ruby/orders/#{order_id}")
    end

    def cancel_order(order_id:, idempotency_key: nil)
      request(
        verb: :post, path: "/ruby/orders/#{order_id}/cancel",
        headers: idempotency_headers(idempotency_key)
      )
    end

    # ------------------------------------------------------------------
    # Checkout Sessions (JSON)
    # ------------------------------------------------------------------
    def create_checkout_session(payload:, idempotency_key: nil)
      request(
        verb: :post, path: '/ruby/checkout/sessions',
        body: payload,
        headers: idempotency_headers(idempotency_key)
      )
    end

    def show_checkout_session(id:)
      request(verb: :get, path: "/ruby/checkout/sessions/#{id}")
    end

    def update_checkout_session(id:, payload:)
      request(verb: :patch, path: "/ruby/checkout/sessions/#{id}", body: payload)
    end

    def lock_checkout_session(id:, idempotency_key: nil)
      request(
        verb: :post, path: "/ruby/checkout/sessions/#{id}/lock",
        headers: idempotency_headers(idempotency_key)
      )
    end

    def place_checkout_session(id:, idempotency_key: nil)
      request(
        verb: :post, path: "/ruby/checkout/sessions/#{id}/place",
        headers: idempotency_headers(idempotency_key)
      )
    end

    # Read-only Orders API (v1)
    def show_order(id:)
      request(verb: :get, path: "/ruby/orders/#{id}")
    end

    # ------------------------------------------------------------------
    # Internals
    # ------------------------------------------------------------------
    private

    # Build a fresh client with dynamic default headers for each call.
    def http(extra_headers = EMPTY_HASH)
      # dynamic headers that may change per-thread/request
      dynamic_defaults = default_headers
      headers = extra_headers && !extra_headers.empty? ? dynamic_defaults.merge(extra_headers) : dynamic_defaults
      @http_base.headers(headers)
    end

    # Only static defaults + dynamic X-Store-Id resolved just-in-time.
    def default_headers
      {
        'User-Agent' => 'Sellioly-RubyShop/1 ApiClient',
        'Accept'     => 'application/json',
        'X-Store-Id' => safe_store_id
      }.compact
    end

    def idempotency_headers(key)
      return EMPTY_HASH if key.nil? || key.to_s.empty?
      { 'X-Idempotency-Key' => key.to_s, 'Idempotency-Key' => key.to_s }
    end

    def safe_store_id
      # Resolve the store id at request time. We guard with &. to avoid NoMethodError if StoreContext is not loaded in some environments.
      StoreContext&.store_id&.to_s
    rescue NameError
      nil
    end

    def request(verb:, path:, params: nil, body: nil, content: :json, headers: EMPTY_HASH)
      attempts = 0
      begin
        attempts += 1
        log_debug("HTTP #{verb.upcase} #{path} params=#{redact(params)} body=#{redact(body)} headers=#{redact(headers)} attempt=#{attempts}")

        response =
          case content
          when :form
            if body.nil?
              http(headers).public_send(verb, url_for(path), params: compact(params))
            else
              http(headers).public_send(verb, url_for(path), params: compact(params), form: (body || EMPTY_HASH))
            end
          else # :json (default)
            if body.nil?
              http(headers).public_send(verb, url_for(path), params: compact(params))
            else
              http(headers).public_send(verb, url_for(path), params: compact(params), json: body)
            end
          end

        build_result(response)
      rescue *RETRYABLE_ERRORS => e
        if attempts <= @retries
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
      # Try the lightweight parser first, then fall back to JSON.parse, then raw body
      response.parse
    rescue StandardError
      JSON.parse(response.body.to_s)
    rescue StandardError
      { 'raw' => response.body.to_s }
    end

    def build_result(response)
      body = safe_parse(response)
      ok   = response.status.success?

      # capture request headers actually sent (if available) would require http.rb hooks; keep response headers normalized
      Result.new(
        ok?: ok,
        status: response.status.to_i,
        json:   (ok ? body : nil),
        error:  (ok ? nil : body),
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

    def log_debug(msg)
      @logger&.debug(msg)
    end

    # Redact potentially sensitive values in logs (very basic; extend as needed)
    def redact(obj)
      return nil if obj.nil?
      return obj unless obj.is_a?(Hash)
      obj.transform_values do |v|
        if v.is_a?(Hash)
          redact(v)
        elsif v.is_a?(String) && v.length > 64
          v[0, 61] + '...'
        else
          v
        end
      end
    end
  end
end
