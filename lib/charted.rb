require 'rubygems'
require 'sinatra/base'
require 'dm-core'
require 'dm-types'
require 'dm-timestamps'
require 'dm-validations'
require 'dm-aggregates'
require 'date'
require 'digest/sha1'
require 'json'
require 'uri'
require 'geoip'
require 'pony'
require 'useragent'
require 'search_terms'
require 'terminal-table'
require 'colorize'
require 'dashes'

DataMapper::Model.raise_on_save_failure = true

module Charted
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

  def self.prev_month(date, delta=1)
    date = Date.new(date.year, date.month, 1)
    delta.times { date = Date.new((date - 1).year, (date - 1).month, 1) }
    date
  end

  def self.next_month(date, delta=1)
    date = Date.new(date.year, date.month, 1)
    delta.times { date = Date.new((date + 32).year, (date + 32).month, 1) }
    date
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

  module Endable
    def ended?
      !!ended_at
    end

    def end!
      self.ended_at = DateTime.now
      self.save
    end
  end

  class Site
    include DataMapper::Resource

    property :id, Serial
    property :domain, String, :required => true, :unique => true
    property :created_at, DateTime

    has n, :visitors
    has n, :visits, :through => :visitors

    def visitor_with_cookie(cookie)
      visitor = self.visitors.get(cookie.to_s.split('-').first)
      visitor && visitor.cookie == cookie ? visitor : nil
    end
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
    has n, :events
    has n, :conversions
    has n, :experiments

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

    def start_conversion(label)
      conversions.first(label: label) || self.conversions.create(label: label)
    end

    def end_conversion(label)
      conv = start_conversion(label)
      conv.end!
      conv
    end

    def start_experiment(label, bucket)
      exp = experiments.first(label: label)
      if exp
        exp.update(bucket: bucket) if exp.bucket != bucket
        exp
      else
        self.experiments.create(label: label, bucket: bucket)
      end
    end

    def end_experiment(label)
      exp = experiments.first(label: label)
      exp.end! if exp
      exp
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

  class Event
    include DataMapper::Resource

    property :id, Serial
    property :label, String, :required => true
    property :created_at, DateTime

    belongs_to :visitor
    has 1, :site, :through => :visitor

    validates_presence_of :visitor
  end

  class Conversion
    include DataMapper::Resource
    include Endable

    property :id, Serial
    property :label, String, :required => true
    property :created_at, DateTime
    property :ended_at, DateTime

    belongs_to :visitor
    has 1, :site, :through => :visitor

    validates_presence_of :visitor
  end

  class Experiment
    include DataMapper::Resource
    include Endable

    property :id, Serial
    property :label, String, :required => true
    property :bucket, String, :required => true
    property :created_at, DateTime
    property :ended_at, DateTime

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
      visitor = site.visitor_with_cookie(request.cookies['charted'])

      if visitor.nil?
        visitor = site.visitors.create(
          resolution: params[:resolution],
          user_agent: request.user_agent,
          ip_address: request.ip)
        response.set_cookie(
          'charted',
          value: visitor.cookie,
          expires: (Date.today + 365*2).to_time)
      end

      visitor.visits.create(
        path: params[:path],
        title: params[:title],
        referrer: params[:referrer])
      '/**/'
    end

    error do
      Pony.mail(
        to: Charted.config.email,
        from: "charted@#{Charted.config.email.split('@')[1..-1].join}",
        subject: 'Charted Error',
        body: request.env['sinatra.error'].to_s
      ) if Charted.config.email && self.class.environment == :production
    end
  end

  class Command
    attr_accessor :config_loaded, :output
    attr_reader :site

    def dashboard
      site_required
      nodes = []
      max_width = [`tput cols`.to_i / 2, 60].min
      chart = Dashes::Chart.new.
        max_width(max_width).
        title("Total Visits".colorize(:light_green))
      chart2 = Dashes::Chart.new.
        max_width(max_width).
        title("Unique Visits".colorize(:light_green))
      table = Dashes::Table.new.
        max_width(max_width).
        spacing(:min, :min, :max).
        align(:right, :right, :left).
        row('Total'.colorize(:light_blue),
          'Unique'.colorize(:light_blue),
          'Visits'.colorize(:light_green)).
        separator
      (0..11).each do |delta|
        date = Charted.prev_month(Date.today, delta)
        visits = @site.visits.count(
          :created_at.gte => date,
          :created_at.lt => Charted.next_month(date))
        unique = @site.visitors.count(:visits => {
          :created_at.gte => date,
          :created_at.lt => Charted.next_month(date)})
        table.row(format(visits), format(unique), date.strftime('%B %Y'))
        chart.row(date.strftime('%b %Y'), visits)
        chart2.row(date.strftime('%b %Y'), unique)
      end
      nodes += [table, chart, chart2]
      [[:browser, 'Browsers', :visitors],
       [:resolution, 'Resolutions', :visitors],
       [:platform, 'Platforms', :visitors],
       [:country, 'Countries', :visitors],
       [:title, 'Pages', :visits],
       [:referrer, 'Referrers', :visits],
       [:search_terms, 'Searches', :visits]].each do |field, column, type|
        table = Dashes::Table.new.
          max_width(max_width).
          spacing(:min, :min, :max).
          align(:right, :right, :left).
          row('Total'.colorize(:light_blue),
            '%'.colorize(:light_blue),
            column.colorize(:light_green)).separator
        rows = []
        total = @site.send(type).count(field.not => nil)
        @site.send(type).aggregate(field, :all.count).each do |label, count|
          label = label.to_s.strip
          next if label == ""
          label = "#{label[0..37]}..." if label.length > 40
          rows << [format(count), "#{((count / total.to_f) * 100).round}%", label]
        end
        rows.sort_by { |r| r[1] }.reverse.each { |row| table.row(*row) }
        nodes << table
      end
      print(Dashes::Grid.new.width(`tput cols`.to_i).add(*nodes))
    end

    def migrate
      load_config
      DataMapper.auto_upgrade!
      Charted.config.sites.each do |domain|
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
      file = ENV['CHARTED_CONFIG']
      load(file)
      @config_loaded = true
    rescue LoadError
      sys_exit("CHARTED_CONFIG not set, please set to `config.ru` file.")
    end

    def sys_exit(reason)
      print(reason)
      ENV['RACK_ENV'] == 'test' ? raise(ExitError.new) : exit
    end

    def print(string)
      ENV['RACK_ENV'] == 'test' ?  (@output ||= []) << string : puts(string)
    end

    def site_required
      load_config
      if @site.nil? && Site.count == 1
        @site = Site.first
      elsif @site.nil?
        sys_exit('Please specify website with --site')
      end
    end

    def format(num)
      num.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse
    end
  end

  class ExitError < RuntimeError; end
end
