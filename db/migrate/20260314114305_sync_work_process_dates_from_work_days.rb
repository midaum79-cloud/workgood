class SyncWorkProcessDatesFromWorkDays < ActiveRecord::Migration[7.2]
  def up
    # Backfill start_date / end_date for any work_process that has work_days
    # but is missing the cached date columns (data existed before the toggle fix).
    execute <<~SQL
      UPDATE work_processes
      SET
        start_date = sub.min_date,
        end_date   = sub.max_date
      FROM (
        SELECT
          work_process_id,
          MIN(work_date) AS min_date,
          MAX(work_date) AS max_date
        FROM work_days
        GROUP BY work_process_id
      ) sub
      WHERE work_processes.id = sub.work_process_id
        AND (work_processes.start_date IS NULL OR work_processes.end_date IS NULL);
    SQL
  end

  def down
    # Non-reversible data migration – safe to leave as no-op
  end
end
