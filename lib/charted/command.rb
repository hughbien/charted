module Charted
  class Command
    attr_accessor :config_loaded, :output
    attr_reader :site

    def clean(label=nil)
      load_config
      sys_exit("Please set 'delete_after' config.") if Charted.config.delete_after.nil?

      threshold = Date.today - Charted.config.delete_after
      Visit.all(:created_at.lt => threshold).destroy
      Event.all(:created_at.lt => threshold).destroy
      Conversion.all(:created_at.lt => threshold).destroy
      Experiment.all(:created_at.lt => threshold).destroy
      Visitor.all(:created_at.lt => threshold).each do |visitor|
        visitor.destroy if visitor.visits.count == 0 &&
          visitor.events.count == 0 &&
          visitor.conversions.count == 0 &&
          visitor.experiments.count == 0
      end

      if label
        Event.all(label: label).destroy
        Conversion.all(label: label).destroy
        Experiment.all(label: label).destroy
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
        visits = @site.visits.count(
          :created_at.gte => date,
          :created_at.lt => Charted.next_month(date))
        unique = @site.visitors.count(:visits => {
          :created_at.gte => date,
          :created_at.lt => Charted.next_month(date)})
        table.row(format(visits), format(unique), date.strftime('%B %Y'))
      end
      nodes += [table]
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
          row('Total', '%', column).separator
        rows = []
        total = @site.send(type).count(field.not => nil)
        @site.send(type).aggregate(field, :all.count).each do |label, count|
          label = label.to_s.strip
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
      @site.events.aggregate(:label, :all.count).each do |label, count|
        unique = @site.visitors.count(:events => {label: label})
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
      @site.conversions.aggregate(:label, :all.count).each do |label, count|
        ended = @site.conversions.count(label: label, :ended_at.not => nil)
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
      @site.experiments.aggregate(:label, :bucket, :all.count).each do |label, bucket, count|
        ended = @site.experiments.count(label: label, bucket: bucket, :ended_at.not => nil)
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
