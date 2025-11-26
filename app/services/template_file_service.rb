# frozen_string_literal: true

module Services
  class TemplateFileService
    class SecurityError < StandardError; end
    class FileNotFoundError < StandardError; end
    class InvalidFileTypeError < StandardError; end
    class FileTooLargeError < StandardError; end
  end
end

