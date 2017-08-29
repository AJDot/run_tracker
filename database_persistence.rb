require 'pg'
require 'bcrypt'

class DatabasePersistence
  def initialize
    @db = if Sinatra::Base.production?
            PG.connect(ENV['DATABASE_URL'])
          else
            PG.connect(dbname: 'run_tracker')
          end
  end

  def disconnect
    @db.close
  end

  def query(statement, *params)
    @db.exec_params(statement, params)
  end

  def find_run(id)
    sql = 'SELECT * FROM runs WHERE id = $1'
    result = query(sql, id)

    tuple_to_run_hash(result.first)
  end

  def all_runs(username)
    sql = 'SELECT * FROM runs WHERE user_id = $1'
    result = query(sql, user_id(username))
    return [] if result.ntuples == 0

    result.map do |tuple|
      tuple_to_run_hash(tuple)
    end
  end

  def add_run(new_run)
    sql = <<~SQL
      INSERT INTO runs (name, distance, duration, date, time, user_id)
        VALUES ($1, $2, $3, $4, $5, $6);
    SQL

    query(sql, *run_hash_to_ordered_array(new_run)[1..-1])
  end

  def update_run(run)
    sql = <<~SQL
      UPDATE runs SET
        name = $2,
        distance = $3,
        duration = $4,
        date = $5,
        time = $6
      WHERE user_id = $7 AND id = $1
    SQL
    query(sql, *run_hash_to_ordered_array(run))
  end

  def delete_run(run_id)
    query('DELETE FROM runs WHERE id = $1', run_id)
  end

  def upload_runs(user_id, new_runs)
    new_runs.each { |run| run[:user_id] = user_id }
    new_runs.each do |run|
      run[:user_id] = user_id
      add_run(run)
    end
  end

  def load_user_credentials
    sql = 'SELECT * FROM users'
    result = query(sql)
    result.each_with_object({}) do |tuple, hash|
      hash[tuple['name']] = tuple['password']
    end
  end

  def save_user_credentials(username, password)
    sql = 'INSERT INTO users (name, password) VALUES ($1, $2);'
    bcrypt_password = BCrypt::Password.create(password).to_s
    query(sql, username, bcrypt_password)
  end

  def valid_credentials?(username, password)
    credentials = load_user_credentials
    return false unless credentials.key?(username)

    bcrypt_password = BCrypt::Password.new(credentials[username])
    bcrypt_password == password
  end

  def user_id(username)
    sql = 'SELECT id FROM users WHERE name = $1 LIMIT 1'
    result = query(sql, username)
    return unless result.first
    result.first['id'].to_i
  end

  private

  def tuple_to_run_hash(tuple)
    {
      id: tuple['id'].to_i,
      name: tuple['name'],
      distance: tuple['distance'].to_f,
      duration: tuple['duration'],
      date: tuple['date'],
      time: tuple['time'],
      user_id: tuple['user_id']
    }
  end

  def run_hash_to_ordered_array(run_hash)
    [
      run_hash[:id],
      run_hash[:name],
      run_hash[:distance],
      run_hash[:duration],
      run_hash[:date],
      run_hash[:time],
      run_hash[:user_id]
    ]
  end
end
