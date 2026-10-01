# frozen_string_literal: true

module ::DiscourseSmartSearch
  # Synonym lookup with two backends, consulted in order:
  #
  #   1. YAML overlay (`config/dictionaries/smart_search_synonyms.yml`)
  #      — small, hand-curated tech-jargon dictionary. Catches the
  #      domain-specific terms WordNet doesn't know (js, k8s, postgres,
  #      docker, etc.). ~30 entries, lowercase ASCII, symmetric groups.
  #
  #   2. WordNet via the `rwordnet` gem — pure-Ruby interface that
  #      ships the WordNet lexical DB (~117K English words, ~8MB)
  #      bundled inside the gem. Covers general English (bug ↔ defect
  #      ↔ glitch, fast ↔ quick ↔ rapid, …) so we don't hand-curate it.
  #
  #   3. Spanish synonym groups (`config/dictionaries/smart_search_synonyms_es.txt`,
  #      from the Open Multilingual Wordnet, CC BY 3.0). Accent-insensitive.
  #      Used instead of WordNet when the request locale is Spanish.
  #
  # Either backend's failure is non-fatal: a missing gem, a missing/
  # malformed YAML, or a WordNet lookup raise all degrade silently to
  # "just the input word" — search then behaves like vanilla Discourse.
  # The fallback contract documented at the top of
  # `lib/discourse_smart_search/search_extension.rb` depends on it.
  #
  # An in-memory LRU cache (default 2000 entries per site) protects
  # against repeated lookups.
  module Synonyms
    DEFAULT_PATH =
      ::File.expand_path("../../config/dictionaries/smart_search_synonyms.yml", __dir__)
    SPANISH_PATH =
      ::File.expand_path("../../config/dictionaries/smart_search_synonyms_es.txt", __dir__)

    CACHE_LIMIT = 2000

    # Hard cap on synonyms returned per lookup. Prevents a runaway
    # WordNet expansion (a polysemous word like "set" has 50+ synonyms
    # across all senses) from blowing up variant generation.
    MAX_SYNONYMS_PER_WORD = 20

    class << self
      # Returns the synonym set for `word`, including the word itself.
      # Empty array for blank input; `[word]` when no synonyms exist.
      def for(word)
        return [] if word.blank?
        key = word.to_s.downcase.strip
        return [] if key.empty?

        spanish = spanish?
        cache_key = "#{spanish ? "es" : "en"}:#{key}"
        cached = cache[cache_key]
        return cached if cached

        result = lookup_uncached(key, spanish)
        cache_set(cache_key, result)
        result
      end

      # Discourse sets I18n.locale per request: the user's own language when
      # users may pick one, the site default otherwise.
      def spanish?
        ::I18n.locale.to_s.start_with?("es")
      end

      # Clears the cached dictionary; the next lookup re-reads it.
      def reload!
        @indexes = {}
        @cache = {}
        nil
      end

      # The shipped dictionary plus this site's smart_search_extra_synonyms,
      # built once per site and setting value, so every process (web and
      # Sidekiq alike) and every site on a multisite picks up a change on
      # its next search.
      def overlay_index
        extras = extra_groups_setting
        key = [current_db, extras]
        @indexes ||= {}
        @indexes[key] ||= begin
          @indexes.clear if @indexes.size > 50
          build_index(shipped_groups + parse_extra_groups(extras))
        end
      end

      # True when the rwordnet backend is available + DB loaded.
      # Memoized after the first call.
      def wordnet_available?
        return @wordnet_available unless @wordnet_available.nil?
        @wordnet_available =
          begin
            require "rwordnet"
            # Touch the DB once to surface any startup failure here
            # rather than on the first user search.
            ::WordNet::Lemma.find_all("test")
            true
          rescue StandardError, ::LoadError => e
            ::Rails.logger.warn(
              "[smart-search] WordNet backend unavailable: #{e.class}: #{e.message}",
            )
            false
          end
      end

      private

      def lookup_uncached(key, spanish)
        # 1. Overlay (curated tech jargon, plus this site's own groups).
        hit = overlay_index[key]
        return hit if hit

        # 2. The searcher's language only — never mix dictionaries.
        found = spanish ? spanish_synonyms_for(key) : wordnet_synonyms_for(key)
        return found if found.size > 1

        # 3. Default — just the word itself.
        [key].freeze
      end

      # The file lists groups smallest first (the precise senses), so each
      # word's groups arrive already in that order.
      def spanish_synonyms_for(key)
        groups = spanish_index[unaccent(key)]
        return [] unless groups
        ([key] + groups.flatten).uniq.first(MAX_SYNONYMS_PER_WORD).freeze
      end

      def spanish_index
        @spanish_index ||=
          begin
            index = Hash.new { |h, k| h[k] = [] }
            ::File.foreach(SPANISH_PATH, chomp: true) do |line|
              next if line.empty? || line.start_with?("#")
              words = line.split(",").freeze
              words.each { |w| index[unaccent(w)] << words }
            end
            index.default_proc = nil
            index
          rescue StandardError => e
            ::Rails.logger.warn(
              "[smart-search] Spanish dictionary unavailable: #{e.class}: #{e.message}",
            )
            {}
          end
      end

      # Spanish accents only: plain tr is far cheaper than transliterate when
      # indexing ~70k words on first use.
      def unaccent(word)
        return word.downcase if word.ascii_only?
        word.downcase.tr("áéíóúüñàèìòù", "aeiouunaeiou")
      end

      def wordnet_synonyms_for(key)
        return [] unless wordnet_available?

        # IMPORTANT: do NOT sort alphabetically. WordNet returns
        # synsets in approximate frequency-of-use order — the FIRST
        # synset for "bug" is the insect sense, but the third/fourth
        # synsets contain the "defect/glitch/fault" senses that a
        # tech-forum user actually wants. Alphabetical sort would put
        # "badger" first (an annoy-verb peer of "bug"), which is
        # nonsense as a search expansion. Preserve insertion order so
        # the variant generator picks a synonym from a sense WordNet
        # thinks is common. Words a user really cares about should
        # also be hand-overridden in the YAML overlay anyway.
        synonyms = [key]
        seen = Set.new([key])
        # rwordnet API: `Lemma.find_all(word)` returns one Lemma per
        # part of speech the word appears as (noun, verb, adj, adv).
        # Each Lemma has `synsets` (senses); each Synset has `words`
        # (the canonical synonym list for that sense).
        ::WordNet::Lemma
          .find_all(key)
          .each do |lemma|
            lemma.synsets.each do |synset|
              synset.words.each do |w|
                # Skip multi-word entries ("side_by_side") and strip
                # WordNet's adjective markers ("future(a)").
                word = w.to_s.sub(/\([a-z]+\)\z/, "")
                next if word.include?("_")
                normalized = word.downcase.strip
                next unless normalized.length.between?(2, 60)
                next if seen.include?(normalized)
                seen << normalized
                synonyms << normalized
                break if synonyms.size >= MAX_SYNONYMS_PER_WORD
              end
              break if synonyms.size >= MAX_SYNONYMS_PER_WORD
            end
            break if synonyms.size >= MAX_SYNONYMS_PER_WORD
          end
        synonyms.freeze
      rescue StandardError => e
        ::Rails.logger.warn(
          "[smart-search] WordNet lookup failed for #{key.inspect}: " \
            "#{e.class}: #{e.message}",
        )
        []
      end

      # Lazily-allocated LRU cache, per site (sites can have different
      # extra synonyms). Hash insertion order is the LRU primitive —
      # `shift` removes the oldest entry.
      def cache
        @cache ||= {}
        @cache[[current_db, extra_groups_setting]] ||= {}
      end

      def cache_set(key, value)
        c = cache
        c.delete(key) if c.key?(key)
        c[key] = value
        c.shift while c.size > CACHE_LIMIT
        value
      end

      def current_db
        defined?(::RailsMultisite) ? ::RailsMultisite::ConnectionManagement.current_db : "default"
      end

      def extra_groups_setting
        ::SiteSetting.smart_search_extra_synonyms.to_s
      rescue StandardError
        ""
      end

      # "a,b|c,d" → [["a", "b"], ["c", "d"]]
      def parse_extra_groups(value)
        value
          .split("|")
          .map { |row| row.split(",").map(&:strip).reject(&:empty?) }
          .select { |group| group.size >= 2 }
      end

      def shipped_groups
        @shipped_groups ||= load_groups(DEFAULT_PATH).freeze
      end

      def load_groups(path)
        return [] unless ::File.exist?(path)
        raw = ::YAML.safe_load(::File.read(path)) || []
        return [] unless raw.is_a?(Array)
        raw.select { |g| g.is_a?(Array) && g.size >= 2 }
      rescue StandardError => e
        ::Rails.logger.warn(
          "[smart-search] dictionary load failed for #{path}: #{e.class}: #{e.message}",
        )
        []
      end

      # word → [word, *its synonyms in the order the groups list them].
      # Order matters: the query expander swaps in the first synonym, so the
      # dictionary's first-listed (clearest) term wins.
      def build_index(groups)
        table = {}
        groups.each do |group|
          normalized = group.map { |w| w.to_s.downcase.strip }.reject(&:empty?).uniq
          next if normalized.size < 2
          normalized.each { |w| (table[w] ||= [w]).concat(normalized - [w]) }
        end
        table.transform_values { |v| v.uniq.freeze }.freeze
      end
    end
  end
end
