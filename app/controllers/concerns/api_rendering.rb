# frozen_string_literal: true
module ApiRendering
  # result: Http::Result (ok?, status, json, error)
  # location_for: ->(id) { url_or_nil }
  def render_result(result, mapper: method(:map_status), default_ok: :ok, location_for: nil)
    status = mapper.call(result.status, default_ok: default_ok)

    if result.ok? && location_for && result.json.is_a?(Hash)
      id = result.json["id"] || result.json[:id]
      headers["Location"] = location_for.call(id) if id.present?
    end

    payload = result.json || { error: result.error || "Upstream error" }
    render json: payload, status: status
  end
end
