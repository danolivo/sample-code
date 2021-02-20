-- Set variable and use it in IF contruct.
	select sum(amount) as var1 from accounts; \gset
	\if :var1 <> 0
		raise exception "ERROR!";
	\endif
