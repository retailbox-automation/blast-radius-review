/// Runs the suite and prints one line per failure plus a total. Used by tests/run.sh and the README.
Class BlastRadiusTests.Runner Extends %RegisteredObject
{

ClassMethod Go(pClasses As %String = "GateTest,PolicyTest,EvidenceTest,EndToEndTest") As %Integer
{
	set ^UnitTestRoot="/home/irisowner/dev/tests"
	set passed=0, failed=0
	for i=1:1:$length(pClasses,",") {
		set cls="BlastRadiusTests."_$piece(pClasses,",",i)
		continue:'##class(%Dictionary.CompiledClass).%ExistsId(cls)
		set dev=$io
		// The test manager prints a lot; only the totals below matter.
		set sc=##class(%UnitTest.Manager).DebugRunTestCase("",cls,"/noload/nodelete/nodisplay","")
		if $$$ISERR(sc) { write "Could not run ",cls,": ",$system.Status.GetErrorText(sc),! set failed=failed+1 continue }
		set inst=$order(^UnitTest.Result(""),-1)
		set rs=##class(BlastRadius.Evidence.Sql).Run("SELECT Status,Description,Counter,TestMethod->Name m FROM %UnitTest_Result.TestAssert WHERE TestMethod->TestCase->TestSuite->TestInstance=?",inst)
		while rs.%Next() {
			if rs.Status=1 { set passed=passed+1 } else { set failed=failed+1 write !,"FAILED ",cls,".",rs.m,": ",rs.Description,! }
		}
	}
	write !,"RESULT passed=",passed," failed=",failed,!
	quit failed
}

}
