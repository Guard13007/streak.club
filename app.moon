lapis = require "lapis"

import Users from require "models"
import generate_csrf from require "helpers.csrf"

import require_login, not_found, ensure_https from require "helpers.app"

date = require "date"
config = require("lapis.config").get!

class extends lapis.Application
  layout: require "views.layout"

  cookie_attributes: =>
    expires = date(true)\adddays(365)\fmt "${http}"
    "Expires=#{expires}; Path=/; HttpOnly"

  @enable "exception_tracking"

  @include "applications.users"
  @include "applications.streaks"
  @include "applications.submissions"
  @include "applications.uploads"
  @include "applications.admin"
  @include "applications.api"
  @include "applications.search"

  @before_filter =>
    @current_user = Users\read_session @
    generate_csrf @

    if @current_user
      @current_user\update_last_active!
      @global_notifications = @current_user\unseen_notifications!

    if @session.flash
      @flash = @session.flash
      @session.flash = false

  "/console": require"lapis.console".make!

  handle_404: => not_found

  [index: "/"]: ensure_https =>
    if @current_user
      @created_streaks = @current_user\find_hosted_streaks!\get_page!
      @active_streaks = @current_user\find_participating_streaks(state: "active")\get_page!

      render: "index_logged_in"
    else
      import FeaturedStreaks, FeaturedSubmissions, Streaks, Users from require "models"
      featured = FeaturedStreaks\select "order by position desc limit 4"

      Streaks\include_in featured, "streak_id"
      @featured_streaks = [f.streak for f in *featured]
      Users\include_in @featured_streaks, "user_id"

      @mobile_friendly = true

      @featured_submissions = FeaturedSubmissions\find_submissions!\get_page!

      -- filter out things that don't have image
      @featured_submissions = for sub in *@featured_submissions
        has_image = false
        for upload in *sub.uploads
          has_image = true if upload\is_image!
          break if has_image

        continue unless has_image
        sub

      render: "index_logged_out"

  [notifications: "/notifications"]: require_login =>
    import Notifications from require "models"

    @old_notifications = Notifications\select "
      where user_id = ? and seen
      order by id desc
      limit 10
    ", @current_user.id

    all = {}

    for n in *@global_notifications
      table.insert all, n

    for n in *@old_notifications
      table.insert all, n

    Notifications\preload_objects all

    for n in *@global_notifications
      n\mark_seen!

    render: true

  [following_feed: "/feed"]: require_login =>
    import Submissions from require "models"
    @pager = @current_user\find_follower_submissions {
      per_page: 25
      prepare_results: (...) ->
        Submissions\preload_for_list ..., {
          likes_for: @current_user
        }
    }
    @submissions = @pager\get_page!
    render: true

  [terms: "/terms"]: =>
    render: true

  [privacy_policy: "/privacy-policy"]: =>
    render: true

  [stats: "/stats"]: =>
    import Submissions, Streaks, SubmissionComments, SubmissionLikes from require "models"

    @graph_type = @params.graph_type or "cumulative"

    import cumulative_created, daily_created from require "helpers.stats"

    switch @graph_type
      when "cumulative"
        @graph_users = cumulative_created Users
        @graph_streaks = cumulative_created Streaks

        @graph_submissions = cumulative_created Submissions
        @graph_submission_comments = cumulative_created SubmissionComments
        @graph_submission_likes = cumulative_created SubmissionLikes
      when "daily"
        @graph_users = daily_created Users
        @graph_streaks = daily_created Streaks

        @graph_submissions = daily_created Submissions
        @graph_submissions_comments = daily_created SubmissionComments
        @graph_submissions_likes = daily_created SubmissionLikes
      else
        return not_found

    render: true

