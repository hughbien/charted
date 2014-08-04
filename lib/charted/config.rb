module Charted
  class << self
    attr_accessor :database

    def configure
      yield self.config
      Pony.options = config.email_options if !config.email_options.nil?
      Charted.database = Sequel.connect(config.db_options)
      require_relative 'model'
    end

    def config
      @config ||= Config.new
    end
  end

  class Config
    def self.attr_option(*names)
      names.each do |name|
        define_method(name) do |*args|
          value = args[0]
          instance_variable_set("@#{name}".to_sym, value) if !value.nil?
          instance_variable_get("@#{name}".to_sym)
        end
      end
    end

    attr_option :error_email, :email_options, :db_options, :delete_after, :sites
  end
end
