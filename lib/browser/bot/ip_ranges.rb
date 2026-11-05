# frozen_string_literal: true

require "ipaddr"

module Browser
  class Bot
    # The IP ranges crawler owners publish, from bot_ip_ranges.yml (rewritten
    # weekly by script/sync_ip_ranges.rb) or fetched again by `refresh`.
    module IPRanges
      GOOGLE_RANGES_URL = "https://developers.google.com/static/crawling/ipranges"
      SOURCES = {
        google: {
          keywords: %w[
            adsbot-google apis-google feedfetcher-google google-cloudvertexbot google-inspectiontool
            google-read-aloud google-safety google-site-verification googleagent-urlcontext googlebot
            googleother googleproducer mediapartners-google storebot-google
          ],
          # https://developers.google.com/search/docs/crawling-indexing/verifying-googlebot
          domains: %w[googlebot.com google.com googleusercontent.com],
          urls: %w[common-crawlers.json special-crawlers.json user-triggered-fetchers.json
            user-triggered-fetchers-google.json user-triggered-agents.json].map { |file| "#{GOOGLE_RANGES_URL}/#{file}" }
        },
        bing: {
          keywords: %w[adidxbot bingbot bingpreview microsoftpreview msnbot],
          domains: %w[search.msn.com],
          urls: %w[https://www.bing.com/toolbox/bingbot.json]
        },
        openai: {
          keywords: %w[chatgpt-user gptbot oai-searchbot],
          domains: [],
          urls: %w[https://openai.com/gptbot.json https://openai.com/searchbot.json
            https://openai.com/chatgpt-user.json]
        },
        apple: {
          keywords: %w[applebot],
          domains: %w[applebot.apple.com],
          urls: %w[https://search.developer.apple.com/applebot.json]
        },
        perplexity: {
          keywords: %w[perplexity-user perplexitybot],
          domains: [],
          urls: %w[https://www.perplexity.ai/perplexitybot.json https://www.perplexity.ai/perplexity-user.json]
        },
        duckduckgo: {
          keywords: %w[duckassistbot duckduckbot],
          domains: [],
          urls: %w[https://duckduckgo.com/duckduckbot.json https://duckduckgo.com/duckassistbot.json]
        }
      }.freeze
      FETCH_TIMEOUT_SECONDS = 10
      # Owners move their files: Google's old URLs redirect to the new ones.
      MAX_REDIRECTS = 3
      DNS_TIMEOUT_SECONDS = 2

      # The owner whose crawler the lowercase user agent claims to be.
      def self.owner(ua)
        SOURCES.each_key.find do |owner|
          SOURCES[owner][:keywords].any? { |keyword| ua.include?(keyword) }
        end
      end

      def self.include?(owner, ip)
        address = parse(ip)
        return false unless address

        starts, ends = ranges_by_owner.dig(owner, address.family)
        return false unless starts

        number = address.to_i
        index = (starts.bsearch_index { |start| start > number } || starts.size) - 1
        index >= 0 && number <= ends[index]
      end

      # Google's documented method: the reverse lookup names one of the owner's
      # domains, and that name resolves back to the IP. Two DNS queries.
      def self.verified_by_dns?(owner, ip)
        address = parse(ip)
        domains = SOURCES.dig(owner, :domains)
        return false unless address && domains&.any?

        require "resolv"
        Resolv::DNS.open do |dns|
          dns.timeouts = DNS_TIMEOUT_SECONDS
          host = dns.getname(address.to_s).to_s.downcase
          domains.any? { |domain| host == domain || host.end_with?(".#{domain}") } &&
            dns.getaddresses(host).any? { |resolved| IPAddr.new(resolved.to_s) == address }
        end
      rescue Resolv::ResolvError, Resolv::ResolvTimeout, SystemCallError
        false
      end

      # Prefixes ("66.249.64.0/27"), keyed by owner.
      def self.prefixes_by_owner
        @prefixes_by_owner ||= Browser.load_data("bot_ip_ranges").transform_keys(&:to_sym)
      end

      def self.ranges_by_owner
        @ranges_by_owner ||= build_ranges(prefixes_by_owner)
      end

      # For long-lived processes: fetches every owner's ranges again and swaps
      # them in at once. Raises Browser::Error and keeps the current ranges when
      # a source fails.
      def self.refresh
        load(fetch)
      end

      def self.load(prefixes_by_owner)
        ranges_by_owner = build_ranges(prefixes_by_owner)
        @prefixes_by_owner = prefixes_by_owner
        @ranges_by_owner = ranges_by_owner
      end

      def self.fetch
        SOURCES.to_h do |owner, source|
          addresses = source[:urls].flat_map { |url| fetch_prefixes(url) }.map do |prefix|
            IPAddr.new(prefix)
          rescue ArgumentError
            raise Error, "#{owner}: invalid prefix #{prefix.inspect}"
          end
          sorted = addresses.uniq.sort_by { |address| [address.family, address.to_i, address.prefix] }
          [owner, sorted.map { |address| "#{address}/#{address.prefix}" }]
        end
      end

      def self.fetch_prefixes(url)
        require "json"
        require "net/http"
        uri = URI(url)
        response = nil
        (MAX_REDIRECTS + 1).times do
          response = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
            open_timeout: FETCH_TIMEOUT_SECONDS, read_timeout: FETCH_TIMEOUT_SECONDS) do |http|
            http.get(uri.request_uri, "User-Agent" => "Agentry/#{VERSION} (+https://github.com/levups/agentry)")
          end
          break unless response.is_a?(Net::HTTPRedirection)

          uri = uri.merge(response["Location"])
        end
        raise Error, "#{url}: HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

        prefixes = JSON.parse(response.body).fetch("prefixes").map do |prefix|
          prefix["ipv4Prefix"] || prefix["ipv6Prefix"]
        end
        raise Error, "#{url}: no prefixes" if prefixes.empty?

        prefixes
      rescue JSON::ParserError, KeyError, Timeout::Error, IOError, SystemCallError, OpenSSL::SSL::SSLError => exception
        raise Error, "#{url}: #{exception.message}"
      end

      # Per owner and address family, the merged ranges as two sorted arrays of
      # integers, first and last addresses, for a binary search.
      def self.build_ranges(prefixes_by_owner)
        prefixes_by_owner.to_h do |owner, prefixes|
          ranges_by_family = prefixes.map { |prefix| IPAddr.new(prefix) }.group_by(&:family)
          [owner.to_sym, ranges_by_family.transform_values { |addresses| merge(addresses) }]
        end
      end

      def self.merge(addresses)
        ranges = addresses.map do |address|
          range = address.to_range
          [range.begin.to_i, range.end.to_i]
        end
        ranges.sort!
        starts = []
        ends = []
        ranges.each do |first, last|
          if ends.any? && first <= ends.last + 1
            ends[-1] = last if last > ends.last
          else
            starts << first
            ends << last
          end
        end
        [starts, ends]
      end

      # A forged or malformed X-Forwarded-For must not raise in a request.
      def self.parse(ip)
        ip = ip.to_s
        return if ip.include?("/")

        address = IPAddr.new(ip)
        address.ipv4_mapped? ? address.native : address
      rescue ArgumentError
        nil
      end

      private_class_method :fetch_prefixes, :build_ranges, :merge, :parse
    end
  end
end
