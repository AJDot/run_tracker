require 'pry'
class SessionPersistence
  def initialize(session)
    @session = session
    @session[:runs] = if File.exist?(runs_path)
                        YAML.load_file(runs_path)
                      else
                        []
                      end
  end

  def find_run(id)
    @session[:runs].find { |run| run[:id] == id } if id
  end

  def all_runs
    @session[:runs]
  end

  def add_run(new_run)
    new_run[:id] ||= next_id
    @session[:runs] << new_run
  end

  def delete_run(run_to_delete)
    @session[:runs].delete(run_to_delete)
  end

  def save_runs
    File.write(runs_path, @session[:runs].to_yaml)
  end

  def upload_runs(file_location)
    new_runs = YAML.load_file(file_location)
    @session[:runs] += new_runs
    @session[:runs].uniq!
    save_runs
  end

  def credentials_path
    if ENV['RACK_ENV'] == 'test'
      File.expand_path('../test/users.yml', __FILE__)
    else
      File.expand_path('../users.yml', __FILE__)
    end
  end

  def load_user_credentials
    binding.pry
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

  private

  def next_id
    max = @session[:runs].map { |run| run[:id] }.max || 0
    max + 1
  end

  def runs_path
    File.join(data_path, "#{@session[:username]}.yml")
  end
end
