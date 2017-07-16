require 'pry'
require "stamp"
require "yaml"
require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"
require "bcrypt"

require_relative "./run_helpers"

configure do
  enable :sessions
  set :session_secret, 'super secret'
  set :erb, :escape_html => true
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
  File.join(data_path, "#{session[:username]}.yml")
end

def credentials_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end
end

def load_user_credentials
    YAML.load_file(credentials_path) || {}
end

def save_user_credentials(username, password)
  credentials = load_user_credentials
  credentials[username] = BCrypt::Password.create(password).to_s
  File.write(credentials_path, credentials.to_yaml)
end

def valid_credentials?(username, password)
  credentials = load_user_credentials
  if credentials.key?(username)
    bcrypt_password = BCrypt::Password.new(credentials[username])
    bcrypt_password == password
  else
    false
  end
end

def user_signed_in?
  session.key?(:username)
end

def require_signed_in_user
  unless user_signed_in?
    session[:error] = "You must be signed in to do that."
    redirect "/"
  end
end

def error_for_new_username(username)
  credentials = load_user_credentials

  if credentials.key?(username)
    "#{username} is already taken."
  elsif !(1..100).cover? username.size
    "Username must be between 1 and 100 characters."
  end
end

def error_for_new_password(password, password_confirm)
  if password != password_confirm
    "Passwords do not match."
  elsif password.size < 6
    "Password must be at least 6 characters."
  end
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

helpers do
  def sort_by_attribute(runs, attribute)
    runs.sort_by { |run| run[attribute] }
  end

  def format_time(duration)
    format("%2d:%02d:%02d", *duration)
  end

  def format_pace(pace)
    format("%2d:%02d", *pace)
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

# view signup page
get "/users/signup" do
  erb :signup
end

# signup new user
post "/users/signup" do
  username = params[:username]
  password = params[:password]
  password_confirm = params[:password_confirm]

  username_error = error_for_new_username(username)
  password_error = error_for_new_password(password, password_confirm)
  if username_error || password_error
    status 422
    session[:error] = username_error || password_error
    erb :signup
  else
    save_user_credentials(username, password)
    session[:success] = "You are now signed up!"
    redirect "/"
  end
end

# view signin page
get "/users/signin" do
  erb :signin
end

# signin existing user
post "/users/signin" do
  username = params[:username]

  if valid_credentials?(username, params[:password])
    session[:username] = username
    session[:success] = "Welcome, #{username}!"
    redirect "/"
  else
    status 422
    session[:error] = "Invalid credentials."
    erb :signin
  end
end

# sign out user
post "/users/signout" do
  session[:success] = "#{session[:username]} has been signed out."
  session.delete(:username)
  redirect "/"
end

# view list of runs
get "/runs" do
  require_signed_in_user
  @runs = session[:runs]
  erb :runs
end

# view add new run page
get "/new" do
  require_signed_in_user
  erb :new
end

# add new run
post "/new" do
  require_signed_in_user
  new_run = {
    id:       next_id,
    name:     params[:name].strip,
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
  require_signed_in_user
  @run = load_run(params[:id].to_i)
  erb :edit
end

# update run
post "/runs/:id" do
  require_signed_in_user
  @run = {
    id:       params[:id].to_i,
    name:     params[:name].strip,
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
  require_signed_in_user
  run_to_delete = load_run(params[:id].to_i)
  session[:runs].delete(run_to_delete)
  save_runs
  session[:success] = "#{run_to_delete[:name]} was deleted."
  redirect "/runs"
end

# upload runs
post "/upload" do
  require_signed_in_user
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

# download runs as .yml file
get '/download/:filename' do
  require_signed_in_user
  filename = params[:filename]
  @runs = session[:runs]

  if File.exist?("./public/data/#{filename}")
    send_file "./public/data/#{filename}", :filename => "runs.yml", :type => 'text/plain'
  else
    session[:error] = "There was a problem downloading the data."
    erb :runs
  end
end
