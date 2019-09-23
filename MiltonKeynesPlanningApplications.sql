--create database MiltonKeynes
--go

use MiltonKeynes
go

USE [MiltonKeynes]
GO

if OBJECT_ID('dbo.MainData') is not null
begin
	drop table dbo.MainData
end
go

set dateformat dmy
SELECT
	[CaseReference] as CaseReference
   ,try_cast([CaseDate] as date) as CaseDate
   ,[ServiceTypeLabel] as ServiceLabel
   ,[ClassificationLabel] as ClassificationLabel
   ,[CaseText] as CaseDescription
   ,CASE
		when right(rtrim(LocationText),8) like '[A-Z][A-Z][1-9][1-9] [1-9]__'
			then right(rtrim(LocationText),8)
		when right(rtrim(LocationText),7) like '[A-Z][A-Z][1-9] [1-9]__'
			then right(rtrim(LocationText),7)
		else ''
		end as PostCode
   ,[LocationText] as LocationText
   ,try_cast([DecisionTargetDate] as date) as TargetDecisionDate
   ,[Status] as CaseStatus
   ,try_cast([DecisionDate] as date) as ActualDecisionDate
   ,[Decision] as Decision
   ,[DecisionType] as DecisionType
   ,[AppealRef] as AppealReference
   ,[AppealDecisionDate] as AppealDecisionDate
   ,[AppealDecision] as AppealOutcome
   ,[Agent] as Agent

into dbo.MainData
FROM [dbo].[PlanningData]
GO

if OBJECT_ID('dbo.MainDataRefused') is not null
begin
	drop table dbo.MainDataRefused
end
go

select 
	 left(PostCode,charindex(' ',PostCode,1)-1) as PostCodeArea
	,*
	,datediff(dd,CaseDate,
		CASE
			when AppealDecisionDate<>''
				then AppealDecisionDate
			else ActualDecisionDate
		END) as Latency
into dbo.MainDataRefused
from dbo.MainData
where 1=1
	and Decision like '%Refuse%'
	and PostCode <> ''
	and ActualDecisionDate <> '1900-01-01'

if OBJECT_ID('dbo.MainDataApproved') is not null
begin
	drop table dbo.MainDataApproved
end
go

select
	 left(PostCode,charindex(' ',PostCode,1)-1) as PostCodeArea
	,*
	,datediff(dd,CaseDate,
		CASE
			when AppealDecisionDate<>''
				then AppealDecisionDate
			else ActualDecisionDate
		END) as Latency
into dbo.MainDataApproved
from dbo.MainData
where 1=1
	and Decision like '%Approve%'
	and PostCode <> ''
	and ActualDecisionDate <> '1900-01-01'

create view vw_MKRegionDecisionSummary
as
select distinct
	 a.PostCodeArea
	,avg(a.Latency) over (partition by a.PostCodeArea) as AvgApprovalTime
	,avg(r.Latency) over (partition by r.PostCodeArea) as AvgRefusalTime
	,CASE
		when avg(a.Latency) over (partition by a.PostCodeArea) is null
			or
			avg(r.Latency) over (partition by r.PostCodeArea) is null
			then 'Insufficient data'
		when avg(a.Latency) over (partition by a.PostCodeArea) < avg(r.Latency) over (partition by r.PostCodeArea)
			then 'Approval'
		else 'Refusal'
	end as QuickerDecisionType
from dbo.MainDataApproved as a left join dbo.MainDataRefused as r
	on a.PostCodeArea = r.PostCodeArea
go



--this solution returns an answer but is imperfect, due to some inaccurate cleansing/data understanding
--better might have been to calculate all regions and latencies, then use window functions to calculate
--each average and partition (eg I currently lose the split decision type).