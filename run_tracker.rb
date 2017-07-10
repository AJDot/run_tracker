require 'pry'
require "stamp"
require "yaml"
require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, 'super secret'
end

before do
  session[:runs] = YAML.load_file(runs_path) || []
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
  # session[:runs] ||= []
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
  name = params[:name]
  distance = params[:distance]
  duration = format_duration(params[:duration])
  date = params[:date]
  time = params[:time]


  name_error = error_for_name(name)
  distance_error = error_for_distance(distance)
  duration_error = error_for_duration(duration)

  if name_error || distance_error || duration_error
    session[:error] = name_error || distance_error || duration_error
    erb :add
  else
    session[:runs] << { id: next_id, name: name, distance: distance, duration: duration, date: date, time: time };
    save_runs
    redirect "/list"
  end
end
