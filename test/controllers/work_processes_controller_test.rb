require "test_helper"

class WorkProcessesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @work_process = work_processes(:one)
  end

  test "should get index" do
    get work_processes_url
    assert_response :success
  end

  test "should get new" do
    get new_work_process_url
    assert_response :success
  end

  test "should create work_process" do
    assert_difference("WorkProcess.count") do
      post work_processes_url, params: { work_process: { contractor_name: @work_process.contractor_name, end_date: @work_process.end_date, labor_cost: @work_process.labor_cost, material_cost: @work_process.material_cost, memo: @work_process.memo, process_name: @work_process.process_name, project_id: @work_process.project_id, start_date: @work_process.start_date, status: @work_process.status } }
    end

    assert_redirected_to work_process_url(WorkProcess.last)
  end

  test "should show work_process" do
    get work_process_url(@work_process)
    assert_response :success
  end

  test "should get edit" do
    get edit_work_process_url(@work_process)
    assert_response :success
  end

  test "should update work_process" do
    patch work_process_url(@work_process), params: { work_process: { contractor_name: @work_process.contractor_name, end_date: @work_process.end_date, labor_cost: @work_process.labor_cost, material_cost: @work_process.material_cost, memo: @work_process.memo, process_name: @work_process.process_name, project_id: @work_process.project_id, start_date: @work_process.start_date, status: @work_process.status } }
    assert_redirected_to work_process_url(@work_process)
  end

  test "should destroy work_process" do
    assert_difference("WorkProcess.count", -1) do
      delete work_process_url(@work_process)
    end

    assert_redirected_to work_processes_url
  end
end
