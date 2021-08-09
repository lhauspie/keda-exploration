\set session_id `shuf -i 1-1000000000 -n 1`
\set final_state `echo "'$FINAL_STATE'"`

-- DISPLAY THE CLAP TO MAKE
SELECT *
FROM make_it_clap
LEFT JOIN clap ON make_it_clap.id = clap.id
WHERE clap.status IS NULL
ORDER BY make_it_clap.id asc
LIMIT 1;


-- FLAG THE CLAP AS 'RUNNING' WITH THE SESSION ID
INSERT INTO clap (id, status, session_id, creation_date, creation_time)
    SELECT make_it_clap.id, 'RUNNING', :session_id, current_date, current_time
    FROM make_it_clap
    LEFT JOIN clap ON make_it_clap.id = clap.id
    WHERE clap.status IS NULL
    ORDER BY make_it_clap.id asc
    LIMIT 1;

-- DEAL WITH THE CLAP WHILE duration_seconds
SELECT pg_sleep(make_it_clap.duration_seconds)
FROM make_it_clap
LEFT JOIN clap ON make_it_clap.id = clap.id
WHERE clap.session_id = :session_id;

-- FLAG THE CLAP AS 'FAILED' OR 'SUCCESS'
UPDATE clap
SET status = :final_state,
    end_time = current_time
WHERE session_id = :session_id;
