# app/controllers/api/events_controller.rb
# frozen_string_literal: true

class EventsController < ApplicationController
  skip_before_action :verify_authenticity_token

  # POST /api/events
  # JSON body (single or batch):
  # { "shop_id":"...", "entity":"product", "operation":"update", "handle":"sku-1", "event_id":"uuid", "occurred_at":"..." }
  # OR { "batch":[ { ... }, { ... } ] }
  #
  # Headers (recommended):
  # - X-Sellioly-Timestamp: ISO8601
  # - X-Sellioly-Signature: sha256=<hmac_of("ts\nraw_body")>
  # - X-Sellioly-Idempotency-Key: uuid-v4 (optional but recommended)
  #
  # Behavior: bump-only; returns 204 No Content on success.
  def create
    ok, err = Security::WebhookSignature.verify!(request, secret: ENV["SHOP_EVENTS_SECRET"].to_s)
    return render json: { error: err }, status: :unauthorized unless ok

    body = parse_json_body
    return render json: { error: "Invalid JSON" }, status: :bad_request unless body

    if body.is_a?(Hash) && body.key?("batch")
      handle_batch(body["batch"])
    else
      handle_single(body)
    end

    head :no_content
  rescue => e
    Rails.logger.error({ at: "events#create", err: e.class.name, msg: e.message, bt: e.backtrace&.take(5) }.to_json)
    render json: { error: "Server error" }, status: :internal_server_error
  end

  private

  def handle_single(ev)
    ev = normalize_event(ev)
    ensure_idempotency!(ev)

    vs = Infra::VersionStore.new
    Events::EventsMapper.bump!(vs: vs,
      shop_id:   ev.fetch("shop_id"),
      entity:    ev.fetch("entity"),
      operation: ev.fetch("operation"),
      handle:    ev["handle"]
    )
  end

  def handle_batch(list)
    Array(list).each do |ev|
      begin
        handle_single(ev)
      rescue => e
        Rails.logger.warn({ at: "events#batch_item", err: e.class.name, msg: e.message, ev: ev }.to_json)
      end
    end
  end

  def normalize_event(ev)
    {
      "shop_id"    => ev["shop_id"].to_s,
      "entity"     => ev["entity"].to_s,       # product | collection | menu | metadata | shop
      "operation"  => ev["operation"].to_s,    # insert | update | delete
      "handle"     => ev["handle"].presence,
      "event_id"   => (ev["event_id"].presence || ev["id"].presence),
      "occurred_at"=> ev["occurred_at"].presence
    }
  end

  def ensure_idempotency!(ev)
    key = request.get_header("HTTP_X_SELLIOLY_IDEMPOTENCY_KEY").presence || ev["event_id"]
    return if key.blank? # idempotency optional

    store = Infra::IdempotencyStore.new
    fresh = store.put_once(key)
    raise ArgumentError, "Duplicate event" unless fresh
  end

  def parse_json_body
    raw = request.raw_post.to_s
    return {} if raw.strip.empty?
    JSON.parse(raw)
  rescue JSON::ParserError
    nil
  end
end
