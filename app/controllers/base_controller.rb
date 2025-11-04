# frozen_string_literal: true
class Api::BaseController < ApplicationController
  include UpstreamStatusMapper
  include IdempotencyKey
  include ApiRendering

  # ApplicationController عندك أصلاً فيه:
  # - protect_from_forgery with: :null_session
  # - rescue_from StandardError, with: :log_and_render_error
  # لذا ما نكررهم هنا.
end
