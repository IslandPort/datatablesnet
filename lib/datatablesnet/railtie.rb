# encoding: utf-8

module Datatablesnet
  # @private
  class Railtie < Rails::Railtie
    initializer 'datatablesnet.initialize' do
      ActiveSupport.on_load(:action_view) do
        include Datatable
      end
    end
  end
end