/// Candidate change: billing now wants observation stays reported as outpatient.
Class DemoHospital.DTL.AdtToBillingV2 Extends Ens.DataTransformDTL [ DependsOn = EnsLib.HL7.Message ]
{

Parameter IGNOREMISSINGSOURCE = 1;

XData DTL [ XMLNamespace = "http://www.intersystems.com/dtl" ]
{
<transform sourceClass='EnsLib.HL7.Message' targetClass='EnsLib.HL7.Message' sourceDocType='2.5:ADT_A01' targetDocType='2.5:ADT_A01' create='copy' language='objectscript' >
<assign value='"BILLING"' property='target.{MSH:ReceivingApplication}' action='set' />
<if condition='source.{PV1:PatientClass}="O"' >
<true>
<assign value='"U"' property='target.{PV1:PatientClass}' action='set' />
</true>
</if>
</transform>
}

}
