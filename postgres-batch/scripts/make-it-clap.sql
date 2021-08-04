\set ON_ERROR_STOP true
\set session_id `shuf -i 1-1000000000 -n 1`
\set job_name `echo "'$JOB_NAME'"`

-- AFFECT THE CURRENT JOB TO THE OLDEST CLAP TO MAKE OR RETRY
UPDATE make_it_clap
SET job_name = :job_name
WHERE id IN (
    SELECT make_it_clap.id
    FROM make_it_clap
    LEFT JOIN clap ON make_it_clap.id = clap.id
    WHERE make_it_clap.job_name IS NULL AND clap.status IS NULL
           OR make_it_clap.job_name = :job_name AND clap.status = 'FAILED'
    ORDER BY make_it_clap.id asc
    LIMIT 1
);

-- DISPLAY THE CLAP TO MAKE OR RETRY
SELECT *
FROM make_it_clap
LEFT JOIN clap ON make_it_clap.id = clap.id
WHERE make_it_clap.job_name = :job_name
      AND (clap.status IS NULL
           OR clap.status = 'FAILED')
ORDER BY make_it_clap.id asc
LIMIT 1;


-- FLAG THE CLAP AS 'RUNNING' WITH THE SESSION ID
INSERT INTO clap (id, status, session_id, creation_date, creation_time)
    SELECT make_it_clap.id, 'RUNNING', :session_id, current_date, current_time
    FROM make_it_clap
    LEFT JOIN clap ON make_it_clap.id = clap.id
    WHERE make_it_clap.job_name = :job_name
          AND (clap.status IS NULL
               OR clap.status = 'FAILED')
    ORDER BY make_it_clap.id asc
    LIMIT 1
ON CONFLICT (id)
DO -- Conflict when clap already done but FAILED, so back to RUNNING status and new session
    UPDATE SET status = 'RUNNING',
               session_id = :session_id
;

-- DEAL WITH THE CLAP WHILE duration_seconds
SELECT pg_sleep(make_it_clap.duration_seconds)
FROM make_it_clap
LEFT JOIN clap ON make_it_clap.id = clap.id
WHERE clap.session_id = :session_id;

-- FLAG THE CLAP AS 'FAILED'
UPDATE clap
SET status = 'FAILED',
    end_time = current_time,
    iteration = iteration + 1
WHERE session_id = :session_id;

-- OR 'SUCCESS'
UPDATE clap
SET status = 'SUCCESS'
WHERE session_id = :session_id
      AND iteration = 4;

-- FAILING THE SQL SCRIPT 3 FIRST TIMES
SELECT 1/FLOOR(iteration::decimal/4)
FROM clap
WHERE session_id = :session_id;
