def no_runs?(runs)
  runs.size.zero?
end

def total_distance(runs)
  return 0.0 if no_runs?(runs)
  runs.reduce(0) { |total, run| total + run[:distance].to_f }
end

def total_duration(runs)
  return [0, 0, 0] if no_runs?(runs)

  secs_totals = total_secs(runs)
  hours, secs_totals = secs_totals.divmod(3600)
  mins, secs = secs_totals.divmod(60)

  [hours, mins, secs]
end

def total_secs(runs)
  return 0 if no_runs?(runs)
  runs.reduce(0) do |total, run|
    total + get_total_secs(run)
  end
end

def get_hour_min_sec(run)
  duration = run[:duration].split(':').map(&:to_i)
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
  distance = run[:distance].to_f
  duration = get_total_secs(run)

  mins_per_mile = duration.to_f / 60 / distance
  mins, secs = mins_per_mile.divmod(1)
  [mins, secs * 60]
end

def average_pace(runs)
  return [0, 0] if no_runs?(runs)

  total_distance = total_distance(runs)
  secs_totals = runs.reduce(0) do |total, run|
    total + get_total_secs(run)
  end

  mins_per_mile = secs_totals.to_f / 60 / total_distance
  mins, secs = mins_per_mile.divmod(1)
  [mins, secs * 60]
end

def average_distance_per_run(runs)
  return 0.0 if no_runs?(runs)

  total_distance(runs).to_f / runs.size
end

def average_duration_per_run(runs)
  return [0, 0, 0] if no_runs?(runs)

  average_secs = (total_secs(runs).to_f / runs.size).to_i
  hours, remaining_secs = average_secs.divmod(3600)
  mins, secs = remaining_secs.divmod(60)
  [hours, mins, secs]
end
