Datum
sr_register_query(PG_FUNCTION_ARGS)
{
	const char *query_string = text_to_cstring(PG_GETARG_TEXT_P(0));
	int			numParams;
	Datum	   *args;
	bool	   *nulls;
	Oid		   *types;
	int			i;

	/* Fetch list of the query parameters. */
	numParams = extract_variadic_args(fcinfo, 1, false, &args, &types, &nulls);

	elog(WARNING, "Q: %s (%d)", query_string, numParams);

	for (i = 0; i < numParams; i++)
	{
		if (nulls[i])
			ereport(ERROR,
					(errcode(ERRCODE_INVALID_PARAMETER_VALUE),
					 errmsg("[SR] argument %d cannot be null", i + 1),
					 errhint("Parameter should be regtype.")));

		Assert(types[i] == REGTYPEOID);
		elog(WARNING, "type: %u - %u", types[i], DatumGetObjectId(args[i]));
	}

	PG_RETURN_BOOL(true);
	sr_register_query_int(query_string, types, numParams);
}
