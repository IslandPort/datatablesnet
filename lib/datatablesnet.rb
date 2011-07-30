require 'datatablesnet/railtie' if defined?(::Rails)

module Datatablesnet
  extend ActiveSupport::Autoload

  autoload :Datatable
  autoload :HashSql
  autoload :NoEscape

end
