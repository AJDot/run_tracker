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
    # File.write(runs_path, "---\n")
  end

  def teardown
    # delete data directory
    FileUtils.rm_rf(data_path)
  end

  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def session
    last_request.env["rack.session"]
  end

  def add_run_to_file(id, name, distance, duration, date, time)
    run_data = {id: id, name: name, distance: distance, duration: duration, date: date, time: time}
    if session[:runs]
      session[:runs] << run_data
    else
      session[:runs] = [run_data]
    end
    File.write(runs_path, session[:runs].to_yaml)
  end

  def test_index
    get "/"

    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Run Tracker'
    assert_includes last_response.body, 'Total Miles'
  end

  def test_viewing_new_run
    get "/new"

    assert_equal 200, last_response.status
    assert_includes last_response.body, %q(<input name="distance")
    assert_includes last_response.body, %q(<input type="submit")
  end

  def test_add_and_save_new_run
    post "/new", { name: "test_run", distance: "10", duration: "01:02:00", date: "2017-07-10", time: "14:00" }

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
  end

  def test_add_run_without_name

  end

  def test_add_run_with_existing_name

  end

  def test_add_run_with_negative_distance

  end

  def test_add_run_with_invalid_format_duration

  end

  def test_add_run_with_zero_duration

  end

  def test_add_run_with_out_of_range_duration

  end

  def test_add_run_with_invalid_format_date

  end

  def test_add_run_with_invlaid_format_time

  end

  def test_viewing_view_runs
    post "/new", { name: "test_run", distance: "10", duration: "01:02:00", date: "2017-07-10", time: "14:00" }

    get last_response["Location"]

    assert_equal 200, last_response.status
    assert_includes last_response.body, "Name"
    assert_includes last_response.body, "test_run"
  end
end
