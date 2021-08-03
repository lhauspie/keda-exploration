CREATE TABLE IF NOT EXISTS clap (
    id integer NOT NULL,
    status varchar(20) NOT NULL,
    session_id bigint NOT NULL,
    creation_date date NOT NULL,
    creation_time time NOT NULL,
    CONSTRAINT clap_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS make_it_clap (
    id SERIAL PRIMARY KEY,
    duration_seconds integer NOT NULL
);
