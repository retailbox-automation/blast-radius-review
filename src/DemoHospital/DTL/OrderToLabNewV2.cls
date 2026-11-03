/// Candidate fix: same as OrderToLabNew, but keeps the ordering provider on every order in the message.
Class DemoHospital.DTL.OrderToLabNewV2 Extends Ens.DataTransformDTL [ DependsOn = EnsLib.HL7.Message ]
{

Parameter IGNOREMISSINGSOURCE = 1;

XData DTL [ XMLNamespace = "http://www.intersystems.com/dtl" ]
{
<transform sourceClass='EnsLib.HL7.Message' targetClass='EnsLib.HL7.Message' sourceDocType='2.5:ORM_O01' targetDocType='2.5:ORM_O01' create='copy' language='objectscript' >
<assign value='"LAB-NEW"' property='target.{MSH:ReceivingApplication}' action='set' />
<foreach property='source.{ORCgrp()}' key='k1' >
<assign value='..Lookup("LabCodesToLoinc",source.{ORCgrp(k1).OBRuniongrp.OBRunion.OBR:UniversalServiceIdentifier.Identifier},source.{ORCgrp(k1).OBRuniongrp.OBRunion.OBR:UniversalServiceIdentifier.Identifier})' property='target.{ORCgrp(k1).OBRuniongrp.OBRunion.OBR:UniversalServiceIdentifier.Identifier}' action='set' />
<assign value='"LN"' property='target.{ORCgrp(k1).OBRuniongrp.OBRunion.OBR:UniversalServiceIdentifier.NameofCodingSystem}' action='set' />
</foreach>
</transform>
}

}
