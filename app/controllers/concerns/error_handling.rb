# frozen_string_literal: true

module ErrorHandling
  extend ActiveSupport::Concern

  included do
    rescue_from Services::TemplateFileService::SecurityError, with: :render_security_error
    rescue_from Services::TemplateFileService::FileNotFoundError, with: :render_not_found
    rescue_from Services::TemplateFileService::InvalidFileTypeError, with: :render_validation_error
    rescue_from Services::TemplateFileService::FileTooLargeError, with: :render_validation_error
    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
    rescue_from ActionController::ParameterMissing, with: :render_bad_request
  end

  private

  def render_security_error(exception)
    render json: {
      error: {
        code: 'security_error',
        message: exception.message
      }
    }, status: :forbidden
  end

  def render_not_found(exception)
    render json: {
      error: {
        code: 'not_found',
        message: exception.message || 'Resource not found'
      }
    }, status: :not_found
  end

  def render_validation_error(exception)
    render json: {
      error: {
        code: 'validation_error',
        message: exception.message
      }
    }, status: :bad_request
  end

  def render_bad_request(exception)
    render json: {
      error: {
        code: 'bad_request',
        message: exception.message || 'Invalid request parameters'
      }
    }, status: :bad_request
  end
end

