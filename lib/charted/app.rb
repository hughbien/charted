module Charted
  class App < Sinatra::Base
    set :logging, true
    set :raise_errors, false
    set :show_exceptions, false

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
      err = request.env['sinatra.error']
      Pony.mail(
        to: Charted.config.email,
        from: "charted@#{Charted.config.email.split('@')[1..-1].join}",
        subject: "[Charted Error] #{err.message}",
        body: [request.env.to_s, err.message, err.backtrace].compact.flatten.join("\n")
      ) if Charted.config.email
      raise err
    end
  end
end
