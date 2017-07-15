ENV["RACK_ENV"] = "test"

require "fileutils"

require "rack/test"
require 'minitest/autorun'
require 'minitest/reporters'
Minitest::Reporters.use!

require_relative "../run_tracker"

class RunTrackerTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    # create data directory
    FileUtils.mkdir_p(File.join(data_path))
    # create users.yml for testing
    File.write(credentials_path, "---")
    save_user_credentials("admin", "secret")
  end

  def teardown
    # delete data directory
    FileUtils.rm_rf(data_path)
    # delete credentials file
    FileUtils.rm(credentials_path)
  end

  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def tempfile(name)
    Rack::Test::UploadedFile.new(File.join(data_path, name))
  end

  def session
    last_request.env["rack.session"]
  end

  def admin_session
    { "rack.session" => { username: "admin"} }
  end

  def test_viewing_index
    get "/", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Run Tracker'
    assert_includes last_response.body, 'Total Miles'
  end

  def test_viewing_new_run
    get "/new", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, %q(<input name="distance")
    assert_includes last_response.body, %q(<input type="submit")
  end

  def test_add_and_save_new_run
    post "/new", { name: "test_run", distance: "10", duration: "01:02:00", date: "2017-07-10", time: "14:00" }, admin_session

    assert_equal [{ id: 1, name: "test_run", distance: "10", duration: "01:02:00", date: "2017-07-10", time: "14:00" }], session[:runs]
    assert_equal File.open(runs_path).read, <<~RUNS
      ---
      - :id: 1
        :name: test_run
        :distance: '10'
        :duration: '01:02:00'
        :date: '2017-07-10'
        :time: '14:00'
    RUNS

    assert_equal "test_run was added.", session[:success]
  end

  def test_add_run_without_name
    post "/new", { name: "", distance: "10", duration: "01:02:00", date: "2017-07-10", time: "14:00" }, admin_session

    assert_equal 422, last_response.status
    assert_includes last_response.body, "Run name must be between 1 and 100 characters."
  end

  def test_add_run_with_existing_name
    post "/new", { name: "test_run", distance: "10", duration: "01:02:00", date: "2017-07-10", time: "14:00" }, admin_session
    post "/new", { name: "test_run", distance: "10", duration: "01:02:00", date: "2017-07-10", time: "14:00" }

    assert_equal 422, last_response.status
    assert_includes last_response.body, "Run name must be unique."
  end

  def test_add_run_with_non_positive_distance
    post "/new", { name: "test_run", distance: "0", duration: "01:02:00", date: "2017-07-10", time: "14:00" }, admin_session

    assert_equal 422, last_response.status
    assert_includes last_response.body, "Run distance must be greater than 0."
  end

  def test_add_run_with_invalid_format_duration
    post "/new", { name: "test_run", distance: "10", duration: "011:02:00", date: "2017-07-10", time: "14:00" }, admin_session

    assert_equal 422, last_response.status
    assert_includes last_response.body, "Invalid duration format. Must be of the form hh:mm:ss."

    post "/new", { name: "test_run", distance: "10", duration: "bad_duration", date: "2017-07-10", time: "14:00" }

    assert_equal 422, last_response.status
    assert_includes last_response.body, "Invalid duration format. Must be of the form hh:mm:ss."
  end

  def test_add_run_with_zero_duration
    post "/new", { name: "test_run", distance: "10", duration: "0", date: "2017-07-10", time: "14:00" }, admin_session

    assert_equal 422, last_response.status
    assert_includes last_response.body, "Must enter a duration greater than 0 seconds."
  end

  def test_add_run_with_out_of_range_duration
    post "/new", { name: "test_run", distance: "10", duration: "75:00", date: "2017-07-10", time: "14:00" }, admin_session

    assert_equal 422, last_response.status
    assert_includes last_response.body, "Hours, minutes, and seconds must be between 0 and 59."
  end

  def test_add_run_with_invalid_format_date
    post "/new", { name: "test_run", distance: "10", duration: "1:00:00", date: "invalid_date", time: "14:00" }, admin_session

    assert_equal 422, last_response.status
    assert_includes last_response.body, "Date must be after 1900 and of the form mm/dd/yyyy."

    post "/new", { name: "test_run", distance: "10", duration: "1:00:00", date: "2017-14-10", time: "14:00" }

    assert_equal 422, last_response.status
    assert_includes last_response.body, "Date must be after 1900 and of the form mm/dd/yyyy."
  end

  def test_add_run_with_invalid_format_time
    post "/new", { name: "test_run", distance: "10", duration: "1:00:00", date: "2017-07-10", time: "00" }, admin_session

    assert_equal 422, last_response.status
    assert_includes last_response.body, "Time must be of the form hh:mm AM/PM."

    post "/new", { name: "test_run", distance: "10", duration: "1:00:00", date: "2017-07-10", time: "25:00" }

    assert_equal 422, last_response.status
    assert_includes last_response.body, "Time must be of the form hh:mm AM/PM."
  end

  def test_viewing_view_runs
    post "/new", { name: "test_run", distance: "10", duration: "01:02:00", date: "2017-07-10", time: "14:00" }, admin_session

    get last_response["Location"]

    assert_equal 200, last_response.status
    assert_includes last_response.body, "Name"
    assert_includes last_response.body, "test_run"
  end

  def test_viewing_edit_run
    post "/new", { name: "test_run", distance: "10", duration: "01:02:00", date: "2017-07-10", time: "14:00" }, admin_session

    get "/runs/1/edit"

    assert_includes last_response.body, "test_run"
    assert_includes last_response.body, %q(value="Edit")
  end

  def test_edit_run
    post "/new", { name: "test_run", distance: "10", duration: "01:02:00", date: "2017-07-10", time: "14:00" }, admin_session

    post "/runs/1", { name: "name_changed", distance: "10", duration: "01:02:00", date: "2017-07-10", time: "14:00" }

    assert_equal File.open(runs_path).read, <<~RUNS
      ---
      - :id: 1
        :name: name_changed
        :distance: '10'
        :duration: '01:02:00'
        :date: '2017-07-10'
        :time: '14:00'
    RUNS

    assert_equal "name_changed was updated.", session[:success]
  end

  def test_delete_run
    post "/new", { name: "test_run", distance: "10", duration: "01:02:00", date: "2017-07-10", time: "14:00" }, admin_session

    post "/runs/1/delete"

    assert_equal File.open(runs_path).read, <<~RUNS
      --- []
    RUNS

    assert_equal "test_run was deleted.", session[:success]
  end

  def test_upload_file
    runs = <<~RUNS
      ---
      - :id: 1
        :name: test_run
        :distance: '10'
        :duration: '01:02:00'
        :date: '2017-07-10'
        :time: '14:00'
    RUNS
    create_document("runs_to_upload.yml", runs)

    post "/upload", { file: tempfile("runs_to_upload.yml") }, admin_session

    assert_equal "runs_to_upload.yml was uploaded.", session[:success]
  end

  def test_upload_file_unsupported_format
    create_document("runs_to_upload.unknown")

    post "/upload", { file: tempfile("runs_to_upload.unknown") }, admin_session

    assert_includes last_response.body, "Unable to upload. Currently only .yml files are supported."
  end

  def test_upload_file_without_file_selected
    post "/upload", {}, admin_session

    assert_includes last_response.body, "Must provide a .yml file for upload."
  end
end
