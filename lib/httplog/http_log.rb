require "net/http"
require "logger"
require "benchmark"
require "colorify"

module HttpLog
  DEFAULT_LOGGER  = Logger.new($stdout)
  DEFAULT_OPTIONS = {
    :logger                => DEFAULT_LOGGER,
    :severity              => Logger::Severity::DEBUG,
    :log_connect           => true,
    :log_request           => true,
    :log_headers           => false,
    :log_data              => true,
    :log_status            => true,
    :log_response          => true,
    :log_benchmark         => true,
    :compact_log           => false,
    :url_whitelist_pattern => /.*/,
    :url_blacklist_pattern => nil,
    :color                 => false,
    :status_code_range     => 400..599
  }

  LOG_PREFIX = "[httplog] ".freeze

  class << self
    def options
      @@options ||= DEFAULT_OPTIONS.clone
    end

    def reset_options!
      @@options = DEFAULT_OPTIONS.clone
    end

    def url_approved?(url)
      unless options[:url_blacklist_pattern].nil?
        return false if url.to_s.match(options[:url_blacklist_pattern])
      end

      url.to_s.match(options[:url_whitelist_pattern])
    end

    def attains_severity_level?(response)
      response && options[:status_code_range].cover?(response.code.to_i)
    end

    def log(msg)
      # This builds a hash {0=>:DEBUG, 1=>:INFO, 2=>:WARN, 3=>:ERROR, 4=>:FATAL, 5=>:UNKNOWN}.
      # Courtesy of the delayed_job gem in this commit: 
      # https://github.com/collectiveidea/delayed_job/commit/e7f5aa1ed806e61251bdb77daf25864eeb3aff59
      severities = Hash[*Logger::Severity.constants.enum_for(:each_with_index).collect{ |s, i| [i, s] }.flatten]
      severity = severities[options[:severity]].to_s.downcase
      options[:logger].send(severity, colorize(LOG_PREFIX + msg))
    end

    def log_connection(host, port = nil)
      return if options[:compact_log] || !options[:log_connect]
      log("Connecting: #{[host, port].compact.join(":")}")
    end

    def log_request(method, uri)
      return if options[:compact_log] || !options[:log_request]
      log("Sending: #{method.to_s.upcase} #{uri}")
    end

    def log_headers(headers = {})
      return if options[:compact_log] || !options[:log_headers]
      headers.each do |key,value|
        log("Header: #{key}: #{value}")
      end
    end

    def log_status(status)
      return if options[:compact_log] || !options[:log_status]
      log("Status: #{status}")
    end

    def log_benchmark(seconds)
      return if options[:compact_log] || !options[:log_benchmark]
      log("Benchmark: #{seconds} seconds")
    end

    def log_body(body, encoding = nil, content_type=nil)
      return if options[:compact_log] || !options[:log_response]

      unless text_based?(content_type)
        log("Response: (not showing binary data)")
        return
      end

      if body.is_a?(Net::ReadAdapter)
        # open-uri wraps the response in a Net::ReadAdapter that defers reading
        # the content, so the reponse body is not available here.
        log("Response: (not available yet)")
        return
      end

      if encoding =~ /gzip/
        sio = StringIO.new( body.to_s )
        gz = Zlib::GzipReader.new( sio )
        body = gz.read
      end

      data = utf_encoded(body.to_s, content_type)

      log("Response:\n#{data}")
    end

    def log_data(data)
      return if options[:compact_log] || !options[:log_data]
      data = utf_encoded(data.to_s)
      log("Data: #{data}")
    end

    def log_compact(method, uri, status, seconds)
      return unless options[:compact_log]
      status = Rack::Utils.status_code(status) unless status == /\d{3}/
      log("#{method.to_s.upcase} #{uri} completed with status code #{status} in #{seconds} seconds")
    end

    def colorize(msg)
      return msg unless options[:color]
      Colorify(msg).public_send(options[:color])
    end

    private

    def utf_encoded(data, content_type=nil)
      charset = content_type.to_s.scan(/; charset=(\S+)/).flatten.first || 'UTF-8'
      data.force_encoding(charset) rescue data.force_encoding('UTF-8')
      data.encode('UTF-8', :invalid => :replace, :undef => :replace)
    end

    def text_based?(content_type)
      # This is a very naive way of determining if the content type is text-based; but
      # it will allow application/json and the like without having to resort to more
      # heavy-handed checks.
      content_type =~ /^text/ || 
      content_type =~ /^application/ && content_type != 'application/octet-stream'
    end
  end
end
