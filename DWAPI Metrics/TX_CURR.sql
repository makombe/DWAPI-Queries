select 'TX_CURR'                                                                   AS 'INDICATOR',
       count(distinct t.patient_id)                                                as 'INDICATOR_VALUE',
       date_format(last_day(date_sub(current_date(), interval 1 MONTH)), '%Y%b%d') as 'INDICATOR_DATE'
from(
    select fup.visit_date,fup.patient_id, max(e.visit_date) as enroll_date,
           greatest(max(e.visit_date), ifnull(max(date(e.transfer_in_date)),'0000-00-00')) as latest_enrolment_date,
           greatest(max(fup.visit_date), ifnull(max(d.visit_date),'0000-00-00')) as latest_vis_date,
           greatest(mid(max(concat(fup.visit_date,fup.next_appointment_date)),11), ifnull(max(d.visit_date),'0000-00-00')) as latest_tca,
           d.patient_id as disc_patient,
           d.effective_disc_date as effective_disc_date,
           max(d.visit_date) as date_discontinued,
           de.patient_id as started_on_drugs
    from kenyaemr_etl.etl_patient_hiv_followup fup
           join kenyaemr_etl.etl_patient_demographics p on p.patient_id=fup.patient_id
           join kenyaemr_etl.etl_hiv_enrollment e on fup.patient_id=e.patient_id
           left outer join kenyaemr_etl.etl_drug_event de on e.patient_id = de.patient_id and de.program='HIV' and date(date_started) <= date(date(last_day(date_sub(current_date(),interval 1 MONTH))))
           left outer JOIN
             (select patient_id, coalesce(date(effective_discontinuation_date),visit_date) visit_date,max(date(effective_discontinuation_date)) as effective_disc_date from kenyaemr_etl.etl_patient_program_discontinuation
              where date(visit_date) <= date(date(last_day(date_sub(current_date(),interval 1 MONTH))))
                and program_name='HIV' and patient_id
              group by patient_id
             ) d on d.patient_id = fup.patient_id
    where fup.visit_date <= date(date(last_day(date_sub(current_date(),interval 1 MONTH))))
    group by patient_id
    having (started_on_drugs is not null and started_on_drugs <> '')
       and
           (
               ((timestampdiff(DAY,date(latest_tca),date(date(last_day(date_sub(current_date(),interval 1 MONTH))))) <= 30 or timestampdiff(DAY,date(latest_tca),date(curdate())) <= 30) and
                ((date(d.effective_disc_date) > date(date(last_day(date_sub(current_date(),interval 1 MONTH)))) or date(enroll_date) > date(d.effective_disc_date)) or d.effective_disc_date is null))
                 and
               (date(latest_vis_date) >= date(date_discontinued) or date(latest_tca) >= date(date_discontinued) or disc_patient is null)
               )
    )t;