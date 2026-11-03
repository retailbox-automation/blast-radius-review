/// %ExecDirect reports a bad statement in the result object and %Next() then just returns 0.
/// For a tool that reasons from "no rows", an unnoticed SQL error would read as "nobody uses this", so errors throw here.
Class BlastRadius.Evidence.Sql Extends %RegisteredObject
{

ClassMethod Run(pSql As %String, pArgs...) As %SQL.StatementResult
{
	set rs=##class(%SQL.Statement).%ExecDirect(,pSql,pArgs...)
	if rs.%SQLCODE<0 {
		$$$ThrowStatus($$$ERROR($$$GeneralError,"SQL "_rs.%SQLCODE_": "_rs.%Message_" in: "_pSql))
	}
	quit rs
}

}
