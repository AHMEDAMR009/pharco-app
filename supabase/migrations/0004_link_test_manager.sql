-- Replace <MANAGER_UID> with the UID of the manager account you just created
-- (Authentication -> Users -> the 9001@pharco.local row).
update public.employees
set manager_id = '<MANAGER_UID>'
where code = '101241';
