module Charted
  class App < Sinatra::Base
    set :logging, true

    before do
      @site = Site.first(domain: request.host)
      halt(404) if @site.nil?
      @visitor = @site.visitor_with_cookie(request.cookies['charted'])
    end

    get '/' do
      if @visitor.nil?
        @visitor = @site.visitors.create(
          resolution: params[:resolution],
          user_agent: request.user_agent,
          ip_address: request.ip,
          bucket: params[:bucket])
        response.set_cookie(
          'charted',
          value: @visitor.cookie,
          path: '/',
          expires: (Date.today + 365*2).to_time)
      end

      begin
        referrer = params[:referrer].to_s
        referrer = nil if URI.parse(referrer).host == @site.domain || referrer =~ /^\s*$/
      rescue URI::InvalidURIError
        referrer = nil
      end
      @visitor.visits.create(
        path: params[:path],
        title: params[:title],
        referrer: referrer)
      @visitor.start_conversions(params[:conversions])
      @visitor.start_experiments(params[:experiments])
      '/**/'
    end

    get '/record' do
      halt(404) if @visitor.nil?
      @visitor.make_events(params[:events])
      @visitor.end_goals(params[:goals])
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
end
