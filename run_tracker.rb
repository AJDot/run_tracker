require 'stamp'
require 'yaml'
require 'sinatra'
require 'sinatra/content_for'
require 'tilt/erubis'
require 'pry'

require_relative './run_helpers'
require_relative './database_persistence'

configure do
  enable :sessions
  set :session_secret, 'super secret'
  set :erb, escape_html: true
end

configure(:development) do
  require 'sinatra/reloader'
  also_reload 'run_helpers.rb', 'database_persistence.rb'
end

before do
  # @storage = SessionPersistence.new(session)
  @storage = DatabasePersistence.new
end

def data_path
  if ENV['RACK_ENV'] == 'test'
    File.expand_path('../test/data', __FILE__)
  else
    File.expand_path('../public/data', __FILE__)
  end
end

def user_signed_in?
  session.key?(:username)
end

def require_signed_in_user
  return if user_signed_in?
  session[:error] = 'You must be signed in to do that.'
  redirect '/'
end

def error_for_new_username(username)
  credentials = @storage.load_user_credentials

  if credentials.key?(username)
    "#{username} is already taken."
  elsif !(1..100).cover? username.size
    'Username must be between 1 and 100 characters.'
  end
end

def error_for_new_password(password, password_confirm)
  if password != password_confirm
    'Passwords do not match.'
  elsif password.size < 6
    'Password must be at least 6 characters.'
  end
end

def load_run(id)
  run = @storage.find_run(id)
  return run if run

  session[:error] = 'The specified run was not found.'
  redirect '/'
end

def error_for_name(name, id)
  return 'Must provide a name.' if name.nil?
  all_runs = @storage.all_runs(session[:username])
  if !(1..100).cover? name.size
    'Run name must be between 1 and 100 characters.'
  elsif all_runs.any? { |run| run[:name] == name && run[:id] != id }
    'Run name must be unique.'
  end
end

def error_for_distance(distance)
  return 'Must provide a distance.' if distance.nil?
  return 'Run distance must be greater than 0.' if distance.to_f <= 0.0
end

def error_for_duration(duration)
  return 'Must provide a duration.' if duration.nil?
  durations = duration.split(':').map(&:to_i)
  # matches if duration is in proper format - ##:##:##
  # where each section may contain 1 or 2 digits and the third section
  # must be present.
  if !valid_string?(duration, /\A(\d{1,2}:){0,2}\d{1,2}\z/)
    'Invalid duration format. Must be of the form hh:mm:ss.'
  elsif durations.all?(&:zero?)
    'Must enter a duration greater than 0 seconds.'
  elsif durations.any? { |d| !(0..59).cover? d }
    'Hours, minutes, and seconds must be between 0 and 59.'
  end
end

def error_for_date(date)
  return 'Must provide a date.' if date.nil?
  # Proper date format yyyy-mm-dd
  year = /\A(?:[12]\d{3})/
  month = /(?:0[1-9]|1[0-2])/
  day = /(?:[0-2][0-9]|3[01])\z/
  return if date =~ /#{year}-#{month}-#{day}/x

  'Date must be after 1900 and of the form mm/dd/yyyy.'
end

