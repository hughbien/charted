require 'rubygems'
require 'sinatra/base'
require 'dm-core'
require 'dm-types'
require 'dm-timestamps'
require 'dm-validations'
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
    property :secret, String, :required => true

    belongs_to :site
    has n, :visits

    validates_presence_of :site

    def initialize(*args)
      super
      self.secret = self.class.generate_secret
    end

    def cookie
      "#{self.id}-#{self.secret}"
    end

    def self.get_by_cookie(site, cookie)
      visitor = Visitor.get(cookie.to_s.split('-').first)
      visitor && visitor.site == site && visitor.cookie == cookie ?
        visitor :
        nil
    end

    def self.generate_secret
      Digest::SHA1.hexdigest("#{Time.now}-#{rand(100)}")[0..4]
    end
  end

  class Visit
    include DataMapper::Resource

    property :id, Serial
    property :path, String, :required => true
    property :title, String, :required => true

    belongs_to :visitor
    has 1, :site, :through => :visitor

    validates_presence_of :visitor
  end

  DataMapper.finalize

  class App < Sinatra::Base
    set :logging, true

    get '/' do
      site = Site.first(:domain => request.host)
      halt(404) if site.nil?

      if request.cookies['metrics']
        visitor = Visitor.get_by_cookie(site, request.cookies['metrics'])
      end

      if visitor.nil?
        visitor = Visitor.create(:site => site)
        response.set_cookie(
          'metrics',
          :value => visitor.cookie,
          :expires => (Date.today + 365*2).to_time)
      end

      visit = Visit.create(
        :visitor => visitor,
        :path => params[:path],
        :title => params[:title])
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
