# frozen_string_literal: true
class BaseRepository
  def initialize(api: Http::ApiClient.new)
    @api = api
  end

  private

  def ok_json_or_result(res)
    # دائمًا نرجع Result (ولا نرمي استثناء هنا)
    Http::Result.new(ok?: res.ok?, status: res.status, json: res.json, error: res.error)
  end

  def to_vo(klass, hash)
    return nil unless hash
    klass.new(hash)
  end
end