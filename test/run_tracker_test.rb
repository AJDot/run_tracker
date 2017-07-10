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
    File.write(runs_path, "---\n")
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

  def add_run_to_file(name, distance, duration, date, time)
    run_data = {name: name, distance: distance, duration: duration, date: date, time: time}
    session[:runs] << run_data
    File.write(runs_path, session[:runs].to_yaml)
  end

  def test_index
    get "/"

    assert_equal 200, last_response.status
    assert_includes last_response.body, '<table'
    assert_includes last_response.body, 'Total Miles'
  end

  def test_viewing_view_runs
    get "/"
    add_run_to_file('run1', '1', '01:02:03', '2017-07-10', '17:15')

    get "/list"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "Name</h3>"

  end
end