def error_for_time(time)
  return 'Must provide a time.' if time.nil?
  # Proper time format hh:mm:ss
  valid_format = time =~ /\A(?:[01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]\z/
  return if valid_format

  'Time must be of the form hh:mm:ss.'
end

def error_for_add_run(run)
  error_for_name(run[:name], run[:id]) ||
    error_for_distance(run[:distance]) ||
    error_for_duration(run[:duration]) ||
    error_for_date(run[:date]) ||
    error_for_time(run[:time])
end

def error_for_upload
  if params[:file].nil? ||
     File.extname(params[:file][:tempfile].path) != '.yml'
    return 'Must provide a .yml file for upload.'
  end

  file_location = params[:file][:tempfile].path
  new_runs = YAML.load_file(file_location)

  new_runs.each_with_index do |run, index|
    error = error_for_add_run(run)
    return error + " Fix item ##{index + 1} in file." if error
  end
  nil
end

def valid_string?(string, regex)
  !string[regex].nil?
end

helpers do
  def sort_by_attribute(runs, attribute)
    runs.sort_by { |run| run[attribute] }
  end

  def format_time(duration)
    format('%2d:%02d:%02d', *duration)
  end

  def format_pace(pace)
    format('%2d:%02d', *pace)
  end

  def format_distance(distance)
    format('%.2f', distance)
  end

  def format_duration(duration)
    durations = duration.split(':')
    durations.map! { |d| d.rjust(2, '0') }
    durations.unshift('00') until durations.size == 3
    durations.join(':')
  end
end

# view index page - summary info
get '/' do
  @runs = @storage.all_runs(session[:username])
  erb :index
end

# view signup page
get '/users/signup' do
  erb :signup
end

# signup new user
post '/users/signup' do
  username = params[:username]
  password = params[:password]
  password_confirm = params[:password_confirm]

  signup_error = error_for_new_username(username) ||
                 error_for_new_password(password, password_confirm)
  if signup_error
    status 422
    session[:error] = signup_error
    erb :signup
  else
    @storage.save_user_credentials(username, password)
    session[:success] = 'You are now signed up!'
    redirect '/'
  end
end

# view signin page
get '/users/signin' do
  erb :signin
end

# signin existing user
post '/users/signin' do
  username = params[:username]

  if @storage.valid_credentials?(username, params[:password])
    session[:username] = username
    session[:user_id] = @storage.user_id(username)
    session[:success] = "Welcome, #{username}!"
    redirect '/'
  else
    status 422
    session[:error] = 'Invalid credentials.'
    erb :signin
  end
end

# sign out user
post '/users/signout' do
  session[:success] = "#{session[:username]} has been signed out."
  session.delete(:username)
  redirect '/'
end

# view list of runs
get '/runs' do
  require_signed_in_user
  @runs = @storage.all_runs(session[:username])
  erb :runs
end

# view add new run page
get '/new' do
  require_signed_in_user
  erb :new
end

# add new run
post '/new' do
  require_signed_in_user
  new_run = {
    name:     params[:name].strip,
    distance: params[:distance],
    duration: format_duration(params[:duration]),
    date:     params[:date],
    time:     params[:time],
    user_id:  @storage.user_id(session[:username])
  }

  error = error_for_add_run(new_run)
  if error
    session[:error] = error
    status 422
    erb :new
  else
    @storage.add_run(new_run)
    session[:success] = "#{new_run[:name]} was added."
    redirect '/runs'
  end
end

# view edit run page
get '/runs/:id/edit' do
  require_signed_in_user
  @run = load_run(params[:id].to_i)
  erb :edit
end

# update run
post '/runs/:id' do
  require_signed_in_user
  @run = {
    id:       params[:id].to_i,
    name:     params[:name].strip,
    distance: params[:distance],
    duration: format_duration(params[:duration]),
    date:     params[:date],
    time:     params[:time],
    user_id:  session[:user_id]
  }

  error = error_for_add_run(@run)
  if error
    session[:error] = error
    erb :edit
  else
    @storage.update_run(@run)
    session[:success] = "#{@run[:name]} was updated."
    redirect '/runs'
  end
end

# delete run
post '/runs/:id/delete' do
  require_signed_in_user
  @storage.delete_run(params[:id].to_i)
  session[:success] = "#{params[:name]} was deleted."
  redirect '/runs'
end

# upload runs
post '/upload' do
  require_signed_in_user
  @runs = @storage.all_runs(session[:username])

  error = error_for_upload
  if error
    session[:error] = error
    status 422
    erb :runs
  else
    new_runs = YAML.load_file(params[:file][:tempfile].path)
    @storage.upload_runs(session[:user_id], new_runs)
    session[:success] = "#{params[:file][:filename]} was uploaded."
    redirect '/runs'
  end
end
