json.extract! work_process, :id, :project_id, :process_name, :start_date, :end_date, :contractor_name, :material_cost, :labor_cost, :memo, :status, :created_at, :updated_at
json.url work_process_url(work_process, format: :json)
