module Feeds
  class Import
    def self.call
      new.call
    end

    def initialize
      @rss_feeds = RssFeed.where.not(status: "disabled")
    end

    def call
      total_articles_count = 0

      @rss_feeds.find_in_batches.each do |rss_feeds|
        articles = Parallel.map(rss_feeds, in_threads: 8) do |rss_feed|
          Feeds::ImportFromRssFeed.call(rss_feed)
        end

        total_articles_count += articles.compact.flatten.length
      end

      total_articles_count
    end
  end
end
