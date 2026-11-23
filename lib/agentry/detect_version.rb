# frozen_string_literal: true

module Agentry
  module DetectVersion
    # Gem::Version.new and Gem::Version#release keep every version they build in class variables, for the life of
    # the process: a version read from a header must not reach them, or each new one an attacker sends stays.
    # A subclass skips the first; this #release is RubyGems' own without the second.
    class UncachedVersion < Gem::Version
      def release
        return self unless prerelease?

        self.class.new(segments.take_while { |segment| segment.is_a?(Integer) }.join("."))
      end
    end

    private_constant :UncachedVersion

    private def detect_version?(actual_version, expected_version)
      return true unless expected_version
      return false unless actual_version

      expected_version = parse_version(expected_version)
      actual_version = parse_version(actual_version)

      Cache.requirement(expected_version) { Gem::Requirement.create(expected_version) }
        .satisfied_by?(gem_version(actual_version))
    rescue ArgumentError
      false
    end

    # The last one used: a cached platform asks for the same version on each request, also when Cache keeps none.
    private def gem_version(version)
      string, gem_version = @gem_version
      return gem_version if string == version

      gem_version = Cache.version(version) { UncachedVersion.create(version) }
      @gem_version = [version, gem_version] if version.bytesize <= Cache::MAX_CACHED_VERSION_BYTES
      gem_version
    end

    private def parse_version(version)
      version.is_a?(Numeric) ? version.to_s : version
    end
  end
end
