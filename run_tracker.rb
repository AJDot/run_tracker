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
    File.expand_path("../data", __FILE__)
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

def sort_by_attribute(runs, attribute)
  runs.sort_by { |run| run[attribute] }
end

def error_for_name(name)
  if !(1..100).cover? name.size
    "Run name must be between 1 and 100 characters."
  elsif session[:runs].any? { |run| run[:name] == name }
    "Run name must be unique."
  end
end

def error_for_distance(distance)
  if distance.to_f <= 0
    "Run distance must be greater the 0."
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
  # Proper date format
  unless date =~ /\A\d{4}-\d{2}-\d{2}\z/
    "Date must be of the form mm/dd/yyyy."
  end
end

def error_for_time(time)
  # Proper time format
  unless time =~ /\A(?:[01][0-9]|2[0-4]):[0-5][0-9]\z/
    "Time must be of the form hh:mm AM/PM."
  end
end

def error_for_add_run_form(run)
  error_for_name(run[:name]) ||
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
  durations.join(":")
end

get "/" do
  erb :index
end

get "/list" do
  @runs = session[:runs]
  erb :list
end

get "/add" do
  erb :add
end

post "/add" do
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
    erb :add
  else
    session[:runs] << new_run
    save_runs
    session[:success] = "#{new_run[:name]} was added."
    redirect "/list"
  end
end

post "/:id/delete" do
  run_to_delete = session[:runs].find { |run| run[:id] == params[:id].to_i }
  session[:runs].delete(run_to_delete)
  save_runs
  session[:success] = "#{run_to_delete[:name]} was deleted."
  redirect "/list"
end
