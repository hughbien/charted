module Charted
  class Migrate
    def self.run
      Sequel.extension :migration
      Sequel::Migrator.run(Charted.database, File.join(File.dirname(__FILE__), '..', '..', 'migrate'))
      # re-parse the schema after table changes
      [Site, Visitor, Visit, Event, Conversion, Experiment].each do |table|
        table.dataset = table.dataset
      end
    end
  end

  module HasVisitor
    def site
      self.visitor.site
    end
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

  class Site < Sequel::Model
    one_to_many :visitors

    def initialize(*args)
      super
      self.created_at ||= DateTime.now
    end

    def visitor_with_cookie(cookie)
      visitor = self.visitors_dataset[cookie.to_s.split('-').first.to_i]
      visitor && visitor.cookie == cookie ? visitor : nil
    end
  end

  class Visitor < Sequel::Model
    many_to_one :site
    one_to_many :visits
    one_to_many :events
    one_to_many :conversions
    one_to_many :experiments

    def initialize(*args)
      super
      self.created_at ||= DateTime.now
      self.bucket ||= rand(10)
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
        add_event(label: label)
      end
    end

    def start_conversions(labels)
      labels.to_s.split(';').map(&:strip).map do |label|
        conversions_dataset.first(label: label) || self.add_conversion(label: label)
      end
    end

    def start_experiments(labels) # label:bucket;...
      labels.to_s.split(';').map do |str|
        label, bucket = str.split(':', 2).map(&:strip)
        exp = experiments_dataset.first(label: label)
        if exp
          exp.update(bucket: bucket) if exp.bucket != bucket
          exp
        else
          self.add_experiment(label: label, bucket: bucket)
        end
      end
    end

    def end_goals(labels)
      labels.to_s.split(';').map(&:strip).each do |label|
        exp = experiments_dataset.first(label: label)
        exp.end! if exp
        conv = conversions_dataset.first(label: label)
        conv.end! if conv
      end
    end

    def self.generate_secret
      Digest::SHA1.hexdigest("#{Time.now}-#{rand(100)}")[0..4]
    end
  end

  class Visit < Sequel::Model
    include HasVisitor
    many_to_one :visitor

    def initialize(*args)
      super
      self.created_at ||= DateTime.now
    end

    def before_save
      self.search_terms = URI.parse(self.referrer).search_string if self.referrer.to_s !~ /^\s*$/
      super
    end
  end

  class Event < Sequel::Model
    include HasVisitor
    many_to_one :visitor

    def initialize(*args)
      super
      self.created_at ||= DateTime.now
    end
  end

  class Conversion < Sequel::Model
    include HasVisitor
    include Endable
    many_to_one :visitor

    def initialize(*args)
      super
      self.created_at ||= DateTime.now
    end
  end

  class Experiment < Sequel::Model
    include HasVisitor
    include Endable
    many_to_one :visitor

    def initialize(*args)
      super
      self.created_at ||= DateTime.now
    end
  end
end
