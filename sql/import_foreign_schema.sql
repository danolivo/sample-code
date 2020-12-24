create extension postgres_fdw;

CREATE SERVER lb FOREIGN DATA WRAPPER postgres_fdw OPTIONS (use_remote_estimate 'true');
ALTER SERVER lb OPTIONS (ADD dbname 'tpch');
CREATE USER MAPPING FOR PUBLIC SERVER lb;
IMPORT FOREIGN SCHEMA public FROM SERVER lb INTO public;
