module Feeds
  # Responsible for fetching RSS feeds for multiple users.
  #
  # @see Feeds::Import.call
  class Import
    # Fetch the feeds for the given users (with some filtering based on internal business logic).
    #
    # @param users_scope [ActiveRecord::Relation<User>] the initial scope for determining the users
    #        whose feeds we'll be fetching.
    #
    # @param earlier_than [NilClass, ActiveSupport::TimeWithZone] when given, use this to further
    #        filter the user's who's articles we'll fetch.  That is to say, we won't fetch anyone's
    #        feeds who's last fetch time was after our earlier_than parameter.
    #
    # @param feed_source_ids [Array<Integer>, NilClass] optional explicit feed_source IDs to import.
    #
    # @return [Integer] count of total articles fetched.
    def self.call(users_scope: User, earlier_than: nil, feed_source_ids: nil)
      new(users_scope: users_scope, earlier_than: earlier_than, feed_source_ids: feed_source_ids).call
    end

    def initialize(users_scope: User, earlier_than: nil, feed_source_ids: nil)
      @earlier_than = earlier_than
      @feed_source_ids = Array(feed_source_ids).presence
      @users = filter_users_from(users_scope: users_scope, earlier_than: earlier_than, feed_source_ids: feed_source_ids)

      # NOTE: should these be configurable? Currently they are the result of empiric
      # tests trying to find a balance between memory occupation and speed
      @users_batch_size = 50
    end

    def call
      total_articles_count = 0

      users.in_batches(of: users_batch_size) do |batch_of_users|
        articles = feed_targets_for(batch_of_users).flat_map do |feed_target|
          import_single_feed(feed_target)
        end

        total_articles_count += articles.length

        # we use `feed_fetched_at` to mark the last time a particular user's feed has been fetched, parsed and imported
        batch_of_users.update_all(feed_fetched_at: Time.current)
      end

      total_articles_count
    end

    private

    attr_reader :earlier_than, :users_batch_size, :users, :feed_source_ids

    # @return [ActiveRecord::Relation<User>] you'll likely want to set @users from this, but
    #         [@jeremyf]'s choosing not to do that as it makes the implementation just a bit
    #         cleaner.
    def filter_users_from(users_scope:, earlier_than:, feed_source_ids:)
      users_scope = ArticlePolicy.scope_users_authorized_to_action(users_scope: users_scope, action: :create)

      if feed_source_ids.present?
        return users_scope.where(id: FeedSource.enabled.where(id: feed_source_ids).select(:user_id))
      end

      legacy_scope = users_scope.where(id: Users::Setting.with_feed.select(:user_id))
      multi_scope = users_scope.where(id: FeedSource.enabled.select(:user_id))
      users_scope = legacy_scope.or(multi_scope)

      recent_activity_since = 3.months.ago
      users_scope = users_scope.where("last_article_at >= ? OR last_presence_at >= ?", recent_activity_since,
                                      recent_activity_since)

      return users_scope unless earlier_than

      # Filtering users whose feed hasn't been processed in the last `earlier_than` time span.
      # New users + any user whose feed was processed earlier than the given time
      users_scope.where(feed_fetched_at: nil).or(users_scope.where(feed_fetched_at: ..earlier_than))
    end

    def feed_targets_for(batch_of_users)
      targets = []

      batch_of_users.each do |user|
        if user.setting&.feed_url.present? && feed_source_ids.blank?
          targets << {
            user: user,
            url: user.setting.feed_url,
            feed_source: nil,
            mark_canonical: user.setting.feed_mark_canonical,
            referential_link: user.setting.feed_referential_link,
            fallback_author: user,
            fallback_organization_id: nil
          }
        end

        feed_source_scope = user.feed_sources.enabled
        feed_source_scope = feed_source_scope.where(id: feed_source_ids) if feed_source_ids.present?

        feed_source_scope.find_each do |feed_source|
          targets << {
            user: user,
            url: feed_source.url,
            feed_source: feed_source,
            mark_canonical: feed_source.feed_mark_canonical,
            referential_link: feed_source.feed_referential_link,
            fallback_author: feed_source.effective_fallback_author,
            fallback_organization_id: feed_source.fallback_organization_id
          }
        end
      end

      targets.uniq { |target| [target[:user].id, target[:feed_source]&.id, target[:url]] }
    end

    def import_single_feed(feed_target)
      feed_source = feed_target[:feed_source]
      run = create_import_run(feed_source)

      feed_xml = fetch_feed(feed_target, run)
      return [] if feed_xml.blank?

      feed = parse_feed(feed_target, feed_xml, run)
      return [] if feed.blank?

      create_articles_from_user_feed(feed_target[:user], feed, feed_target: feed_target, run: run)
    ensure
      mark_feed_source_fetched(feed_source)
    end

    def create_import_run(feed_source)
      return unless feed_source

      feed_source.feed_import_runs.create!(user: feed_source.user, status: :processing, started_at: Time.current)
    end

    def fetch_feed(feed_target, run)
      response = HTTParty.get(feed_target[:url].to_s.strip,
                              timeout: 10,
                              headers: { "User-Agent" => "Forem Feeds Importer" })

      response.body
    rescue StandardError => e
      report_error(
        e,
        feeds_import_info: {
          user_id: feed_target[:user].id,
          feed_source_id: feed_target[:feed_source]&.id,
          url: feed_target[:url],
          error: "Feeds::Import::FetchFeedError"
        },
      )
      fail_import_run(run, e)
      nil
    end

    def parse_feed(feed_target, feed_xml, run)
      Feedjira.parse(feed_xml)
    rescue StandardError => e
      report_error(
        e,
        feeds_import_info: {
          user_id: feed_target[:user].id,
          feed_source_id: feed_target[:feed_source]&.id,
          error: "Feeds::Import::ParseFeedError"
        },
      )
      fail_import_run(run, e)
      nil
    end

    # TODO: currently this is exactly as it was in the RssReader, but we might find
    # avenues for optimization, like:
    # 1. why are we sending N exists query to the DB, one per each item, can we fetch them all?
    # 2. should we queue a batch of workers to create articles, but then, following issues ensue:
    # => synchronization on write (table/row locking)
    # => what happens if 2 jobs are in the queue for the same article?
    # => what happens if they stay in the queue for long and the next iteration of the feeds importer starts?
    def create_articles_from_user_feed(user, feed, feed_target:, run:)
      articles = []
      detected_items_count = 0
      skipped_items_count = 0
      failed_items_count = 0
      fallback_author = feed_target[:fallback_author]

      # rubocop:disable Metrics/BlockLength
      feed.entries.reverse_each do |item|
        detected_items_count += 1
        if Feeds::CheckItemMediumReply.call(item)
          skipped_items_count += 1
          track_item(run, feed_target, fallback_author, item, status: :skipped, skip_reason: "medium_reply")
          next
        end
        if Feeds::CheckItemPreviouslyImported.call(item, fallback_author)
          skipped_items_count += 1
          track_item(run, feed_target, fallback_author, item, status: :skipped, skip_reason: "already_imported")
          next
        end

        feed_source_url = item.url.strip.split("?source=")[0]
        article = Article.create!(
          feed_source_url: feed_source_url,
          user_id: fallback_author.id,
          published_from_feed: true,
          show_comments: true,
          body_markdown: Feeds::AssembleArticleMarkdown.call(
            item,
            fallback_author,
            feed,
            feed_source_url,
            mark_canonical: feed_target[:mark_canonical],
            referential_link: feed_target[:referential_link],
          ),
          organization_id: feed_target[:fallback_organization_id],
        )

        subscribe_author_to_comments(fallback_author, article)
        track_item(run, feed_target, fallback_author, item, status: :imported, article: article)
        articles.append(article)
      rescue StandardError => e
        failed_items_count += 1
        track_item(
          run,
          feed_target,
          fallback_author,
          item,
          status: :failed,
          error_message: e.message,
        )
        # TODO: add better exception handling
        report_error(
          e,
          feeds_import_info: {
            username: user.username,
            feed_url: feed_target[:url],
            feed_source_id: feed_target[:feed_source]&.id,
            item_count: item_count_error(feed),
            error: "Feeds::Import::CreateArticleError:#{item.url}"
          },
        )

        next
      end

      if articles.length.positive?
        Slack::WorkflowWebhookWorker.perform_async("Imported #{articles.length} articles for #{user.username}")
      end

      finalize_import_run(
        run,
        detected_items_count: detected_items_count,
        imported_items_count: articles.length,
        skipped_items_count: skipped_items_count,
        failed_items_count: failed_items_count,
      )
      mark_feed_source_imported(feed_target[:feed_source], articles.length)

      articles
      # rubocop:enable Metrics/BlockLength
    end

    def track_item(run, feed_target, fallback_author, item, status:, article: nil, skip_reason: nil, error_message: nil)
      return unless run

      run.feed_import_items.create!(
        user_id: fallback_author.id,
        feed_source_id: feed_target[:feed_source].id,
        article: article,
        external_id: item.entry_id,
        source_url: item.url&.strip,
        title: item.title&.truncate(255),
        status: status,
        skip_reason: skip_reason,
        error_message: error_message,
        published_at: item.published,
      )
    end

    def fail_import_run(run, error)
      return unless run

      run.update!(status: :failed, finished_at: Time.current, error_message: error.message)
      run.feed_source.update_columns(last_error_message: error.message)
    end

    def finalize_import_run(
      run,
      detected_items_count:,
      imported_items_count:,
      skipped_items_count:,
      failed_items_count:
    )
      return unless run

      status = if failed_items_count.positive? && imported_items_count.zero?
                 :failed
               elsif failed_items_count.positive?
                 :partially_succeeded
               else
                 :succeeded
               end

      run.update!(
        status: status,
        finished_at: Time.current,
        detected_items_count: detected_items_count,
        imported_items_count: imported_items_count,
        skipped_items_count: skipped_items_count,
        failed_items_count: failed_items_count,
      )
    end

    def mark_feed_source_fetched(feed_source)
      return unless feed_source

      feed_source.update_columns(last_fetched_at: Time.current)
    end

    def mark_feed_source_imported(feed_source, imported_count)
      return unless feed_source
      return if imported_count.zero?

      feed_source.update_columns(last_imported_at: Time.current, last_error_message: nil)
    end

    def report_error(error, metadata)
      Rails.logger.error(
        "feeds::import::error::#{error.class}::#{metadata.merge(error_message: error.message)}",
      )
    end

    def item_count_error(feed)
      return "NIL FEED, INVALID URL" unless feed

      feed.entries ? feed.entries.length : "no count"
    end

    def subscribe_author_to_comments(user, article)
      NotificationSubscription.create!(
        user: user,
        notifiable_id: article.id,
        notifiable_type: "Article",
        config: "all_comments",
      )
    end
  end
end
