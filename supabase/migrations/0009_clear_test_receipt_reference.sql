-- Clears the reference to an accidentally-uploaded (non-receipt) image
-- from earlier automated testing. Delete the actual file separately via
-- Dashboard -> Storage -> receipts ->
--   1ce70948-0d8f-46a6-9c56-4deb1985eb48/17726e2b-0968-414c-b493-b2880d3cfdeb.PNG
update public.request_extra_costs
set invoice_image = null
where id = 1;
