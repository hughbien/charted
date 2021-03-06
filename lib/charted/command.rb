module Charted
  class Command
    attr_accessor :config_loaded, :output
    attr_reader :site

    def clean(label=nil)
      load_config
      sys_exit("Please set 'delete_after' config.") if Charted.config.delete_after.nil?

      threshold = Date.today - Charted.config.delete_after
      Visit.where { created_at < threshold }.delete
      Event.where { created_at < threshold }.delete
      Conversion.where { created_at < threshold }.delete
      Experiment.where { created_at < threshold }.delete
      Visitor.where { created_at < threshold }.each do |visitor|
        visitor.delete if visitor.visits.count == 0 &&
          visitor.events.count == 0 &&
          visitor.conversions.count == 0 &&
          visitor.experiments.count == 0
      end

      if label
        Event.where(label: label).delete
        Conversion.where(label: label).delete
        Experiment.where(label: label).delete
      end
    end

    def dashboard
      site_required
      nodes = []
      max_width = [`tput cols`.to_i / 2, 60].min
      table = Dashes::Table.new.
        align(:right, :right, :left).
        row('Total', 'Unique', 'Visits').
        separator
      (0..11).each do |delta|
        date = Charted.prev_month(Date.today, delta)
        query = Charted::Visit.
          join(:visitors, id: :visitor_id).
          where(visitors__site_id: @site.id).
          where('visits.created_at >= ? AND visits.created_at < ?', date, Charted.next_month(date))
        visits = query.count
        unique = query.select(:visitor_id).distinct.count
        table.row(format(visits), format(unique), date.strftime('%B %Y'))
      end
      nodes += [table]
      [[:browser, 'Browsers', Charted::Visitor],
       [:resolution, 'Resolutions', Charted::Visitor],
       [:platform, 'Platforms', Charted::Visitor],
       [:country, 'Countries', Charted::Visitor],
       [:title, 'Pages', Charted::Visit],
       [:referrer, 'Referrers', Charted::Visit],
       [:search_terms, 'Searches', Charted::Visit]].each do |field, column, type|
        table = Dashes::Table.new.
          max_width(max_width).
          spacing(:min, :min, :max).
          align(:right, :right, :left).
          row('Total', '%', column).separator
        rows = []
        query = type.exclude(field => nil)
        query = query.join(:visitors, id: :visitor_id) if type == Charted::Visit
        query = query.where(visitors__site_id: @site.id)
        total = query.count
        query.group_and_count(field).each do |row|
          count = row[:count]
          label = row[field].to_s.strip
          next if label == ""
          label = "#{label[0..37]}..." if label.length > 40
          rows << [format(count), "#{((count / total.to_f) * 100).round}%", label]
        end
        add_truncated(table, rows)
        nodes << table
      end
      table = Dashes::Table.new.
        max_width(max_width).
        spacing(:min, :min, :max).
        align(:right, :right, :left).
        row('Total', 'Unique', 'Events').
        separator
      rows = []
      events = Charted::Event.join(:visitors, id: :visitor_id).where(visitors__site_id: @site.id)
      events.group_and_count(:label).all.each do |row|
        label, count = row[:label], row[:count]
        unique = Charted::Visitor.
          join(:events, visitor_id: :id).
          where(site_id: @site.id, events__label: label).
          select(:visitors__id).distinct.count
        rows << [format(count), format(unique), label]
      end
      add_truncated(table, rows)
      nodes << table

      table = Dashes::Table.new.
        max_width(max_width).
        spacing(:min, :min, :max).
        align(:right, :right, :left).
        row('Start', 'End', 'Conversions').
        separator
      rows = []
      conversions = Charted::Conversion.join(:visitors, id: :visitor_id).where(visitors__site_id: @site.id)
      conversions.group_and_count(:label).all.each do |row|
        label, count = row[:label], row[:count]
        ended = Charted::Visitor.
          join(:conversions, visitor_id: :id).
          where(site_id: @site.id, conversions__label: label).
          exclude(conversions__ended_at: nil).
          select(:visitors__id).distinct.count
        rows << [format(count), format(ended), label]
      end
      add_truncated(table, rows)
      nodes << table

      table = Dashes::Table.new.
        max_width(max_width).
        spacing(:min, :min, :max).
        align(:right, :right, :left).
        row('Start', 'End', 'Experiments').
        separator
      rows = []
      experiments = Charted::Experiment.join(:visitors, id: :visitor_id).where(visitors__site_id: @site.id)
      experiments.group_and_count(:label, :experiments__bucket).all.each do |row|
        label, bucket, count = row[:label], row[:bucket], row[:count]
        ended = Charted::Visitor.
          join(:experiments, visitor_id: :id).
          where(site_id: @site.id, experiments__label: label, experiments__bucket: bucket).
          exclude(experiments__ended_at: nil).
          select(:visitors__id).distinct.count
        rows << [format(count), format(ended), "#{label}: #{bucket}"]
      end
      add_truncated(table, rows)
      nodes << table

      nodes.reject! do |node|
        minimum = node.is_a?(Dashes::Table) ? 1 : 0
        node.instance_variable_get(:@rows).size == minimum # TODO: hacked
      end
      print(Dashes::Grid.new.width(`tput cols`.to_i).add(*nodes))
    end

    def js
      print(File.read(JS_FILE))
    end

    def migrate
      load_config
      Charted::Migrate.run
      Charted.config.sites.each do |domain|
        if Site.first(domain: domain).nil?
          Site.create(domain: domain)
        end
      end
    end

    def site=(domain)
      load_config
      sites = Site.where(Sequel.like(:domain, "%#{domain}%")).all

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
      sys_exit("Please set CHARTED_CONFIG to `config.ru` file.") if !File.exist?(file.to_s)
      load(file)
      @config_loaded = true
    end

    def sys_exit(reason)
      print(reason)
      ENV['RACK_ENV'] == 'test' ? raise(ExitError.new(reason)) : exit
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

    def add_truncated(table, rows)
      rows = rows.sort_by { |r| r[0].gsub(/[^\d]/, '').to_i }.reverse
      if rows.length > 12 
        rows = rows[0..11]
        rows << ['...', '...', '...']
      end
      rows.each { |row| table.row(*row) }
    end
  end

  class ExitError < RuntimeError; end
end
