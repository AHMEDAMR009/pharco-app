-- Real org data import: companies + lines

insert into public.companies (name) values
  ('CHC'),
  ('CSC-GIT/CVM'),
  ('CSC-RESP/GYNA'),
  ('OO'),
  ('PPC')
on conflict do nothing;

insert into public.lines (company_id, name) values
  ((select id from public.companies where name = 'CHC' limit 1), 'CHC'),
  ((select id from public.companies where name = 'CHC' limit 1), 'CHC_Medical'),
  ((select id from public.companies where name = 'CHC' limit 1), 'CHC_PHARMA'),
  ((select id from public.companies where name = 'CSC-GIT/CVM' limit 1), 'GIT1'),
  ((select id from public.companies where name = 'CSC-GIT/CVM' limit 1), 'CVM2'),
  ((select id from public.companies where name = 'CSC-GIT/CVM' limit 1), 'CVM1'),
  ((select id from public.companies where name = 'CSC-GIT/CVM' limit 1), 'CSC-GIT/CVM'),
  ((select id from public.companies where name = 'CSC-GIT/CVM' limit 1), 'GIT2'),
  ((select id from public.companies where name = 'CSC-RESP/GYNA' limit 1), 'RESP_1'),
  ((select id from public.companies where name = 'CSC-RESP/GYNA' limit 1), 'RESP_2'),
  ((select id from public.companies where name = 'CSC-RESP/GYNA' limit 1), 'RESP_3'),
  ((select id from public.companies where name = 'CSC-RESP/GYNA' limit 1), 'RESP_4'),
  ((select id from public.companies where name = 'CSC-RESP/GYNA' limit 1), 'RESP_5'),
  ((select id from public.companies where name = 'CSC-RESP/GYNA' limit 1), 'GYNA_1'),
  ((select id from public.companies where name = 'CSC-RESP/GYNA' limit 1), 'GYNA_2'),
  ((select id from public.companies where name = 'CSC-RESP/GYNA' limit 1), 'GYNA_3'),
  ((select id from public.companies where name = 'CSC-RESP/GYNA' limit 1), 'CSC-RESP/GYNA'),
  ((select id from public.companies where name = 'OO' limit 1), 'OPHTHA_1'),
  ((select id from public.companies where name = 'OO' limit 1), 'ONCO'),
  ((select id from public.companies where name = 'OO' limit 1), 'OPHTHA_2'),
  ((select id from public.companies where name = 'OO' limit 1), 'OO'),
  ((select id from public.companies where name = 'PPC' limit 1), 'PC4'),
  ((select id from public.companies where name = 'PPC' limit 1), 'PC3'),
  ((select id from public.companies where name = 'PPC' limit 1), 'PC 6'),
  ((select id from public.companies where name = 'PPC' limit 1), 'PC5'),
  ((select id from public.companies where name = 'PPC' limit 1), 'PC1'),
  ((select id from public.companies where name = 'PPC' limit 1), 'PC2'),
  ((select id from public.companies where name = 'PPC' limit 1), 'PPC');
