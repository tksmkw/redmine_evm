module IndicatorsLogic

  def self.calc_indicators(project_or_version)
    time_entries_by_week_and_year, issues = retrive_data(project_or_version)
    end_date = project_or_version.due_date || Time.now.to_date
    check_ary_reported_time_week_year =
      time_entries_by_week_and_year.empty? ? Time.now.to_date :
        Date.ordinal(time_entries_by_week_and_year.keys.last[1],
                       time_entries_by_week_and_year.keys.last[0] * 7 - 3)

    if issues.maximum(:start_date)
      check_ary_all_issues = issues.empty? ? Time.now.to_date : issues.maximum(:start_date)
      my_project_or_version_end_date =
          [end_date, check_ary_reported_time_week_year, check_ary_all_issues].max
    else
      my_project_or_version_end_date =
          [end_date, check_ary_reported_time_week_year].max
    end
    real_start_date = [
          (project_or_version.start_date.nil? ?
            (Time.now.to_date - 1.day) :
              project_or_version.start_date.beginning_of_week),
          (time_entries_by_week_and_year.empty? ?
            Time.now.to_date :
            Date.ordinal(time_entries_by_week_and_year.keys.first[1],
                           time_entries_by_week_and_year.keys.first[0] * 7 - 3))
        ].min
    ary_weeks_years = []
    while real_start_date < my_project_or_version_end_date + 1.week
      ary_weeks_years << [real_start_date.cweek, real_start_date.cwyear]
      real_start_date += 1.week
    end
    hash_weeks_years = {}
    ary_weeks_years.each{|e| hash_weeks_years[e] = [0, 0, 0]}
    issues.each do |issue|
      next if !issue.leaf?
      start_issue_date = issue.start_date? ? issue.start_date : project_or_version.start_date
      end_issue_date = issue.due_date? ? issue.due_date : my_project_or_version_end_date
      estimated_time = issue.estimated_hours? ? issue.estimated_hours : 0
      done_ratio = (issue.done_ratio / 100.0)
      if (not start_issue_date.nil?) && (not end_issue_date.nil?)
        ary_dates = (start_issue_date..end_issue_date).to_a
        ary_dates.delete_if{|x| x.wday == 5 || x.wday == 6}
        if ary_dates.any? && estimated_time != 0
          hoursPerDay = estimated_time / ary_dates.size
          ary_dates.each do |day|
            week = day.cweek
            year = day.cwyear
            hash_weeks_years[[week, year]][1] += hoursPerDay
            hash_weeks_years[[week, year]][2] += hoursPerDay * done_ratio
          end
        end
      end
    end
    ary_data_week_years = [['week', 'ActualCost', 'PlannedCost', 'EarnedValue']]
    sum_real, sum_planned, sum_earned = 0,0,0
    ary_weeks_years.each do |k|
      v = hash_weeks_years[k]
      sum_real += time_entries_by_week_and_year.has_key?(k) ? time_entries_by_week_and_year[k] : 0
      sum_planned += v[1]
      sum_earned += v[2]
      ary_data_week_years.push(
        [k[0].to_s + "/" + k[1].to_s,
         (sum_real * 100).round / 100.0,
         (sum_planned * 100).round / 100.0,
         (sum_earned * 100).round / 100.0])
    end
    cpi = calculate_performance_indicator(hash_weeks_years.values.last[2], hash_weeks_years.values.last[0])
    spi = calculate_performance_indicator(hash_weeks_years.values.last[2], hash_weeks_years.values.last[1])
    [ary_data_week_years, (cpi * 1000).round / 1000.0, (spi * 1000).round / 1000.0]
  end

  private

  def self.retrive_data(project_or_version)
    if project_or_version.instance_of? Version
      project = project_or_version.project
      version = project_or_version
      time_entries_by_week_and_year =
          project.time_entries.where(
              :issue_id => Issue.where(:fixed_version_id => version.id)).sum(
              :hours, :group => [:tweek, :tyear]) # mising sort by year then week - sort na BD
      issues = version.fixed_issues
    else
      project = project_or_version
      time_entries_by_week_and_year =
          project.time_entries.sum(
              :hours, :group => [:tweek, :tyear]) # mising sort by year then week - sort na BD
      issues = project.issues
    end
    return time_entries_by_week_and_year, issues
  end

  def self.calculate_performance_indicator(earned_value, denominator)
    denominator == 0 ? 0 : earned_value / denominator
  end
end
