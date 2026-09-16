json.extract! project, :id, :project_name, :client_name, :address, :start_date, :end_date, :status, :color, :memo, :created_at, :updated_at
json.schedule_count project.project_schedules.count
json.url project_url(project, format: :json)
