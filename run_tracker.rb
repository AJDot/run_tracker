require 'pry'
require "stamp"
require "yaml"
require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, 'super secret'
end

before do
  session[:runs] = if File.exist?(runs_path)
    YAML.load_file(runs_path)
  else
    []
  end
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../public/data", __FILE__)
  end
end

def runs_path
  File.join(data_path, "runs.yml")
end

def next_id
  max = session[:runs].map { |run| run[:id] }.max || 0
  max + 1
end

def save_runs
  File.write(runs_path, session[:runs].to_yaml)
end

def load_run(id)
  run = session[:runs].find { |run| run[:id] == id } if id
  return run if run

  session[:error] = "The specified run was not found."
  redirect "/"
end

def error_for_name(name, id)
  if !(1..100).cover? name.size
    "Run name must be between 1 and 100 characters."
  elsif session[:runs].any? { |run| (run[:name] == name) && (run[:id] != id) }
    "Run name must be unique."
  end
end

def error_for_distance(distance)
  if distance.to_f <= 0
    "Run distance must be greater than 0."
  end
end

def error_for_duration(duration)
  durations = duration.split(":").map(&:to_i)
  # matches if duration is in proper format - ##:##:##
  # where each section may contain 1 or 2 digits and the third section
  # must be present.
  if !valid_string?(duration, /\A(\d{1,2}:){0,2}\d{1,2}\z/)
    "Invalid duration format. Must be of the form hh:mm:ss."
  elsif durations.all? { |duration| duration == 0}
    "Must enter a duration greater than 0 seconds."
  elsif durations.any? { |duration| !(0..59).cover? duration }
    "Hours, minutes, and seconds must be between 0 and 59."
  end
end

def error_for_date(date)
  # Proper date format yyyy-mm-dd
  unless date =~ /\A(?:[12]\d{3})-          # format year
                (?:0[1-9]|1[0-2])-          # format month
                (?:[0-2][0-9]|3[01])\z/x    # format day
  # unless date =~ /\A\d{4}-\d{2}-\d{2}\z/
    "Date must be after 1900 and of the form mm/dd/yyyy."
  end
end

def error_for_time(time)
  # Proper time format
  unless time =~ /\A(?:[01][0-9]|2[0-4]):[0-5][0-9]\z/
    "Time must be of the form hh:mm AM/PM."
  end
end

def error_for_add_run_form(run)
  error_for_name(run[:name], run[:id]) ||
  error_for_distance(run[:distance]) ||
  error_for_duration(run[:duration]) ||
  error_for_date(run[:date]) ||
  error_for_time(run[:time])
end

def valid_string?(string, regex)
  !string[regex].nil?
end

def format_duration(duration)
  durations = duration.split(":")
  durations.map! do |duration|
    case duration
    when '0'..'9'
      '0' + duration
    else
      duration
    end
  end

  case durations.size
  when 1
    ['00', '00', durations[0]].join(":")
  when 2
    ['00', *durations].join(":")
  when 3
    durations.join(":")
  end
end

def total_distance(runs)
  runs.reduce(0) { |total, run| total + run[:distance].to_f }
end

def total_duration(runs)
  secs_totals = total_secs(runs)
  hours, secs_totals = secs_totals.divmod(3600)
  mins, secs = secs_totals.divmod(60)

  [hours, mins, secs]
end

def total_secs(runs)
  runs.reduce(0) do |total, run|
    total + get_total_secs(run)
  end
end

def get_hour_min_sec(run)
  duration = run[:duration].split(":").map(&:to_i)
  case duration.size
  when 1
    [0, 0, duration[0]]
  when 2
    [0, duration[0], duration[1]]
  when 3
    [duration[0], duration[1], duration[2]]
  end
end

def get_total_secs(run)
  hour_min_sec = get_hour_min_sec(run)
  hour_min_sec[0] * 3600 +
  hour_min_sec[1] * 60 +
  hour_min_sec[2]
end

def pace(run)
  distance = run[:distance]
  duration = get_total_secs(run)

  duration.to_f / 60 / distance
end

def average_pace(runs)
  total_distance = total_distance(runs)
  p total_distance
  secs_totals = runs.reduce(0) do |total, run|
    total + get_total_secs(run)
  end
  p secs_totals

  mins_per_mile = secs_totals.to_f / 60 / total_distance
  mins, secs = mins_per_mile.divmod(1)
  [mins, secs * 60]
end

def average_distance_per_run(runs)
  total_distance(runs).to_f / runs.size
end

def average_duration_per_run(runs)
  average_secs = (total_secs(runs).to_f / runs.size).to_i
  hours, remaining_secs = average_secs.divmod(3600)
  mins, secs = remaining_secs.divmod(60)
  [hours, mins, secs]
end

helpers do
  def sort_by_attribute(runs, attribute)
    runs.sort_by { |run| run[attribute] }
  end

  def format_time(duration)
    format("%2d:%02d:%02d", *duration)
  end

  def format_pace(pace)
    format("%2d:%02d / mile", *pace)
  end

  def format_distance(distance)
    format("%.2f", distance)
  end
end

# view index page - summary info
get "/" do
  @runs = session[:runs]
  erb :index
end

# view list of runs
get "/runs" do
  @runs = session[:runs]
  erb :runs
end

# view add new run page
get "/new" do
  erb :new
end

# add new run
post "/new" do
  new_run = {
    id:       next_id,
    name:     params[:name],
    distance: params[:distance],
    duration: format_duration(params[:duration]),
    date:     params[:date],
    time:     params[:time]
  }

  if error_for_add_run_form(new_run)
    session[:error] = error_for_add_run_form(new_run)
    status 422
    erb :new
  else
    session[:runs] << new_run
    save_runs
    session[:success] = "#{new_run[:name]} was added."
    redirect "/runs"
  end
end

# view edit run page
get "/runs/:id/edit" do
  @run = load_run(params[:id].to_i)
  erb :edit
end

# update run
post "/runs/:id" do
  @run = {
    id:       params[:id].to_i,
    name:     params[:name],
    distance: params[:distance],
    duration: format_duration(params[:duration]),
    date:     params[:date],
    time:     params[:time]
  }

  if error_for_add_run_form(@run)
    session[:error] = error_for_add_run_form(@run)
    erb :edit
  else
    run_to_edit = load_run(params[:id].to_i)
    session[:runs].delete(run_to_edit)
    session[:runs] << @run
    save_runs
    session[:success] = "#{@run[:name]} was updated."
    redirect "/runs"
  end
end

# delete run
post "/runs/:id/delete" do
  run_to_delete = load_run(params[:id].to_i)
  session[:runs].delete(run_to_delete)
  save_runs
  session[:success] = "#{run_to_delete[:name]} was deleted."
  redirect "/runs"
end

# upload runs
post "/upload" do
  if params[:file]
    filename = params[:file][:filename]
    file_location = params[:file][:tempfile].path

    if File.extname(file_location) == ".yml"
      FileUtils.copy(file_location, runs_path)
      session[:success] = "#{filename} was uploaded."
      redirect "/runs"
    else
      @runs = session[:runs]
      session[:error] = "Unable to upload. Currently only .yml files are supported."
      erb :runs
    end
  else
    @runs = session[:runs]
    session[:error] = "Must provide a .yml file for upload."
    erb :runs
  end
end

get '/download/:filename' do
  filename = params[:filename]
  @runs = session[:runs]

  if File.exist?("./public/data/#{filename}")
    send_file "./public/data/#{filename}", :filename => filename, :type => 'Application/octet-stream'
  else
    session[:error] = "There was a problem downloading the data."
    erb :runs
  end
end
