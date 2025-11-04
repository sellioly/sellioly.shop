# frozen_string_literal: true
module UpstreamStatusMapper
  def map_status(upstream_status, default_ok: :ok)
    code = upstream_status.to_i
    return default_ok if (200..299).include?(code)

    case code
    when 400 then :bad_request
    when 401 then :unauthorized
    when 403 then :forbidden
    when 404 then :not_found
    when 409 then :conflict
    when 422 then :unprocessable_entity
    when 429 then :too_many_requests
    when 500 then :bad_gateway
    when 502, 503, 504 then :bad_gateway
    else :bad_gateway
    end
  end
end
