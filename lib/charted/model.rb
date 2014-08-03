DataMapper::Model.raise_on_save_failure = true
DataMapper::Property::String.length(255)

module Charted
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
    has n, :events, :through => :visitors
    has n, :conversions, :through => :visitors
    has n, :experiments, :through => :visitors

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
    property :bucket, Integer

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
      # TODO: raise if nil id, bucket, or secret
      "#{self.id}-#{self.bucket}-#{self.secret}"
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

    def make_events(labels)
      labels.to_s.split(';').map(&:strip).map do |label|
        events.create(label: label)
      end
    end

    def start_conversions(labels)
      labels.to_s.split(';').map(&:strip).map do |label|
        conversions.first(label: label) || self.conversions.create(label: label)
      end
    end

    def start_experiments(labels) # label:bucket;...
      labels.to_s.split(';').map do |str|
        label, bucket = str.split(':', 2).map(&:strip)
        exp = experiments.first(label: label)
        if exp
          exp.update(bucket: bucket) if exp.bucket != bucket
          exp
        else
          self.experiments.create(label: label, bucket: bucket)
        end
      end
    end

    def end_goals(labels)
      labels.to_s.split(';').map(&:strip).each do |label|
        exp = experiments.first(label: label)
        exp.end! if exp
        conv = conversions.first(label: label)
        conv.end! if conv
      end
    end

    def self.generate_secret
      Digest::SHA1.hexdigest("#{Time.now}-#{rand(100)}")[0..4]
    end
  end

  class Visit
    include DataMapper::Resource

    property :id, Serial
    property :path, String, required: true
    property :title, String, required: true
    property :referrer, String, length: 2048
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
end
