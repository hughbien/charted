require 'rubygems'
require 'sinatra/base'
require 'dm-core'
require 'dm-types'
require 'dm-timestamps'
require 'date'
require 'digest/sha1'
require 'json'
require 'pony'

DataMapper::Model.raise_on_save_failure = true

module Metrics
  VERSION = '0.0.1'

  def self.configure(setup_db=true)
    yield self.config
    DataMapper.setup(:default,
      :adapter  => config.db_adapter,
      :host     => config.db_host,
      :username => config.db_username,
      :password => config.db_password,
      :database => config.db_database
    ) if setup_db
  end

  def self.config
    @config ||= Config.new
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

    attr_option :email, :delete_after, :sites,
                :db_adapter, :db_host, :db_username, :db_password, :db_database
  end

  class Site
    include DataMapper::Resource

    property :id,     Serial
    property :domain, String, :required => true, :unique => true

    has n, :visitors
    has n, :visits, :through => :visitors
  end

  class Visitor
    include DataMapper::Resource

    property :id, Serial

    belongs_to :site, :key => true
    has n, :visits
  end

  class Visit
    include DataMapper::Resource

    property :id, Serial

    belongs_to :visitor, :key => true
    has 1, :site, :through => :visitor
  end

  DataMapper.finalize

  class App < Sinatra::Base
    set :logging, true

    get '/' do
      'OK'
    end

    error do
      Pony.mail(
        :to => Metrics.config.email,
        :from => "metrics@#{Metrics.config.email.split('@')[1..-1].join}",
        :subject => 'Metrics Error',
        :body => request.env['sinatra.error'].to_s
      ) if Metrics.config.email && self.class.environment == :production
    end
  end
end
