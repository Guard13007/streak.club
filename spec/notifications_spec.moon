import
  load_test_server
  close_test_server
  request
  from require "lapis.spec.server"

db = require "lapis.db"

import truncate_tables from require "lapis.spec.db"

import
  Users
  Notifications
  Submissions from require "models"

factory = require "spec.factory"
import request, request_as from require "spec.helpers"

describe "notifications", ->
  local current_user

  setup ->
    load_test_server!

  teardown ->
    close_test_server!

  before_each ->
    truncate_tables Users, Notifications, Submissions
    current_user = factory.Users!

  it "should create a new notification", ->
    submission = factory.Submissions!
    Notifications\notify_for current_user, submission, "comment"

    notifications = Notifications\select!
    assert.same 1, #notifications
    n = unpack notifications
    assert.same 1, n.count
    assert.same submission.id, n.object_id
    assert.same Notifications.object_types.submission, n.object_type
    assert.same current_user.id, n.user_id

  it "should increment notifications", ->
    submission = factory.Submissions!
    for i=1,5
      Notifications\notify_for current_user, submission, "comment"

    notifications = Notifications\select!
    assert.same 1, #notifications

  it "should not have notifications interfere", ->
    submission = factory.Submissions!
    other_submission = factory.Submissions!
    other_user = factory.Users!

    assert.same "create", Notifications\notify_for current_user, submission, "comment"
    assert.same "create", Notifications\notify_for other_user, submission, "comment"

    assert.same "create", Notifications\notify_for current_user, other_submission, "comment"
    assert.same "create", Notifications\notify_for other_user, other_submission, "comment"

    assert.same "update", Notifications\notify_for current_user, other_submission, "comment"
    assert.same "update", Notifications\notify_for other_user, submission, "comment"

    assert.same 4, #Notifications\select!
    assert.same 6, unpack(db.query "select sum(count) from notifications").sum

  it "should create a new notification after notification has been seen", ->
    submission = factory.Submissions!
    Notifications\notify_for current_user, submission, "comment"
    unpack(Notifications\select!)\update seen: true

    Notifications\notify_for current_user, submission, "comment"


    notifications = Notifications\select!
    assert.same 2, #notifications
