require 'rubygems'
require 'sinatra/base'
require 'dm-core'
require 'dm-types'
require 'dm-timestamps'
require 'dm-validations'
require 'date'
require 'digest/sha1'
require 'json'
require 'uri'
require 'geoip'
require 'pony'
require 'useragent'
require 'search_terms'
require 'colorize'

DataMapper::Model.raise_on_save_failure = true

module Metrics
  VERSION = '0.0.1'
  GEOIP = GeoIP.new("#{File.dirname(__FILE__)}/../geoip.dat")

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

    property :id, Serial
    property :domain, String, :required => true, :unique => true
    property :created_at, DateTime

    has n, :visitors
    has n, :visits, :through => :visitors
  end

  class Visitor
    include DataMapper::Resource

    property :id, Serial
    property :secret, String, :required => true
    property :resolution, String
    property :created_at, DateTime
    property :platform, String
    property :browser, String
    property :browser_version, String
    property :country, String

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

    def user_agent=(user_agent)
      ua = UserAgent.parse(user_agent)
      self.browser = ua.browser
      self.browser_version = ua.version
      self.platform = ua.platform == 'X11' ? 'Linux' : ua.platform
    end

    def ip_address=(ip)
      return if ip.to_s =~ /^\s*$/ || ip == '127.0.0.1'
      name = GEOIP.country(ip).country_name

      return if name =~ /^\s*$/ || name == 'N/A'
      self.country = name
    rescue SocketError
      # invalid IP address, skip setting country
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
    property :referrer, String
    property :search_terms, String
    property :created_at, DateTime

    belongs_to :visitor
    has 1, :site, :through => :visitor

    validates_presence_of :visitor

    before :save, :set_search_terms

    def set_search_terms
      return if self.referrer.to_s =~ /^\s*$/
      self.search_terms = URI.parse(self.referrer).search_string
    end
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
        visitor = Visitor.create(
          :site => site,
          :resolution => params[:resolution],
          :user_agent => request.user_agent,
          :ip_address => request.ip)
        response.set_cookie(
          'metrics',
          :value => visitor.cookie,
          :expires => (Date.today + 365*2).to_time)
      end

      visit = Visit.create(
        :visitor => visitor,
        :path => params[:path],
        :title => params[:title],
        :referrer => params[:referrer])
      '/**/'
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

  class Command
    attr_accessor :config_loaded, :output
    attr_reader :site

    def dashboard
      site_required
    end

    def migrate
      load_config
      DataMapper.auto_upgrade!
      Metrics.config.sites.each do |domain|
        if Site.first(:domain => domain).nil?
          Site.create(:domain => domain)
        end
      end
    end

    def site=(domain)
      load_config
      sites = Site.all(:domain.like => "%#{domain}%")

      if sites.length > 1
        sys_exit("\"#{domain}\" ambiguous: #{sites.map(&:domain).join(', ')}")
      elsif sites.length < 1
        sys_exit("No sites matching \"#{domain}\"")
      else
        @site = sites.first
      end
    end

    private
    def load_config
      return if @config_loaded
      file = ENV['METRICS_CONFIG']
      load(file)
      @config_loaded = true
    rescue LoadError
      sys_exit("METRICS_CONFIG not set, please set to `config.ru` file.")
    end

    def sys_exit(reason)
      print(reason)
      ENV['RACK_ENV'] == 'test' ? raise(ExitError.new) : exit
    end

    def print(string)
      ENV['RACK_ENV'] == 'test' ?  (@output ||= []) << string : puts(string)
    end

    def site_required
      if @site.nil? && Site.count == 1
        @site = Site.first
      elsif @site.nil?
        sys_exit('Please specify website with --site')
      end
    end
  end

  class ExitError < RuntimeError; end
end
