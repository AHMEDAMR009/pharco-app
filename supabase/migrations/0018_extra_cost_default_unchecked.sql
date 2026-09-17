-- New extra-cost line items should start unchecked, requiring the manager
-- to actively accept each one during review (matches the app's own default).
alter table public.request_extra_costs alter column is_checked set default false;
