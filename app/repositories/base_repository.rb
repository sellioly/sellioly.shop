# frozen_string_literal: true
class BaseRepository
  def initialize(api: Http::ApiClient.new)
    @api = api
  end
end