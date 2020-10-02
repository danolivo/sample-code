-- Получить свободные OIDы из заданного диапазона значений.
SELECT * FROM generate_series(4000,5000) as gs
WHERE gs NOT IN
(SELECT oid FROM pg_am
	UNION
SELECT oid FROM pg_amop
UNION
SELECT oid FROM pg_amproc
UNION
SELECT oid FROM pg_attrdef
UNION
SELECT oid FROM pg_authid
UNION
SELECT oid FROM pg_cast
UNION
SELECT oid FROM pg_class
UNION
SELECT oid FROM pg_collation
UNION
SELECT oid FROM pg_constraint
UNION
SELECT oid FROM pg_conversion
UNION
SELECT oid FROM pg_database
UNION
SELECT oid FROM pg_default_acl
UNION
SELECT oid FROM pg_enum
UNION
SELECT oid FROM pg_type
UNION
SELECT oid FROM pg_extension
UNION
SELECT oid FROM pg_foreign_data_wrapper
UNION
SELECT oid FROM pg_foreign_server
UNION
SELECT oid FROM pg_language
UNION
SELECT oid FROM pg_largeobject_metadata
UNION
SELECT oid FROM pg_namespace
UNION
SELECT oid FROM pg_opclass
UNION
SELECT oid FROM pg_operator
UNION
SELECT oid FROM pg_opfamily
UNION
SELECT oid FROM pg_proc
UNION
SELECT oid FROM pg_publication
UNION
SELECT oid FROM pg_rewrite
UNION
SELECT oid FROM pg_subscription
UNION
SELECT oid FROM pg_tablespace
UNION
SELECT oid FROM pg_trigger
UNION
SELECT oid FROM pg_ts_config
UNION
SELECT oid FROM pg_ts_dict
UNION
SELECT oid FROM pg_ts_parser
UNION
SELECT oid FROM pg_ts_template
UNION
SELECT oid FROM pg_user_mapping);

