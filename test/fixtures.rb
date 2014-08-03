require_relative '../lib/charted'
require 'date'

module Charted
  class Fixtures
    def self.load!
      Charted::Site.destroy
      Charted::Visitor.destroy
      Charted::Visit.destroy
      localhost = Charted::Site.create(:domain => 'localhost')
      example = Charted::Site.create(:domain => 'example.org')

      months = (0..11).map { |d| Charted.prev_month(Date.today, d) }
      200.times do
        visitor = Charted::Visitor.create(
          :site => select_rand([localhost, example]),
          :created_at => select_rand(months),
          :resolution => select_rand(%w(1400x900 1280x800 1024x768)),
          :platform => select_rand(['Linux', 'OS X', 'Windows']),
          :browser => select_rand(%w(IE Firefox Safari Chrome)),
          :browser_version => select_rand(%w(1 2 3 4 5)),
          :country => select_rand(%w(USA CA FR CH)),
          :ip_address => select_rand(%w(67.188.42.140 67.184.24.140)),
          :user_agent => select_rand([
            'Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 6.0)',
            'Mozilla/5.0 (X11; Linux i686; rv:14.0) Gecko/20100101 Firefox/14.0.1',
            'Mozilla/5.0 (Macintosh; U; PPC Mac OS X; en) AppleWebKit/125.2 (KHTML, like Gecko) Safari/125.8',
            'Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.8.1.19) Gecko/20081216 Ubuntu/8.04 (hardy) Firefox/2.0.0.19']))
        (rand(2) + 1).times do |index|
          Charted::Visit.create(
            :visitor => visitor,
            :created_at => Charted.next_month(visitor.created_at, select_rand([0, index])),
            :path => select_rand(%w(/ /page-one/ /page-two/ /page-three/)),
            :title => select_rand(%w(Prime Optimus Alpha Beta Omega)),
            :referrer => select_rand([
              'http://www.google.com?q=Charted+Test',
              'http://coverstrap.com',
              'http://news.ycombinator.com',
              'http://example.org']),
            :search_terms => select_rand([
              'Charted Keywords',
              'Web Analytics',
              'Command Line Analytics']))
        end
      end
    end

    private
    def self.select_rand(items)
      items[rand(items.length)]
    end
  end
end

if __FILE__ == $0
  ENV['CHARTED_CMD'] = '1'
  load(File.expand_path('../config.ru', File.dirname(__FILE__)))
  Charted::Fixtures.load!
end
